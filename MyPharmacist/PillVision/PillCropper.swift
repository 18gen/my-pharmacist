//
//  PillCropper.swift
//  MyPharmacist
//

import CoreGraphics
import CoreText
import Foundation

/// Makes the pictures a pill is recognized from: one of each pill, cut from the
/// full-size photo, and one of all of them together with numbers.
nonisolated enum PillCropper {
    /// The picture's side is this many times the pill's length, so the pill has some of
    /// what it lies on around it and its edge is never at the picture's edge.
    static let sideOverLength = 1.45
    /// Pictures are enlarged to at least this and reduced to at most this. Enlarging
    /// adds nothing the camera didn't catch, but the model reads small text better large.
    static let smallestSide = 384
    static let largestSide = 512
    /// A pill at least this much longer than wide is turned to lie flat, as text on it
    /// runs along its length and reads worse turned.
    static let leastElongation = 1.25
    /// How dark everything but the pill is made, so the pill next to it isn't taken for it.
    static let dimming = 0.5
    /// The lit area reaches this share of the pill's width beyond its outline, so the
    /// pill's own edge is never dimmed.
    static let outlineMargin = 0.08
    static let overviewSide = 1024

    /// One pill in the middle of a square picture, lying flat if it is long, with its
    /// surroundings dimmed. Where the square reaches past the photo it is plain grey:
    /// the pill stays in the middle.
    static func picture(of pill: FoundPill, in photo: CapturedPhoto) -> CGImage? {
        let scale = photo.size.width / pill.searchedSize.width
        let centre = CGPoint(x: pill.shape.centre.x * scale, y: pill.shape.centre.y * scale)
        let side = max(16, pill.shape.length * scale * sideOverLength)
        let isLong = pill.shape.length >= leastElongation * max(1, pill.shape.width)
        let angle = isLong ? pill.shape.angle : 0

        // What the square covers once turned, cut from the full-size photo.
        let reach = side * (abs(cos(angle)) + abs(sin(angle)))
        let wanted = CGRect(x: centre.x - reach / 2, y: centre.y - reach / 2, width: reach, height: reach).integral
        let inside = wanted.intersection(CGRect(origin: .zero, size: photo.size))
        // The pill's outline grown a little, so that its own edge is never dimmed.
        let margin = max(1, Int((outlineMargin * pill.shape.width).rounded()))
        let grown = pill.outline.padded(by: margin)
        guard let piece = photo.region(wanted), let outline = grown.mask.dilated(by: margin).grayImage() else { return nil }

        let output = min(largestSide, max(smallestSide, Int(side.rounded())))
        guard let context = CGContext.bitmap(width: output, height: output) else { return nil }
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: output, height: output))

        // From here, coordinates are the photo's own: pixels from its top left. The
        // pill's middle goes to the picture's middle, turned by the pill's angle.
        context.translateBy(x: 0, y: CGFloat(output))
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: CGFloat(output) / 2, y: CGFloat(output) / 2)
        context.rotate(by: -angle)
        context.scaleBy(x: CGFloat(output) / side, y: CGFloat(output) / side)
        context.translateBy(x: -centre.x, y: -centre.y)

        draw(piece, in: inside, context: context)
        context.setFillColor(gray: 0, alpha: dimming)
        context.fill(inside)
        // The pill itself, drawn again at full brightness through its outline.
        let outlineRect = CGRect(x: Double(grown.x) * scale, y: Double(grown.y) * scale,
                                 width: Double(grown.mask.width) * scale, height: Double(grown.mask.height) * scale)
        context.saveGState()
        context.translateBy(x: outlineRect.minX, y: outlineRect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.clip(to: CGRect(origin: .zero, size: outlineRect.size), mask: outline)
        context.draw(piece, in: CGRect(x: inside.minX - outlineRect.minX, y: outlineRect.maxY - inside.maxY,
                                       width: inside.width, height: inside.height))
        context.restoreGState()
        return context.makeImage()
    }

    /// All the pills in one picture, each boxed and numbered beside (not on) it, so the
    /// model can say whether something pill-like has no number: a pill that was missed.
    static func overview(of pills: [FoundPill], in photo: CapturedPhoto) -> CGImage? {
        guard !pills.isEmpty else { return nil }
        let working = photo.working
        let width = Double(working.width), height = Double(working.height)
        let boxes = pills.map { CGRect(x: $0.box.minX * width, y: $0.box.minY * height, width: $0.box.width * width, height: $0.box.height * height) }
        let around = boxes.dropFirst().reduce(boxes[0]) { $0.union($1) }
        // Room around the pills for a missed one to show, and for the numbers.
        let margin = max(around.width, around.height) * 0.25 + 40
        let region = around.insetBy(dx: -margin, dy: -margin).integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard let piece = working.cropping(to: region) else { return nil }
        let scale = min(1, Double(overviewSide) / Double(max(region.width, region.height)))
        let outputWidth = max(1, Int(region.width * scale)), outputHeight = max(1, Int(region.height * scale))
        guard let context = CGContext.bitmap(width: outputWidth, height: outputHeight) else { return nil }
        context.draw(piece, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        let fontSize = max(14, Double(min(outputWidth, outputHeight)) * 0.045)
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        for (index, box) in boxes.enumerated() {
            // Core Graphics counts up from the bottom.
            let shown = CGRect(x: (box.minX - region.minX) * scale, y: Double(outputHeight) - (box.maxY - region.minY) * scale,
                               width: box.width * scale, height: box.height * scale).insetBy(dx: -4, dy: -4)
            context.setStrokeColor(gray: 1, alpha: 1)
            context.setLineWidth(2)
            context.stroke(shown)

            let attributes = [kCTFontAttributeName as NSAttributedString.Key: font,
                              kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 1, alpha: 1)] as [NSAttributedString.Key: Any]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "\(index + 1)", attributes: attributes))
            let text = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            // A dark tag above the box's top-left corner, or below it at the top edge.
            let tag = CGSize(width: text.width + fontSize * 0.6, height: fontSize * 1.3)
            var origin = CGPoint(x: max(0, shown.minX), y: shown.maxY + 2)
            if origin.y + tag.height > Double(outputHeight) { origin.y = max(0, shown.minY - tag.height - 2) }
            context.setFillColor(gray: 0, alpha: 0.85)
            context.fill(CGRect(origin: origin, size: tag))
            context.textPosition = CGPoint(x: origin.x + fontSize * 0.3 - text.minX, y: origin.y + fontSize * 0.3)
            CTLineDraw(line, context)
        }
        return context.makeImage()
    }

    /// Draws an image where `rect` is, in a context whose coordinates count down from
    /// the top (Core Graphics would draw it upside down there).
    private static func draw(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
}
