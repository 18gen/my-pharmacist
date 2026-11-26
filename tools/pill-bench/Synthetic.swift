//
//  Synthetic.swift
//  pill-bench
//
//  Made-up photos for trying the bench before real ones exist: the demo pills' own
//  pictures, at their printed size, with a soft shadow, on four surfaces. They show
//  whether the rules work as meant (sizes, edges, touching, a white pill on a white desk);
//  they can't show what Vision does with a real hand, so they don't replace real photos.
//

import CoreGraphics
import Foundation
import ImageIO

enum Synthetic {
    /// As the camera view keeps a photo (9:16), at the width the camera frames for.
    static let width = 2268, height = 4032
    static let widthMillimeters = CapturedPhoto.assumedWidthMillimeters
    static var perMillimeter: Double { Double(width) / widthMillimeters }

    struct Tablet {
        let asset: String
        /// Longest side, as printed (design/demo-pills).
        let millimeters: Double
    }

    static let exemestane = Tablet(asset: "exemestane-25-1", millimeters: 6)
    static let dexamethasone15 = Tablet(asset: "dexamethasone-1-5-1", millimeters: 6)
    static let metoclopramide = Tablet(asset: "metoclopramide-10-1", millimeters: 8)
    static let ondansetron = Tablet(asset: "ondansetron-8-1", millimeters: 13)
    static let capecitabine = Tablet(asset: "capecitabine-500-1", millimeters: 11)
    static let dexamethasone4 = Tablet(asset: "dexamethasone-4-1", millimeters: 6)
    static let allopurinol = Tablet(asset: "allopurinol-300-1", millimeters: 11)

    struct Scene {
        let name: String
        /// Each tablet and where its middle is, in millimetres right of and below the
        /// photo's middle.
        let placed: [(tablet: Tablet, x: Double, y: Double)]
        /// Where the gaps between pills matter, the pills keep their places exactly.
        var exact = false
        var expectRetake: String?
        var note: String?
    }

    static let scenes: [Scene] = [
        Scene(name: "apart4", placed: [(exemestane, -12, -12), (dexamethasone15, 12, -12), (metoclopramide, -12, 12), (ondansetron, 12, 12)]),
        Scene(name: "sample4", placed: [(capecitabine, -14, -14), (dexamethasone4, 14, -14), (allopurinol, -14, 14), (ondansetron, 14, 14)]),
        Scene(name: "one", placed: [(exemestane, 0, 0)]),
        Scene(name: "close3", placed: [(metoclopramide, -5, 0), (metoclopramide, 5, 0), (dexamethasone15, 0, 16)], exact: true,
              note: "two pills 2 mm apart"),
        Scene(name: "touching3", placed: [(metoclopramide, -3.8, 0), (metoclopramide, 3.8, 0), (exemestane, 0, 16)], exact: true,
              expectRetake: "touching", note: "two pills touching"),
        Scene(name: "edge3", placed: [(exemestane, -6, -12), (metoclopramide, 12, 4), (ondansetron, -41, 10)], exact: true,
              expectRetake: "cutOff", note: "one pill half off the left edge"),
        Scene(name: "six", placed: [(exemestane, -14, -20), (dexamethasone15, 0, -20), (metoclopramide, 14, -20),
                                     (metoclopramide, -14, 0), (ondansetron, 6, 2), (allopurinol, -4, 21)]),
    ]

    enum Surface: String, CaseIterable {
        case palm, desk, dark, wood
    }

    static func make(into out: URL, pills: URL, seed: UInt64) -> Bool {
        do {
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        } catch {
            print("Can't make \(out.path): \(error.localizedDescription)")
            return false
        }
        var random = SplitMix(state: seed)
        var pictures: [String: CGImage] = [:]
        var made = 0
        for surface in Surface.allCases {
            for scene in scenes {
                for variant in 1...2 {
                    for item in scene.placed where pictures[item.tablet.asset] == nil {
                        let url = pills.appending(path: "\(item.tablet.asset).imageset/\(item.tablet.asset).png")
                        guard let picture = trimmed(url) else {
                            print("Can't read \(url.path)")
                            return false
                        }
                        pictures[item.tablet.asset] = picture
                    }
                    guard let (image, boxes) = render(scene, on: surface, pictures: pictures, random: &random) else {
                        print("Can't draw \(scene.name)")
                        return false
                    }
                    let name = "\(surface.rawValue)-\(scene.name)-\(variant)"
                    var sidecar: [String: Any] = [
                        "widthMillimeters": widthMillimeters, "pills": boxes.count, "surface": surface.rawValue,
                        "boxes": boxes.map { [$0.minX, $0.minY, $0.width, $0.height] },
                    ]
                    sidecar["expectRetake"] = scene.expectRetake
                    sidecar["note"] = scene.note
                    guard Picture.writeJPEG(image, to: out.appending(path: "\(name).jpg")),
                          let json = try? JSONSerialization.data(withJSONObject: sidecar, options: [.prettyPrinted, .sortedKeys]),
                          (try? json.write(to: out.appending(path: "\(name).json"))) != nil else {
                        print("Can't write \(name)")
                        return false
                    }
                    made += 1
                }
            }
        }
        print("Made \(made) photos in \(out.path)")
        return true
    }

