//
//  PillFinder.swift
//  MyPharmacist
//

import CoreGraphics
import CoreVideo
import Foundation
import os
import Vision

/// One pill found in a photo: where it is, its outline, and a cut-out of just the pill.
nonisolated struct FoundPill: Sendable {
    /// Normalized 0–1, origin at the top left of the photo.
    let box: CGRect
    /// The pill alone, cropped to it, with everything around it transparent.
    let crop: CGImage
    /// The pill's outline and measurements, in the pixels of the picture that was
    /// searched (a smaller copy of the photo, `searchedSize` across).
    let outline: Blob
    let shape: BlobShape
    let searchedSize: CGSize
    /// Whether Vision found it, its colour did, or both.
    let sources: LocatedPill.Sources
}

/// What looking for pills in a photo came to.
nonisolated enum PillSearch: Sendable {
    /// At least one pill, in reading order (top row first, left to right).
    case found([FoundPill])
    /// The photo was searched and has no pills in it.
    case noPills
    /// Something is there that can't be trusted as it is: the photo has to be taken
    /// again, for this reason.
    case unclear(RetakeReason)
    /// The search itself didn't work, so whether there are pills isn't known. Never to
    /// be shown as "no pills".
    case failed
}

/// Finds the pills in a photo in two ways and lets `PillLocator` settle what each area
/// is. Vision's subject lifting (the same as touching and holding a photo's subject)
/// gives the separate objects; what differs from the surface by colour gives the pills
/// Vision missed, as it does when it takes a hand and the pills on it for one object.
nonisolated enum PillFinder {
    /// The longer side of the picture that is searched. Vision works on a smaller copy
    /// anyway, and the colour check runs over every pixel, in debug builds too.
    static let searchedSide = 960
    /// An object covering more of the picture than this is what the pills lie on (a
    /// hand, a plate), not a pill.
    static let surfaceShare = 0.12
    /// Vision's objects are checked up to this many, largest first.
    static let mostObjects = 24
    /// The surface's colour is learned in squares about this wide: wider than a few pills.
    static let surfaceSquareMillimeters = 20.0

    static func find(in photo: CapturedPhoto) -> PillSearch {
        let started = ContinuousClock.now
        let working = photo.working
        let scale = min(1, Double(searchedSide) / Double(max(working.width, working.height)))
        let width = max(1, Int((Double(working.width) * scale).rounded()))
        let height = max(1, Int((Double(working.height) * scale).rounded()))
        guard let picture = ColourImage(working, width: width, height: height), let searched = picture.cgImage() else {
            return .failed
        }
        let rules = PillRules(pictureWidth: width, widthMillimeters: photo.widthMillimeters, capturedWidth: Int(photo.size.width))

        // First way: Vision's objects. With none pill-sized (the hand took the pills
        // with it, or nothing stood out), look again piece by piece, where the hand is
        // the background.
        var lift = lift(from: searched)
        var usedTiles = false
        if lift.ran, lift.objects.isEmpty {
            usedTiles = true
            lift.objects = liftInTiles(from: searched)
        }

        // Second way: colour, on the surface if Vision found one.
        var settings = SurfaceOutliers.Settings()
        settings.blockSize = max(32, Int(surfaceSquareMillimeters * rules.pixelsPerMillimeter))
        let colour = SurfaceOutliers.find(in: picture, within: lift.surface, settings: settings)

        let location = PillLocator.locate(lifted: lift.objects, colour: colour, rules: rules, pictureWidth: width, pictureHeight: height)
        let took = ContinuousClock.now - started
        ScanLog.logger.info("""
            search \(width)x\(height) at \(rules.pixelsPerMillimeter, format: .fixed(precision: 1)) px/mm: \
            vision \(lift.ran ? "ran" : "failed") mask \(lift.maskWidth)x\(lift.maskHeight), \
            objects \(lift.shares.map { String(format: "%.2f%%", $0 * 100) }), surface \(lift.surface != nil), \
            tiles \(usedTiles), lifted \(lift.objects.count), colour \(colour.blobs.count) clear \(colour.faint.count) faint \
            reliable \(colour.isReliable) spread \(colour.spread) standing out \(colour.shareStandingOut, format: .fixed(precision: 3)) \
            in \(colour.areas), took \(took)
            """)

        // Vision couldn't tell the pills from what they lie on, and the surface is too
        // patterned for colour to: nothing here can say there are no more pills.
        if usedTiles, !colour.isReliable {
            ScanLog.logger.info("search unclear: neither way can be trusted on this surface")
            return .unclear(.hardToSee)
        }

        switch location {
        case .unclear(let reason):
            ScanLog.logger.info("search unclear: \(String(describing: reason))")
            return .unclear(reason)
        case .noPills:
            // Without Vision, an empty answer from colour alone isn't "no pills".
            return lift.ran ? .noPills : .failed
        case .found(let located):
            var pills: [FoundPill] = []
            for pill in located {
                ScanLog.logger.info("""
                    pill \(pills.count + 1): \(pill.shape.length / rules.pixelsPerMillimeter, format: .fixed(precision: 1)) x \
                    \(pill.shape.width / rules.pixelsPerMillimeter, format: .fixed(precision: 1)) mm, \
                    \(pill.shape.length * rules.capturedPixelsPerPixel, format: .fixed(precision: 0)) px in the photo, \
                    fills \(pill.shape.solidity, format: .fixed(precision: 2)), found by \(pill.sources.rawValue)
                    """)
                // A pill that can't be cut out fails the whole search: leaving it out
                // would show the rest as if they were all the pills there are.
                guard let crop = cutOut(pill.blob, from: working, searchedWidth: width) else { return .failed }
                let bounds = pill.blob.bounds
                pills.append(FoundPill(
                    box: CGRect(x: bounds.minX / Double(width), y: bounds.minY / Double(height),
                                width: bounds.width / Double(width), height: bounds.height / Double(height)),
                    crop: crop, outline: pill.blob, shape: pill.shape,
                    searchedSize: CGSize(width: width, height: height), sources: pill.sources))
            }
            return .found(pills)
        }
    }

    // MARK: Vision

    /// What one pass of subject lifting gave.
    struct Lift {
        /// False when Vision couldn't run at all (as in the Simulator).
        var ran = false
        /// Pill-sized objects, each with its outline in the picture's pixels.
        var objects: [Blob] = []
        /// Where the surface under the pills is, if an object large enough was found.
        var surface: PixelMask?
        /// For the log: the size of Vision's own mask and each object's share of it.
        var maskWidth = 0, maskHeight = 0
        var shares: [Double] = []
    }

    static func lift(from picture: CGImage) -> Lift {
        var lift = Lift()
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: picture)
        do {
            try handler.perform([request])
        } catch {
            return lift
        }
        lift.ran = true
        // No result at all: Vision saw nothing that stands out from the background.
        guard let observation = request.results?.first else { return lift }

        let labels = labels(of: observation.instanceMask)
        lift.maskWidth = labels.width
        lift.maskHeight = labels.height
        let measured = InstanceBoxes.boxes(labels: labels.values, width: labels.width, height: labels.height)
        lift.shares = measured.values.map(\.area).sorted(by: >)

        // The surface: every large object, with the pills lying on it (holes in it, if
        // Vision lifted them separately) filled in.
        let large = Set(measured.filter { $0.value.area >= surfaceShare }.keys)
        if !large.isEmpty {
            var surface = PixelMask(width: picture.width, height: picture.height)
            for y in 0..<picture.height {
                let row = min(labels.height - 1, y * labels.height / picture.height) * labels.width
                for x in 0..<picture.width where large.contains(Int(labels.values[row + min(labels.width - 1, x * labels.width / picture.width)])) {
                    surface[x, y] = true
                }
            }
            lift.surface = surface.fillingHoles()
        }

        let small = measured.filter { $0.value.area < surfaceShare }.sorted { $0.value.area > $1.value.area }.prefix(mostObjects)
        for (instance, found) in small {
            if let blob = outline(of: instance, near: found.box, in: observation, handler: handler, width: picture.width, height: picture.height) {
                lift.objects.append(blob)
            }
        }
        return lift
    }

    /// Looks for objects in overlapping pieces of the picture, two across and three
    /// down. In a piece, the hand fills the background and the pills are what stands out.
    static func liftInTiles(from picture: CGImage) -> [Blob] {
        let columns = 2, rows = 3
        let overlap = 0.3
        let tileWidth = Double(picture.width) / (Double(columns) - overlap * Double(columns - 1))
        let tileHeight = Double(picture.height) / (Double(rows) - overlap * Double(rows - 1))
        var found: [Blob] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let tile = CGRect(x: Double(column) * tileWidth * (1 - overlap), y: Double(row) * tileHeight * (1 - overlap),
                                  width: tileWidth, height: tileHeight)
                    .integral.intersection(CGRect(x: 0, y: 0, width: picture.width, height: picture.height))
                guard let piece = picture.cropping(to: tile) else { continue }
                for object in lift(from: piece).objects {
                    // An object against a side of the piece that isn't a side of the
                    // picture is cut by the piece; the next piece over has it whole.
                    let bounds = object.bounds
                    let cut = (bounds.minX <= 1 && tile.minX > 0) || (bounds.minY <= 1 && tile.minY > 0)
                        || (bounds.maxX >= tile.width - 1 && tile.maxX < Double(picture.width))
                        || (bounds.maxY >= tile.height - 1 && tile.maxY < Double(picture.height))
                    guard !cut else { continue }
                    let placed = Blob(x: object.x + Int(tile.minX), y: object.y + Int(tile.minY), mask: object.mask)
                    // The same object seen in two pieces is one object.
                    if !found.contains(where: { PillLocator.overlap($0, placed) }) {
                        found.append(placed)
                    }
                }
            }
        }
        return found
    }

    /// One object's outline at the picture's own size, from Vision's high-resolution
    /// mask, which follows the object's edge much more closely than the label map.
    private static func outline(of instance: Int, near box: CGRect, in observation: VNInstanceMaskObservation,
                                handler: VNImageRequestHandler, width: Int, height: Int) -> Blob? {
        guard let mask = try? observation.generateScaledMaskForImage(forInstances: [instance], from: handler) else { return nil }
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let maskWidth = CVPixelBufferGetWidth(mask), maskHeight = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        let format = CVPixelBufferGetPixelFormatType(mask)
        guard format == kCVPixelFormatType_OneComponent32Float || format == kCVPixelFormatType_OneComponent8 else { return nil }

        // Only around where the label map says the object is.
        let around = CGRect(x: box.minX * Double(width), y: box.minY * Double(height), width: box.width * Double(width), height: box.height * Double(height))
            .insetBy(dx: -0.2 * box.width * Double(width) - 4, dy: -0.2 * box.height * Double(height) - 4)
            .integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard around.width > 0, around.height > 0 else { return nil }
        var patch = PixelMask(width: Int(around.width), height: Int(around.height))
        for y in 0..<patch.height {
            let row = base + min(maskHeight - 1, (Int(around.minY) + y) * maskHeight / height) * bytesPerRow
            for x in 0..<patch.width {
                let column = min(maskWidth - 1, (Int(around.minX) + x) * maskWidth / width)
                let inside = format == kCVPixelFormatType_OneComponent8
                    ? row.assumingMemoryBound(to: UInt8.self)[column] > 127
                    : row.assumingMemoryBound(to: Float32.self)[column] > 0.5
                if inside { patch[x, y] = true }
            }
        }
        // The object itself, without stray pixels of its soft edge.
        guard let largest = patch.blobs().max(by: { $0.mask.count < $1.mask.count }) else { return nil }
        return Blob(x: Int(around.minX) + largest.x, y: Int(around.minY) + largest.y, mask: largest.mask)
    }

    /// Copies Vision's low-resolution label map: one byte per pixel, the number of the
    /// object it belongs to, 0 for the background.
    static func labels(of mask: CVPixelBuffer) -> (values: [UInt8], width: Int, height: Int) {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        guard let base = CVPixelBufferGetBaseAddress(mask), width > 0, height > 0 else { return ([], 0, 0) }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var labels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                labels[y * width + x] = bytes[y * bytesPerRow + x]
            }
        }
        return (labels, width, height)
    }

    // MARK: Cut-outs

    /// The pill alone, from the photo's copy for the screen: cropped to its outline,
    /// with everything outside the outline transparent.
    static func cutOut(_ blob: Blob, from working: CGImage, searchedWidth: Int) -> CGImage? {
        let scale = Double(working.width) / Double(searchedWidth)
        let rect = CGRect(x: Double(blob.x) * scale, y: Double(blob.y) * scale,
                          width: Double(blob.mask.width) * scale, height: Double(blob.mask.height) * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: working.width, height: working.height))
        guard rect.width > 0, rect.height > 0, let piece = working.cropping(to: rect), let outline = blob.mask.grayImage(),
              let context = CGContext(data: nil, width: Int(rect.width), height: Int(rect.height), bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let whole = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)
        context.interpolationQuality = .high
        context.clip(to: whole, mask: outline)
        context.draw(piece, in: whole)
        return context.makeImage()
    }
}
