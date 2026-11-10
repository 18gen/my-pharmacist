//
//  DemoScan.swift
//  MyPharmacist
//

#if DEBUG
import SwiftUI
import UIKit

/// Debug builds only, for the Simulator, which has no camera. Nothing is recorded.
/// - `-demoScan` opens straight into the results page for a made-up photo.
/// - `-demoFind` runs a made-up photo of pills on a palm-coloured surface through the
///   real steps instead: finding the pills (by colour alone, as Vision's subject lifting
///   doesn't run in the Simulator), the question whether every pill is circled, and
///   recognizing each. Add `-noCloud` to keep it from using the OpenAI key.
/// - `-demoRetake` does the same with the palm empty, so the photo has to be taken
///   again: the camera view with its moving picture, and Retake and Cancel.
/// - `-demoOpenClose` opens the camera a second after launch and closes it 2.5 seconds
///   later, to watch (or record) the button growing into the camera picture and back.
/// - `-demoChecking` opens on the results page standing ready while the pills are
///   checked, and stays there.
enum DemoScan {
    static var isRequested: Bool { showsResults || findsPills || retakes || opensAndCloses || checks }
    private static var checks: Bool { ProcessInfo.processInfo.arguments.contains("-demoChecking") }
    private static var opensAndCloses: Bool { ProcessInfo.processInfo.arguments.contains("-demoOpenClose") }
    private static var showsResults: Bool { ProcessInfo.processInfo.arguments.contains("-demoScan") }
    private static var findsPills: Bool { ProcessInfo.processInfo.arguments.contains("-demoFind") }
    private static var retakes: Bool { ProcessInfo.processInfo.arguments.contains("-demoRetake") }

    static func run(in flow: ScanFlow) {
        if checks {
            let sample = samplePills()
            flow.showForPreview(.checking(FoundPills(photo: sample.photo, boxes: sample.pills.map(\.box))))
        } else if opensAndCloses {
            Task {
                try? await Task.sleep(for: .seconds(1))
                withAnimation(ScanLayout.openingAnimation) { flow.setOpen(true) }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(ScanLayout.openingAnimation) { flow.setOpen(false) }
            }
        } else if findsPills || retakes {
            Task { await find(in: flow, empty: retakes) }
        } else {
            show(in: flow)
        }
    }

    /// The sample pills at about their real sizes, two of them touching, on a surface
    /// the colour of a palm that is lit from below.
    static func find(in flow: ScanFlow, empty: Bool = false) async {
        let size = CGSize(width: 1134, height: 2016)   // 87.5 mm wide: about 13 pixels a millimetre
        let placed: [(photo: String?, middle: CGPoint, millimeters: CGFloat)] = [
            ("exemestane-25-1", CGPoint(x: 330, y: 800), 6),
            ("dexamethasone-1-5-1", CGPoint(x: 780, y: 760), 6),
            ("metoclopramide-10-1", CGPoint(x: 420, y: 1200), 8),
            ("metoclopramide-10-2", CGPoint(x: 524, y: 1200), 8),
            ("ondansetron-8-1", CGPoint(x: 800, y: 1260), 9),
            (nil, CGPoint(x: 600, y: 1560), 7),
        ].filter { _ in !empty }
        let photo = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
            .image { context in
                let colours = [UIColor(red: 0.66, green: 0.50, blue: 0.42, alpha: 1).cgColor,
                               UIColor(red: 0.84, green: 0.65, blue: 0.55, alpha: 1).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colours, locations: [0, 1]) {
                    context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                }
                for item in placed {
                    let side = item.millimeters * size.width / 87.5
                    pillImage(item.photo, side: side, trimmed: true)
                        .draw(in: CGRect(x: item.middle.x - side / 2, y: item.middle.y - side / 2, width: side, height: side))
                }
            }
        guard let image = photo.cgImage, let captured = CapturedPhoto(image: image) else { return }
        flow.setOpen(true)
        await flow.check(captured)
    }

    /// Results for the made-up photo below.
    static func show(in flow: ScanFlow) {
        let sample = samplePills()
        flow.setOpen(true)
        flow.showResults(sample.pills, photo: sample.photo, records: false)
    }

    /// A made-up photo with one of each kind of line: two of the morning pills, a second
    /// metoclopramide, the as-needed ondansetron and a white pill not on the list. In
    /// reading order, because results number pills in the order given. Also used by the
    /// scan views' previews.
    static func samplePills() -> (photo: CGImage, pills: [AnalyzedPill]) {
        let size = CGSize(width: 1080, height: 1440)
        let placed: [(photo: String?, id: String?, rect: CGRect)] = [
            ("metoclopramide-10-1", "metoclopramide-10", CGRect(x: 140, y: 470, width: 240, height: 240)),
            ("exemestane-25-1", "exemestane-25", CGRect(x: 640, y: 480, width: 200, height: 200)),
            ("metoclopramide-10-2", "metoclopramide-10", CGRect(x: 120, y: 790, width: 240, height: 240)),
            ("ondansetron-8-1", "ondansetron-8", CGRect(x: 430, y: 800, width: 250, height: 250)),
            (nil, nil, CGRect(x: 760, y: 840, width: 140, height: 140)),
        ]
        let photo = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
            .image { context in
                UIColor(red: 0.85, green: 0.82, blue: 0.78, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                for item in placed {
                    pillImage(item.photo, side: item.rect.width).draw(in: item.rect)
                }
            }
        let pills = placed.map { item in
            AnalyzedPill(
                box: CGRect(x: item.rect.minX / size.width, y: item.rect.minY / size.height,
                            width: item.rect.width / size.width, height: item.rect.height / size.height)
                    .insetBy(dx: 0.02, dy: 0.02),
                crop: pillImage(item.photo, side: item.rect.width).cgImage!,
                match: PillMatch(medicationID: item.id, distance: nil)
            )
        }
        return (photo.cgImage!, pills)
    }

    /// The reference picture, or a plain white pill for the one not on the list.
    /// - Parameter trimmed: Without the clear margin around the reference picture's
    ///   pill, so the pill itself is `side` across.
    private static func pillImage(_ name: String?, side: CGFloat, trimmed: Bool = false) -> UIImage {
        if let name, let image = UIImage(named: name) {
            guard trimmed, let cgImage = image.cgImage, let tight = PillFinderTrim.tight(cgImage) else { return image }
            return UIImage(cgImage: tight)
        }
        let inset = trimmed ? 0 : side * 0.1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            UIColor(white: 0.96, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)).fill()
        }
    }
}

/// Cuts a picture down to what isn't clear in it.
private enum PillFinderTrim {
    static func tight(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 40 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // Square, so a round pill stays round when drawn into a square.
        let side = max(maxX - minX, maxY - minY) + 1
        let rect = CGRect(x: (minX + maxX + 1 - side) / 2, y: (minY + maxY + 1 - side) / 2, width: side, height: side)
        return image.cropping(to: rect.intersection(CGRect(x: 0, y: 0, width: width, height: height)))
    }
}
#endif
