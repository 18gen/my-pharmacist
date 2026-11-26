//
//  ScanPhotoKeeper.swift
//  MyPharmacist
//

#if DEBUG
import CoreGraphics
import Foundation
import ImageIO
import os
import UniformTypeIdentifiers

/// Debug builds only, for measuring the pill search on a Mac (tools/pill-bench). Nothing
/// is kept unless the app is launched with an argument, and never in the photo library:
/// - `-keepScanPhotos` keeps every scan's photo, full size, inside the app
///   (Documents/ScanPhotos), each with a .json of its scale and what the search found.
///   Only while the app runs: opened again from the Home Screen, it keeps nothing.
/// - `-clearScanPhotos` deletes them on launch.
///
/// From the Mac, with the phone connected:
///   xcrun devicectl device process launch --device <phone> --terminate-existing \
///       com.genichihashi.MyPharmacist -- -keepScanPhotos
///   xcrun devicectl device copy from --device <phone> --domain-type appDataContainer \
///       --domain-identifier com.genichihashi.MyPharmacist --source Documents/ScanPhotos --destination <folder>
nonisolated enum ScanPhotoKeeper {
    static var isKeeping: Bool { ProcessInfo.processInfo.arguments.contains("-keepScanPhotos") }

    private static var folder: URL {
        URL.documentsDirectory.appending(path: "ScanPhotos", directoryHint: .isDirectory)
    }

    static func clearIfAsked() {
        guard ProcessInfo.processInfo.arguments.contains("-clearScanPhotos") else { return }
        try? FileManager.default.removeItem(at: folder)
        Log.scan.info("scan photos cleared")
    }

    /// Writes the photo and what the search made of it, away from the main thread.
    static func keep(_ photo: CapturedPhoto, search: PillSearch) {
        guard isKeeping else { return }
        let taken = Date.now
        Task.detached(priority: .utility) {
            let format = DateFormatter()
            format.locale = Locale(identifier: "en_US_POSIX")
            format.dateFormat = "yyyyMMdd-HHmmss-SSS"
            let name = "scan-" + format.string(from: taken)
            let outcome: String = switch search {
            case .found(let pills): "found \(pills.count)"
            case .noPills: "no pills"
            case .unclear(let reason): "retake: \(reason)"
            case .failed: "failed"
            }
            let sidecar: [String: Any] = [
                "widthMillimeters": photo.widthMillimeters,
                "app": outcome,
                "appBoxes": foundBoxes(search).map { [$0.minX, $0.minY, $0.width, $0.height] },
            ]
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                guard let upright = photo.region(CGRect(origin: .zero, size: photo.size)),
                      writeJPEG(upright, to: folder.appending(path: name + ".jpg")) else {
                    Log.scan.error("scan photo not kept: couldn't write it")
                    return
                }
                let json = try JSONSerialization.data(withJSONObject: sidecar, options: [.prettyPrinted, .sortedKeys])
                try json.write(to: folder.appending(path: name + ".json"))
                Log.scan.info("scan photo kept as \(name, privacy: .public): \(outcome, privacy: .public)")
            } catch {
                Log.scan.error("scan photo not kept: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func foundBoxes(_ search: PillSearch) -> [CGRect] {
        if case .found(let pills) = search { pills.map(\.box) } else { [] }
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }
}
#endif
