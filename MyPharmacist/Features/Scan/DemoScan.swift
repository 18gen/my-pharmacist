//
//  DemoScan.swift
//  MyPharmacist
//

#if DEBUG
import SwiftUI
import UIKit

/// Debug builds only: results for a made-up photo built from the reference pictures,
/// so the results screen can be seen in the Simulator, which can't run the camera or
/// Vision's pill finding. Launch with `-demoScan` to open straight into it.
enum DemoScan {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demoScan") }

    /// Three of the morning pills, a second capecitabine, and a white pill not on the
    /// list; dexamethasone is left out so it shows as missing.
    static func show(in flow: ScanFlow) {
        let size = CGSize(width: 1080, height: 1440)
        let placed: [(photo: String?, id: String?, rect: CGRect)] = [
            ("capecitabine-500-2", "capecitabine-500", CGRect(x: 120, y: 300, width: 300, height: 300)),
            ("ondansetron-8-2", "ondansetron-8", CGRect(x: 620, y: 320, width: 280, height: 280)),
            ("allopurinol-300-1", "allopurinol-300", CGRect(x: 150, y: 820, width: 260, height: 260)),
            ("capecitabine-500-1", "capecitabine-500", CGRect(x: 600, y: 800, width: 300, height: 300)),
            (nil, nil, CGRect(x: 470, y: 1140, width: 140, height: 140)),
        ]
        let renderer = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        func pillImage(_ name: String?, side: CGFloat) -> UIImage {
            if let name, let image = UIImage(named: name) { return image }
            return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
                UIColor(white: 0.96, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: side * 0.1, y: side * 0.1, width: side * 0.8, height: side * 0.8)).fill()
            }
        }
        let photo = renderer.image { context in
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
                    .insetBy(dx: 0.012, dy: 0.012),
                crop: pillImage(item.photo, side: item.rect.width).cgImage!,
                match: PillMatch(medicationID: item.id, distance: nil)
            )
        }
        flow.setOpen(true)
        flow.showResults(photo: photo.cgImage!, pills: pills)
    }
}
#endif
