//
//  PillFinder.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import os

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
    /// Its outline isn't a pill's clean one (`LocatedPill.isRough`).
    var isRough = false
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
        let size = PhotoSize.fitting(working, maxSide: searchedSide)
        let width = size.width, height = size.height
        guard let picture = ColourImage(working, width: width, height: height), let searched = picture.cgImage() else {
            return .failed
        }
        let rules = PillRules(pictureWidth: width, widthMillimeters: photo.widthMillimeters, capturedWidth: Int(photo.size.width))

        // First way: Vision's objects. Second way: colour, on the surface if Vision
        // found one.
        let (lift, usedTiles) = liftedObjects(in: searched)
        var settings = SurfaceOutliers.Settings()
        settings.blockSize = max(32, Int(surfaceSquareMillimeters * rules.pixelsPerMillimeter))
        let colour = SurfaceOutliers.find(in: picture, within: lift.surface, settings: settings)

        let (location, areas) = PillLocator.examine(lifted: lift.objects, colour: colour, rules: rules, pictureWidth: width, pictureHeight: height)
        Log.scan.info("""
            search \(width)x\(height) at \(rules.pixelsPerMillimeter, format: .fixed(precision: 1)) px/mm: \
            vision \(lift.ran ? "ran" : "failed") mask \(lift.maskWidth)x\(lift.maskHeight), \
            objects \(lift.shares.map { String(format: "%.2f%%", $0 * 100) }), surface \(lift.surface != nil), \
            tiles \(usedTiles), lifted \(lift.objects.count), colour \(colour.blobs.count) clear \(colour.faint.count) faint \
            reliable \(colour.isReliable) spread \(colour.spread) standing out \(colour.shareStandingOut, format: .fixed(precision: 3)) \
            in \(colour.areas), took \(ContinuousClock.now - started)
            """)
        log(areas, rules: rules)

        // Vision couldn't tell the pills from what they lie on, and the surface is too
        // patterned for colour to: nothing here can say there are no more pills.
        if usedTiles, !colour.isReliable {
            Log.scan.info("search unclear: neither way can be trusted on this surface")
            return .unclear(.hardToSee)
        }

        switch location {
        case .unclear(let reason):
            Log.scan.info("search unclear: \(String(describing: reason))")
            return .unclear(reason)
        case .noPills:
            // Without Vision, an empty answer from colour alone isn't "no pills".
            return lift.ran ? .noPills : .failed
        case .found(let located):
            // A pill that can't be cut out fails the whole search: leaving it out would
            // show the rest as if they were all the pills there are.
            let pills = located.compactMap { pill in
                cutOut(pill.blob, from: working, searchedWidth: width).map { crop in
                    FoundPill(box: pill.blob.normalizedBounds(pictureWidth: width, pictureHeight: height),
                              crop: crop, outline: pill.blob, shape: pill.shape,
                              searchedSize: CGSize(width: width, height: height), sources: pill.sources, isRough: pill.isRough)
                }
            }
            return pills.count == located.count ? .found(pills) : .failed
        }
    }

    /// Vision's pill-sized objects. With none (the hand took the pills with it, or
    /// nothing stood out), the picture is looked at again piece by piece, where the hand
    /// is the background.
    private static func liftedObjects(in picture: CGImage) -> (lift: Lift, usedTiles: Bool) {
        var lift = lift(from: picture)
        guard lift.ran, lift.objects.isEmpty else { return (lift, false) }
        lift.objects = liftInTiles(from: picture)
        return (lift, true)
    }

    /// One line for every area that was pill-sized, with the numbers the rules went by
    /// and what became of it: what explains a photo that was turned away.
    private static func log(_ areas: [ExaminedArea], rules: PillRules) {
        let sized = areas.filter { $0.verdict != .notAPill }
        Log.scan.info("areas \(areas.count), pill-sized \(sized.count)")
        for area in sized {
            let dent = area.shape.deepestDent / max(1, area.shape.equivalentRadius)
            Log.scan.info("""
                area by \(area.sources.rawValue): \(area.shape.length / rules.pixelsPerMillimeter, format: .fixed(precision: 1)) x \
                \(area.shape.width / rules.pixelsPerMillimeter, format: .fixed(precision: 1)) mm, \
                \(area.shape.length * rules.capturedPixelsPerPixel, format: .fixed(precision: 0)) px in the photo, \
                fills \(area.shape.solidity, format: .fixed(precision: 2)), dent \(dent, format: .fixed(precision: 2)), \
                judged \(String(describing: area.verdict), privacy: .public), \(String(describing: area.outcome), privacy: .public)
                """)
        }
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
              let context = CGContext.bitmap(width: Int(rect.width), height: Int(rect.height), transparent: true) else { return nil }
        let whole = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)
        context.clip(to: whole, mask: outline)
        context.draw(piece, in: whole)
        return context.makeImage()
    }
}
