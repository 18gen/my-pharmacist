//
//  CapturedPhoto.swift
//  MyPharmacist
//

import CoreGraphics

/// The photo the pills are checked in: all of its pixels, for cutting each pill out as
/// sharp as the camera caught it, and a smaller upright copy that is quick to show and
/// to search. In memory only; nothing is saved.
///
/// The camera delivers photos in its sensor's landscape orientation. The full-size
/// pixels stay that way: a pill's cut-out is taken from them first and only that small
/// piece is turned upright, so there is never a second full-size copy.
nonisolated struct CapturedPhoto: Sendable {
    /// How the full-size pixels have to be turned to stand upright.
    enum Orientation: Sendable {
        /// Already upright.
        case up
        /// Turn a quarter clockwise: a photo from the back camera of a phone held upright.
        case right
    }

    /// The longer side of `working`, at most.
    static let workingSide = 2048
    /// What a photo that didn't come from the camera is taken to show: the width the
    /// camera frames for.
    static let assumedWidthMillimeters = CameraFraming.pillsWidthMillimeters / CameraFraming.pillsFillFraction

    /// Upright and at most `workingSide` on its longer side: what the screen shows and
    /// where the pills are looked for.
    let working: CGImage
    /// How wide the photo is in real life, in millimetres, with the phone held where the
    /// pills fill the view. Nothing sharp in it is closer, so nothing looks larger.
    let widthMillimeters: Double

    /// Full size, as delivered (see `orientation`), already cut to the part to keep.
    private let pixels: CGImage
    private let orientation: Orientation

    /// The upright photo's full size in pixels.
    var size: CGSize {
        switch orientation {
        case .up: CGSize(width: pixels.width, height: pixels.height)
        case .right: CGSize(width: pixels.height, height: pixels.width)
        }
    }

    /// - Parameters:
    ///   - source: The photo as delivered.
    ///   - visibleAspect: Width over height (upright) of the part the person saw in the
    ///     camera view; the rest is cut away, centred. Nil keeps everything.
    init?(source: CGImage, orientation: Orientation, visibleAspect: Double? = nil,
          widthMillimeters: Double = assumedWidthMillimeters) {
        let kept = Self.visiblePart(of: CGSize(width: source.width, height: source.height),
                                    orientation: orientation, visibleAspect: visibleAspect)
        // Decoded once into plain pixels: the camera's image decodes itself again on
        // every use otherwise, once per pill.
        guard let cut = source.cropping(to: kept),
              let pixels = Self.draw(cut, turned: .up, width: cut.width, height: cut.height) else { return nil }
        self.pixels = pixels
        self.orientation = orientation
        self.widthMillimeters = widthMillimeters

        let upright = orientation == .up ? CGSize(width: pixels.width, height: pixels.height)
                                         : CGSize(width: pixels.height, height: pixels.width)
        let scale = min(1, Double(Self.workingSide) / Double(max(upright.width, upright.height)))
        guard let working = Self.draw(pixels, turned: orientation,
                                      width: max(1, Int((upright.width * scale).rounded())),
                                      height: max(1, Int((upright.height * scale).rounded()))) else { return nil }
        self.working = working
    }

    /// A photo that is already upright, such as the demo's made-up one.
    init?(image: CGImage, widthMillimeters: Double = assumedWidthMillimeters) {
        self.init(source: image, orientation: .up, widthMillimeters: widthMillimeters)
    }

    /// An upright piece of the photo at full size.
    /// - Parameter rect: In the upright photo's pixels, origin at the top left. The part
    ///   outside the photo is left out, so the piece can be smaller than asked for.
    func region(_ rect: CGRect) -> CGImage? {
        let inside = rect.integral.intersection(CGRect(origin: .zero, size: size))
        guard !inside.isEmpty,
              let cut = pixels.cropping(to: Self.stored(inside, orientation: orientation, uprightWidth: size.width)) else { return nil }
        return Self.draw(cut, turned: orientation, width: Int(inside.width), height: Int(inside.height))
    }

    // MARK: Geometry

    /// The part of the delivered photo, in its own pixels, that shows as a centred
    /// `visibleAspect` shape once upright.
    static func visiblePart(of stored: CGSize, orientation: Orientation, visibleAspect: Double?) -> CGRect {
        let whole = CGRect(origin: .zero, size: stored)
        guard let visibleAspect, visibleAspect > 0 else { return whole }
        let upright = orientation == .up ? stored : CGSize(width: stored.height, height: stored.width)
        var kept = CGRect(origin: .zero, size: upright)
        if upright.width / upright.height > visibleAspect {
            let width = (upright.height * visibleAspect).rounded()
            kept = CGRect(x: ((upright.width - width) / 2).rounded(.down), y: 0, width: width, height: upright.height)
        } else {
            let height = (upright.width / visibleAspect).rounded()
            kept = CGRect(x: 0, y: ((upright.height - height) / 2).rounded(.down), width: upright.width, height: height)
        }
        return Self.stored(kept, orientation: orientation, uprightWidth: upright.width).intersection(whole)
    }

    /// Where an upright rectangle is in the delivered pixels. Turned a quarter clockwise,
    /// the delivered photo's left edge is the upright photo's top, and its top edge the
    /// upright photo's right.
    static func stored(_ upright: CGRect, orientation: Orientation, uprightWidth: CGFloat) -> CGRect {
        switch orientation {
        case .up: upright
        case .right: CGRect(x: upright.minY, y: uprightWidth - upright.maxX, width: upright.height, height: upright.width)
        }
    }

    /// Draws `image` into a new picture of the given size, turned upright.
    private static func draw(_ image: CGImage, turned orientation: Orientation, width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        switch orientation {
        case .up:
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        case .right:
            // Core Graphics counts up from the bottom left. Moving the origin to the top
            // left and turning a quarter clockwise puts the image's left edge along the
            // top and its top edge down the right side.
            context.translateBy(x: 0, y: CGFloat(height))
            context.rotate(by: -.pi / 2)
            context.draw(image, in: CGRect(x: 0, y: 0, width: height, height: width))
        }
        return context.makeImage()
    }
}