    // MARK: Drawing

    /// The scene on the surface, and each pill's box (normalized, origin at the top left).
    private static func render(_ scene: Scene, on surface: Surface, pictures: [String: CGImage],
                               random: inout SplitMix) -> (CGImage, [CGRect])? {
        var bytes = background(surface, random: &random)
        // The whole group a little to one side, unless where it lies matters.
        let reach = scene.exact ? 0.0001 : 4
        let shift = (x: Double.random(in: -reach...reach, using: &random), y: Double.random(in: -1.5 * reach...1.5 * reach, using: &random))
        let made: [CGRect]? = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext.bitmap(width: width, height: height, data: buffer.baseAddress) else { return nil }
            if surface == .palm { drawCreases(in: context, random: &random) }
            var boxes: [CGRect] = []
            for item in scene.placed {
                guard let picture = pictures[item.tablet.asset] else { return nil }
                let wobble = scene.exact ? 0 : 1.5
                let x = (Double(width) / 2) + (item.x + shift.x + Double.random(in: -wobble...max(wobble, 0.0001), using: &random)) * perMillimeter
                let y = (Double(height) / 2) + (item.y + shift.y + Double.random(in: -wobble...max(wobble, 0.0001), using: &random)) * perMillimeter
                let scale = item.tablet.millimeters * perMillimeter / Double(max(picture.width, picture.height))
                let across = Double(picture.width) * scale, down = Double(picture.height) * scale
                let angle = Double.random(in: 0..<(2 * .pi), using: &random)

                context.saveGState()
                // Light from the top left: shadows fall a little right and down.
                context.setShadow(offset: CGSize(width: 0.25 * perMillimeter, height: -0.45 * perMillimeter), blur: 1.1 * perMillimeter,
                                  color: CGColor(gray: 0, alpha: surface == .dark ? 0.6 : 0.45))
                // Core Graphics counts up from the bottom.
                context.translateBy(x: x, y: Double(height) - y)
                context.rotate(by: angle)
                context.draw(picture, in: CGRect(x: -across / 2, y: -down / 2, width: across, height: down))
                context.restoreGState()

                let boxAcross = abs(across * cos(angle)) + abs(down * sin(angle))
                let boxDown = abs(across * sin(angle)) + abs(down * cos(angle))
                let box = CGRect(x: (x - boxAcross / 2) / Double(width), y: (y - boxDown / 2) / Double(height),
                                 width: boxAcross / Double(width), height: boxDown / Double(height))
                boxes.append(box.intersection(CGRect(x: 0, y: 0, width: 1, height: 1)))
            }
            return boxes
        }
        guard let boxes = made, let image = ColourImage(width: width, height: height, bytes: bytes).cgImage() else { return nil }
        return (image, boxes)
    }

    /// The surface, four bytes a pixel from the top left: its colour, blotches as large
    /// as a few pills, light falling off toward the bottom, and the camera's grain.
    private static func background(_ surface: Surface, random: inout SplitMix) -> [UInt8] {
        let blotches = SmoothNoise(columns: 9, rows: 16, random: &random)
        let fine = SmoothNoise(columns: 60, rows: 106, random: &random)
        let swirl = SmoothNoise(columns: 3, rows: 5, random: &random)
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        // A palm filling the middle of the view, the table around its top and bottom.
        let palmMiddle = (x: Double(width) / 2, y: Double(height) * 0.5), palmRadius = (x: Double(width) * 0.62, y: Double(height) * 0.42)
        for y in 0..<height {
            let v = Double(y) / Double(height)
            let light = 1.04 - 0.08 * v
            for x in 0..<width {
                let u = Double(x) / Double(width)
                let blotch = blotches(u, v), speckle = fine(u, v)
                var colour: (Double, Double, Double)
                switch surface {
                case .palm:
                    let skin = (222 - 18 * v + 9 * blotch, 172 - 20 * v + 7 * blotch + 2 * speckle, 146 - 18 * v + 6 * blotch + 2 * speckle)
                    let table = (128 + 6 * blotch, 120 + 6 * blotch, 110 + 5 * blotch)
                    let dx = (Double(x) - palmMiddle.x) / palmRadius.x, dy = (Double(y) - palmMiddle.y) / palmRadius.y
                    let inside = smoothstep(1.0, 0.94, dx * dx + dy * dy)
                    colour = (table.0 + (skin.0 - table.0) * inside, table.1 + (skin.1 - table.1) * inside, table.2 + (skin.2 - table.2) * inside)
                case .desk:
                    let edge = 1 - 0.06 * ((u - 0.5) * (u - 0.5) + (v - 0.5) * (v - 0.5)) * 4
                    colour = ((232 + 4 * blotch) * edge, (230 + 4 * blotch) * edge, (224 + 4 * blotch) * edge)
                case .dark:
                    colour = (32 + 3 * blotch + 2 * speckle, 36 + 3 * blotch + 2 * speckle, 54 + 4 * blotch + 2 * speckle)
                case .wood:
                    let grain = (sin(Double(x) * 0.02 + 6 * swirl(u, v) + 1.5 * speckle) + 1) / 2
                    colour = (150 + 32 * grain + 6 * blotch, 104 + 31 * grain + 5 * blotch, 66 + 26 * grain + 4 * blotch)
                }
                let grain = Double(Int(random.next() % 7) - 3)
                let index = (y * width + x) * 4
                bytes[index] = UInt8(max(0, min(255, colour.0 * light + grain)))
                bytes[index + 1] = UInt8(max(0, min(255, colour.1 * light + grain)))
                bytes[index + 2] = UInt8(max(0, min(255, colour.2 * light + grain)))
            }
        }
        return bytes
    }

    /// A few of a palm's lines, faint and soft.
    private static func drawCreases(in context: CGContext, random: inout SplitMix) {
        context.saveGState()
        context.setStrokeColor(CGColor(red: 0.55, green: 0.36, blue: 0.30, alpha: 0.35))
        context.setLineCap(.round)
        for _ in 0..<3 {
            let start = CGPoint(x: Double.random(in: 0...0.2, using: &random) * Double(width), y: Double.random(in: 0.3...0.7, using: &random) * Double(height))
            let end = CGPoint(x: Double.random(in: 0.8...1, using: &random) * Double(width), y: Double.random(in: 0.3...0.7, using: &random) * Double(height))
            let bend = CGPoint(x: Double(width) / 2, y: (start.y + end.y) / 2 + Double.random(in: -400...400, using: &random))
            context.setLineWidth(Double.random(in: 5...10, using: &random))
            context.move(to: start)
            context.addQuadCurve(to: end, control: bend)
            context.strokePath()
        }
        context.restoreGState()
    }

    /// The tablet's picture cut down to the tablet (what isn't see-through).
    private static func trimmed(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext.bitmap(width: width, height: height, transparent: true, data: buffer.baseAddress) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 128 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}

/// Values between -1 and 1 that change smoothly across the picture, `columns` by `rows`
/// bumps.
struct SmoothNoise {
    let columns: Int
    let rows: Int
    private let values: [Double]

    init(columns: Int, rows: Int, random: inout SplitMix) {
        self.columns = columns
        self.rows = rows
        values = (0..<((columns + 1) * (rows + 1))).map { _ in Double.random(in: -1...1, using: &random) }
    }

    /// At `u`, `v` between 0 and 1 across and down.
    func callAsFunction(_ u: Double, _ v: Double) -> Double {
        let fx = u * Double(columns), fy = v * Double(rows)
        let x = min(columns - 1, Int(fx)), y = min(rows - 1, Int(fy))
        let sx = smooth(fx - Double(x)), sy = smooth(fy - Double(y))
        let a = values[y * (columns + 1) + x], b = values[y * (columns + 1) + x + 1]
        let c = values[(y + 1) * (columns + 1) + x], d = values[(y + 1) * (columns + 1) + x + 1]
        return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}

/// A random number generator that gives the same numbers for the same seed.
struct SplitMix: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
