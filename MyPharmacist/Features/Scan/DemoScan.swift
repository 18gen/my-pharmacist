//
//  DemoScan.swift
//  MyPharmacist
//

#if DEBUG
import SwiftUI
import UIKit

/// Debug builds only: results for a made-up photo built from the reference pictures, so
/// the results page can be seen in the Simulator, which can't run the camera or Vision's
/// pill finding. Launch with `-demoScan` to open straight into it. Nothing is recorded.
enum DemoScan {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demoScan") }

    /// One of each kind of line: two of the morning pills, a second metoclopramide, the
    /// as-needed ondansetron and a white pill not on the list. Dexamethasone is left out
    /// so it shows as missing. In reading order, because results number pills in the
    /// order given.
    static func show(in flow: ScanFlow) {
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
        flow.setOpen(true)
        flow.showResults(pills, photo: photo.cgImage!, records: false)
    }

    /// The reference picture, or a plain white pill for the one not on the list.
    private static func pillImage(_ name: String?, side: CGFloat) -> UIImage {
        if let name, let image = UIImage(named: name) { return image }
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            UIColor(white: 0.96, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: side * 0.1, y: side * 0.1, width: side * 0.8, height: side * 0.8)).fill()
        }
    }
}
#endif
