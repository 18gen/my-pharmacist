//
//  PillRules.swift
//  MyPharmacist
//

import CoreGraphics

/// Decides what one area found in the photo is: a pill, pills touching, a pill cut off
/// by the photo's edge, or nothing to do with pills. Sizes are in millimetres and turned
/// into pixels with the photo's own scale, so the rules hold whatever size the photo is.
///
/// Every number is a starting point, to be tuned on real photos.
nonisolated struct PillRules: Sendable {
    enum Verdict: Equatable, Sendable {
        case pill
        /// Probably more than one pill: to be cut apart, or spread apart by hand.
        case touching
        /// Pill-sized but against the photo's edge, so part of it may be missing.
        case cutOff
        /// A speck, a line, or something too large to be a pill.
        case notAPill
    }

    /// Pixels per millimetre in the picture that is searched, with the phone held as
    /// close as it gets. Held further away, everything is smaller than this, never larger.
    var pixelsPerMillimeter: Double
    /// How many pixels of the full-size photo one pixel of the searched picture stands for.
    var capturedPixelsPerPixel = 1.0

    /// The smallest tablets are about 3 mm across.
    var smallestPill = 3.0
    /// The phone may be held this much further away than its closest: pills then look
    /// this share of their closest size.
    var farthest = 0.4
    /// The largest tablets and capsules are about 23 mm long.
    var longestPill = 24.0
    /// An area narrower than this share of its length is a line (a crease, an edge).
    var thinnest = 0.22
    /// One pill fills nearly all of its convex outline; two touching fill about 88%.
    var leastSolidity = 0.93
    /// Or have a dent where they meet, deeper than this share of the radius of a circle
    /// the area's size.
    var deepestDent = 0.15
    /// Closer to the photo's edge than this share of its shorter side counts as cut off.
    var edgeMargin = 0.01
    /// A pill shorter than this in the full-size photo is too small for its markings.
    var leastCapturedLength = 64.0
    /// A cut between two pills is short. One longer than this many times the narrower
    /// piece's width runs through a single pill.
    var longestCut = 0.8
    /// More areas than this is a cluttered picture, not a handful of pills.
    var mostPills = 12

    /// - Parameters:
    ///   - pictureWidth: The searched picture's width in pixels.
    ///   - widthMillimeters: How wide the photo is in real life at the closest distance.
    ///   - capturedWidth: The full-size photo's width in pixels.
    init(pictureWidth: Int, widthMillimeters: Double, capturedWidth: Int) {
        pixelsPerMillimeter = widthMillimeters > 0 ? Double(pictureWidth) / widthMillimeters : 1
        capturedPixelsPerPixel = pictureWidth > 0 ? Double(capturedWidth) / Double(pictureWidth) : 1
    }

    func judge(_ blob: Blob, pictureWidth: Int, pictureHeight: Int) -> Verdict {
        judge(BlobShape(blob), bounds: blob.bounds, pictureWidth: pictureWidth, pictureHeight: pictureHeight)
    }

    func judge(_ shape: BlobShape, bounds: CGRect, pictureWidth: Int, pictureHeight: Int) -> Verdict {
        guard shape.length >= smallestPill * farthest * pixelsPerMillimeter else { return .notAPill }
        guard shape.width >= thinnest * shape.length else { return .notAPill }
        let looksJoined = shape.solidity < leastSolidity || shape.deepestDent > deepestDent * shape.equivalentRadius
        // Nothing sharp is closer than the closest distance, so a single thing longer
        // than the longest pill at that distance is something else (a coin, a ring).
        if shape.length > longestPill * pixelsPerMillimeter, !looksJoined { return .notAPill }
        let margin = edgeMargin * Double(min(pictureWidth, pictureHeight))
        if bounds.minX < margin || bounds.minY < margin
            || bounds.maxX > Double(pictureWidth) - margin || bounds.maxY > Double(pictureHeight) - margin {
            return .cutOff
        }
        return looksJoined ? .touching : .pill
    }

    /// Whether a pill is large enough in the full-size photo for its markings to be read.
    func isReadable(_ shape: BlobShape) -> Bool {
        shape.length * capturedPixelsPerPixel >= leastCapturedLength
    }
}
