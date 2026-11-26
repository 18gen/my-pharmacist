//
//  Training.swift
//  pill-bench
//
//  Pictures for training a pill detector (Create ML's object detector): real photos in
//  which the app circled every pill and nothing else, so their boxes are the whole
//  truth, with more pills pasted on them, apart, touching and lying over each other.
//  The pasted pills are cut-outs from those photos (the pills as the camera saw them)
//  and the demo medications' own pictures. Written as Create ML wants: the pictures and
//  annotations.json in one folder, every box in pixels, by its middle.
//

import CoreGraphics
import Foundation
import ImageIO

enum TrainingData {
    /// The longer side of each picture written.
    static let side = 1024

    struct Background {
        let url: URL
        /// Normalized, origin at the top left.
        let boxes: [CGRect]
    }

    struct Cutout {
        let image: CGImage
        /// Scale to the width of the picture it lands on: pixels across that picture
        /// per pixel of the cut-out, times the picture's width.
        let perPictureWidth: Double
        /// Points on the pill's edge, from the cut-out's middle, y down: for a box that
        /// fits the pill however it is turned.
        let outline: [CGPoint]

        init?(image: CGImage, perPictureWidth: Double) {
            self.image = image
            self.perPictureWidth = perPictureWidth
            outline = Self.edge(of: image)
            if outline.isEmpty { return nil }
        }

        /// Up to about 240 of the pixels at the edge of what isn't see-through.
        private static func edge(of image: CGImage) -> [CGPoint] {
            let width = image.width, height = image.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext.bitmap(width: width, height: height, transparent: true, data: buffer.baseAddress) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard drawn else { return [] }
            func solid(_ x: Int, _ y: Int) -> Bool {
                x >= 0 && y >= 0 && x < width && y < height && bytes[(y * width + x) * 4 + 3] > 128
            }
            var points: [CGPoint] = []
            for y in 0..<height {
                for x in 0..<width where solid(x, y) && (!solid(x - 1, y) || !solid(x + 1, y) || !solid(x, y - 1) || !solid(x, y + 1)) {
                    points.append(CGPoint(x: Double(x) + 0.5 - Double(width) / 2, y: Double(y) + 0.5 - Double(height) / 2))
                }
            }
            let stride = max(1, points.count / 240)
            return Swift.stride(from: 0, to: points.count, by: stride).map { points[$0] }
        }
    }

    /// The demo medications' pictures and their printed size (design/demo-pills).
    static let assetSizes: [String: Double] = [
        "exemestane-25": 6, "dexamethasone-1-5": 6, "metoclopramide-10": 8, "ondansetron-8": 13,
        "capecitabine-500": 11, "dexamethasone-4": 6, "allopurinol-300": 11,
    ]

    static func make(labels: [URL], crops: [URL], assets: URL?, out: URL, count: Int, seed: UInt64) -> Bool {
        do {
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        } catch {
            print("Can't make \(out.path): \(error.localizedDescription)")
            return false
        }
        let backgrounds = labels.flatMap(readBackgrounds)
        var cutouts = crops.flatMap(readCrops)
        if let assets { cutouts += readAssets(assets) }
        guard !backgrounds.isEmpty, !cutouts.isEmpty else {
            print("Need photos with labels (\(backgrounds.count)) and pills to paste (\(cutouts.count))")
            return false
        }
        print("\(backgrounds.count) photos to paste on, \(cutouts.count) pills to paste")

        var random = SplitMix(state: seed)
        var annotations: [[String: Any]] = []
        var pictures: [URL: CGImage] = [:]
        for index in 0..<count {
            let background = backgrounds[Int(random.next() % UInt64(backgrounds.count))]
            if pictures[background.url] == nil { pictures[background.url] = Picture.upright(background.url) }
            guard let photo = pictures[background.url],
                  let (image, boxes) = compose(on: photo, boxes: background.boxes, cutouts: cutouts, random: &random) else { continue }
            let name = String(format: "train-%05d.jpg", index)
            guard Picture.writeJPEG(image, to: out.appending(path: name), quality: 0.88) else { continue }
            annotations.append([
                "imagefilename": name,
                "annotation": boxes.map { box in
                    ["label": "pill", "coordinates": ["x": box.midX, "y": box.midY, "width": box.width, "height": box.height]]
                },
            ])
            if index % 200 == 199 { print("\(index + 1) pictures") }
        }
        guard let json = try? JSONSerialization.data(withJSONObject: annotations, options: [.prettyPrinted]),
              (try? json.write(to: out.appending(path: "annotations.json"))) != nil else {
            print("Can't write annotations.json")
            return false
        }
        print("Made \(annotations.count) pictures in \(out.path)")
        return true
    }

