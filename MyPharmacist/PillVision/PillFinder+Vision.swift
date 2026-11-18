//
//  PillFinder+Vision.swift
//  MyPharmacist
//

import CoreGraphics
import CoreVideo
import Vision

/// The first way pills are found: Vision's subject lifting, over the whole picture and,
/// when that takes the hand and the pills for one object, piece by piece.
nonisolated extension PillFinder {
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
        let found: SubjectMask?
        do {
            found = try SubjectMask(of: picture)
        } catch {
            return lift
        }
        lift.ran = true
        // No result at all: Vision saw nothing that stands out from the background.
        guard let found else { return lift }

        let labels = found.labels
        lift.maskWidth = labels.width
        lift.maskHeight = labels.height
        let measured = found.objects
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
        for (instance, object) in small {
            if let blob = outline(of: instance, near: object.box, in: found, width: picture.width, height: picture.height) {
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
    private static func outline(of instance: Int, near box: CGRect, in found: SubjectMask, width: Int, height: Int) -> Blob? {
        guard let mask = try? found.observation.generateScaledMaskForImage(forInstances: [instance], from: found.handler) else { return nil }
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
}
