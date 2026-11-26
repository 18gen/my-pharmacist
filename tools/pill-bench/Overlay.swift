//
//  Overlay.swift
//  pill-bench
//
//  A picture of what the search saw in one photo, at the size it searched:
//  - blue: the surface (Vision's large object: a hand, a plate)
//  - cyan outline: Vision's pill-sized objects
//  - magenta: what clearly differs from the surface by colour; yellow: what differs faintly
//  - ellipses: each pill-sized area, green if kept, grey if ignored, orange if it asked
//    for a retake, labelled A1, A2… as in the results
//  - green boxes: the pills the app would circle, numbered
//  - red rings: real pills (made-up photos know where) that weren't circled
//

import CoreGraphics
import CoreText
import Foundation

enum Overlay {
    private static let banner = 60

    static func draw(_ diagnosis: Diagnosis, row: Row, label: Label) -> CGImage? {
        let width = diagnosis.picture.width, height = diagnosis.picture.height
        var bytes = diagnosis.picture.bytes

        func tint(_ index: Int, _ colour: (Double, Double, Double), _ amount: Double) {
            for channel in 0..<3 {
                let before = Double(bytes[index * 4 + channel])
                bytes[index * 4 + channel] = UInt8(max(0, min(255, before * (1 - amount) + [colour.0, colour.1, colour.2][channel] * amount)))
            }
        }
        func paint(_ blob: Blob, _ colour: (Double, Double, Double), _ amount: Double, edgeOnly: Bool = false) {
            let mask = blob.mask
            for y in 0..<mask.height {
                for x in 0..<mask.width where mask[x, y] {
                    if edgeOnly, mask.contains(x: x - 1, y: y), mask.contains(x: x + 1, y: y),
                       mask.contains(x: x, y: y - 1), mask.contains(x: x, y: y + 1) { continue }
                    let px = blob.x + x, py = blob.y + y
                    guard px >= 0, py >= 0, px < width, py < height else { continue }
                    tint(py * width + px, colour, amount)
                }
            }
        }

        // The photo a little darker, so the marks stand out.
        for index in 0..<(width * height) {
            for channel in 0..<3 { bytes[index * 4 + channel] = UInt8(Double(bytes[index * 4 + channel]) * 0.72) }
        }
        if let surface = diagnosis.lift.surface {
            for y in 0..<height {
                for x in 0..<width where surface[x, y] { tint(y * width + x, (40, 110, 255), 0.22) }
            }
        }
        diagnosis.colour.faint.forEach { paint($0, (255, 220, 0), 0.45) }
        diagnosis.colour.blobs.forEach { paint($0, (255, 0, 200), 0.45) }
        diagnosis.lift.objects.forEach { paint($0, (0, 240, 255), 1, edgeOnly: true) }

        guard let base = ColourImage(width: width, height: height, bytes: bytes).cgImage(),
              let context = CGContext.bitmap(width: width, height: height + banner) else { return nil }
        context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(bannerColour(row.status))
        context.fill(CGRect(x: 0, y: height, width: width, height: banner))

        // From here on, the origin is the top left; the photo starts `banner` down.
        context.translateBy(x: 0, y: CGFloat(height + banner))
        context.scaleBy(x: 1, y: -1)
        let top = CGFloat(banner)
        let white = CGColor(gray: 1, alpha: 1)
        text(row.file, at: CGPoint(x: 10, y: 24), size: 17, colour: white, bold: true, in: context)
        let truth = row.truth.map { " · really \($0)" } ?? ""
        text("\(row.outcome)\(truth) · \(row.status.rawValue)", at: CGPoint(x: 10, y: 48), size: 16, colour: white, in: context)

        // Each pill-sized area, as the ellipse that spreads the way it does.
        for (number, area) in diagnosis.areas.enumerated() where area.verdict != .notAPill {
            let colour: CGColor = switch area.outcome {
            case .pills: CGColor(red: 0.2, green: 1, blue: 0.3, alpha: 1)
            case .ignored: CGColor(gray: 0.85, alpha: 1)
            case .retake: CGColor(red: 1, green: 0.55, blue: 0, alpha: 1)
            }
            let shape = area.shape
            context.saveGState()
            context.translateBy(x: shape.centre.x, y: shape.centre.y + top)
            context.rotate(by: shape.angle)
            context.setStrokeColor(colour)
            context.setLineWidth(2)
            if case .ignored = area.outcome { context.setLineDash(phase: 0, lengths: [4, 3]) }
            context.strokeEllipse(in: CGRect(x: -shape.length / 2 - 3, y: -shape.width / 2 - 3, width: shape.length + 6, height: shape.width + 6))
            context.restoreGState()
            text("A\(number + 1)", at: CGPoint(x: shape.centre.x + shape.length / 2 + 4, y: shape.centre.y + top + 5),
                 size: 13, colour: colour, bold: true, in: context)
        }

        // The pills the app would circle.
        for (number, box) in diagnosis.foundBoxes.enumerated() {
            let rect = CGRect(x: box.minX * Double(width), y: box.minY * Double(height) + top,
                              width: box.width * Double(width), height: box.height * Double(height)).insetBy(dx: -5, dy: -5)
            context.setStrokeColor(CGColor(red: 0.2, green: 1, blue: 0.3, alpha: 1))
            context.setLineWidth(3)
            context.stroke(rect)
            text("\(number + 1)", at: CGPoint(x: rect.minX + 2, y: rect.minY - 4), size: 15,
                 colour: CGColor(red: 0.2, green: 1, blue: 0.3, alpha: 1), bold: true, in: context)
        }

        // Real pills that weren't circled.
        for box in label.boxes where !diagnosis.foundBoxes.contains(where: { $0.contains(CGPoint(x: box.midX, y: box.midY)) }) {
            let across = box.width * Double(width), down = box.height * Double(height)
            let side = max(across, down) + 18
            let middle = CGPoint(x: box.midX * Double(width), y: box.midY * Double(height) + top)
            let rect = CGRect(x: middle.x - side / 2, y: middle.y - side / 2, width: side, height: side)
            context.setStrokeColor(CGColor(red: 1, green: 0.15, blue: 0.15, alpha: 1))
            context.setLineWidth(3)
            context.setLineDash(phase: 0, lengths: [7, 4])
            context.strokeEllipse(in: rect)
            context.setLineDash(phase: 0, lengths: [])
        }
        return context.makeImage()
    }

    private static func bannerColour(_ status: Row.Status) -> CGColor {
        switch status {
        case .right, .rightRetake: CGColor(red: 0.05, green: 0.35, blue: 0.15, alpha: 1)
        case .missed, .noPills, .failed: CGColor(red: 0.6, green: 0.05, blue: 0.05, alpha: 1)
        case .retake, .extra: CGColor(red: 0.6, green: 0.3, blue: 0, alpha: 1)
        case .unlabelled: CGColor(gray: 0.2, alpha: 1)
        }
    }

    /// Text with its baseline at `point`, on a dark band so it reads on any photo. The
    /// context's origin is at the top left.
    private static func text(_ string: String, at point: CGPoint, size: CGFloat, colour: CGColor, bold: Bool = false, in context: CGContext) {
        let font = CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
        var ascent: CGFloat = 0, descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        context.saveGState()
        context.setFillColor(CGColor(gray: 0, alpha: 0.55))
        context.fill(CGRect(x: point.x - 2, y: point.y - ascent - 1, width: width + 4, height: ascent + descent + 2))
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = point
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