    // MARK: Composing one picture

    /// The photo at `side` on its longer side, perhaps mirrored, with 0 to 4 pills pasted:
    /// most against or over another pill. Boxes in the picture's pixels, origin top left.
    private static func compose(on photo: CGImage, boxes normalized: [CGRect], cutouts: [Cutout],
                                random: inout SplitMix) -> (CGImage, [CGRect])? {
        let size = PhotoSize.fitting(photo, maxSide: side)
        let width = Double(size.width), height = Double(size.height)
        guard let context = CGContext.bitmap(width: size.width, height: size.height) else { return nil }
        let mirrored = Double.random(in: 0..<1, using: &random) < 0.5
        context.saveGState()
        if mirrored {
            context.translateBy(x: width, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        context.draw(photo, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.restoreGState()
        var boxes = normalized.map { box in
            CGRect(x: (mirrored ? 1 - box.maxX : box.minX) * width, y: box.minY * height, width: box.width * width, height: box.height * height)
        }
        // Which pill each pixel shows, last drawn on top (the photo's own pills as the
        // ellipse in their box), so a pill mostly hidden under others can be dropped.
        var owner = [Int16](repeating: -1, count: size.width * size.height)
        var drawnPixels: [Int] = []
        for (index, box) in boxes.enumerated() {
            var count = 0
            for y in max(0, Int(box.minY))..<min(size.height, Int(box.maxY)) {
                for x in max(0, Int(box.minX))..<min(size.width, Int(box.maxX)) {
                    let dx = (Double(x) + 0.5 - box.midX) / (box.width / 2), dy = (Double(y) + 0.5 - box.midY) / (box.height / 2)
                    if dx * dx + dy * dy <= 1 {
                        owner[y * size.width + x] = Int16(index)
                        count += 1
                    }
                }
            }
            drawnPixels.append(count)
        }

        let pasted = [0, 1, 1, 2, 2, 3, 3, 4][Int(random.next() % 8)]
        for _ in 0..<pasted {
            let cutout = cutouts[Int(random.next() % UInt64(cutouts.count))]
            let scale = cutout.perPictureWidth * width * Double.random(in: 0.85...1.15, using: &random)
            let across = Double(cutout.image.width) * scale, down = Double(cutout.image.height) * scale
            let angle = Double.random(in: 0..<(2 * .pi), using: &random)
            // The pill's own outline, turned as it will be drawn (Core Graphics turns
            // counterclockwise with y up; the picture's y runs down).
            let turned = cutout.outline.map { point -> CGPoint in
                let x = point.x * scale, y = -point.y * scale
                return CGPoint(x: x * cos(angle) - y * sin(angle), y: -(x * sin(angle) + y * cos(angle)))
            }
            let reachLeft = turned.map(\.x).min() ?? 0, reachRight = turned.map(\.x).max() ?? 0
            let reachUp = turned.map(\.y).min() ?? 0, reachDown = turned.map(\.y).max() ?? 0
            let boxAcross = reachRight - reachLeft, boxDown = reachDown - reachUp

            // Against another pill (touching or lying partly over it), or anywhere in
            // the middle of the picture.
            var middle: CGPoint?
            for _ in 0..<12 {
                let mode = Double.random(in: 0..<1, using: &random)
                var candidate: CGPoint
                if let other = boxes.randomElement(using: &random), mode < 0.75 {
                    let reach = (min(other.width, other.height) + min(boxAcross, boxDown)) / 2
                    let factor = mode < 0.45 ? Double.random(in: 0.85...1.0, using: &random) : Double.random(in: 0.5...0.85, using: &random)
                    let direction = Double.random(in: 0..<(2 * .pi), using: &random)
                    candidate = CGPoint(x: other.midX + cos(direction) * reach * factor, y: other.midY + sin(direction) * reach * factor)
                } else {
                    candidate = CGPoint(x: Double.random(in: 0.2...0.8, using: &random) * width,
                                        y: Double.random(in: 0.25...0.75, using: &random) * height)
                }
                let left = candidate.x + reachLeft, right = candidate.x + reachRight
                let top = candidate.y + reachUp, bottom = candidate.y + reachDown
                if left > 4, right < width - 4, top > 4, bottom < height - 4 {
                    middle = candidate
                    break
                }
            }
            guard let middle, let pill = shaded(cutout.image, random: &random) else { continue }

            context.saveGState()
            let shadowAlpha = Double.random(in: 0.2...0.45, using: &random)
            context.setShadow(offset: CGSize(width: Double.random(in: 1...5, using: &random), height: -Double.random(in: 1...6, using: &random)),
                              blur: Double.random(in: 3...9, using: &random), color: CGColor(gray: 0, alpha: shadowAlpha))
            // Core Graphics counts up from the bottom.
            context.translateBy(x: middle.x, y: height - middle.y)
            context.rotate(by: angle)
            context.draw(pill, in: CGRect(x: -across / 2, y: -down / 2, width: across, height: down))
            context.restoreGState()

            boxes.append(CGRect(x: middle.x + reachLeft, y: middle.y + reachUp, width: boxAcross, height: boxDown))
            // Its pixels, drawn the same way into a mask, now show this pill.
            var mask = [UInt8](repeating: 0, count: size.width * size.height * 4)
            let masked = mask.withUnsafeMutableBytes { buffer -> Bool in
                guard let alpha = CGContext.bitmap(width: size.width, height: size.height, transparent: true, data: buffer.baseAddress) else { return false }
                alpha.translateBy(x: middle.x, y: height - middle.y)
                alpha.rotate(by: angle)
                alpha.draw(pill, in: CGRect(x: -across / 2, y: -down / 2, width: across, height: down))
                return true
            }
            var count = 0
            if masked {
                let index = Int16(boxes.count - 1)
                for pixel in 0..<(size.width * size.height) where mask[pixel * 4 + 3] > 128 {
                    owner[pixel] = index
                    count += 1
                }
            }
            drawnPixels.append(count)
        }
        guard let image = context.makeImage() else { return nil }
        // A pill with less than 40% of itself still in sight is no longer to be found.
        var visible = [Int](repeating: 0, count: boxes.count)
        for pixel in owner where pixel >= 0 { visible[Int(pixel)] += 1 }
        let kept = boxes.indices.filter { drawnPixels[$0] > 0 && Double(visible[$0]) >= 0.4 * Double(drawnPixels[$0]) }.map { boxes[$0] }
        return (image, kept)
    }

    /// The cut-out a little lighter or darker, as the light where it lands might make it.
    private static func shaded(_ image: CGImage, random: inout SplitMix) -> CGImage? {
        guard let context = CGContext.bitmap(width: image.width, height: image.height, transparent: true) else { return nil }
        let whole = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.draw(image, in: whole)
        context.setBlendMode(.sourceAtop)
        let change = Double.random(in: -0.18...0.12, using: &random)
        context.setFillColor(CGColor(gray: change < 0 ? 0 : 1, alpha: abs(change)))
        context.fill(whole)
        return context.makeImage()
    }

    // MARK: Reading what to work from

    /// labels.json from `pill-bench run` (its training folder).
    private static func readBackgrounds(_ url: URL) -> [Background] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("Can't read \(url.path)")
            return []
        }
        return entries.compactMap { entry in
            guard let path = entry["file"] as? String, let boxes = entry["boxes"] as? [[Double]] else { return nil }
            return Background(url: URL(filePath: path), boxes: boxes.compactMap {
                $0.count == 4 ? CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) : nil
            })
        }
    }

    /// Cut-outs from `pill-bench run`, named `…-w<width of the picture searched>.png`.
    private static func readCrops(_ folder: URL) -> [Cutout] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "png" }.compactMap { file in
            let stem = file.deletingPathExtension().lastPathComponent
            guard let mark = stem.range(of: "-w", options: .backwards), let sourceWidth = Double(stem[mark.upperBound...]),
                  let source = CGImageSourceCreateWithURL(file as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return Cutout(image: image, perPictureWidth: 1 / sourceWidth)
        }
    }

    /// The demo medications' pictures, cut down to the tablet, at their printed size in
    /// a picture as wide as the camera frames for.
    private static func readAssets(_ folder: URL) -> [Cutout] {
        let sets = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return sets.compactMap { set -> Cutout? in
            let name = set.deletingPathExtension().lastPathComponent
            guard let medication = assetSizes.keys.first(where: { name.hasPrefix($0 + "-") }),
                  let millimeters = assetSizes[medication],
                  let image = Synthetic.trimmedPicture(set.appending(path: "\(name).png")) else { return nil }
            let perPixel = millimeters / Double(max(image.width, image.height))
            return Cutout(image: image, perPictureWidth: perPixel / CapturedPhoto.assumedWidthMillimeters)
        }
    }
}
