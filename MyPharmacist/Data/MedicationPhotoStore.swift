//
//  MedicationPhotoStore.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Where the photos of the person's own tablets are kept: PNG files in the app's own
/// storage on the device, never in the photo library. A medication's photos are deleted
/// with it.
nonisolated struct MedicationPhotoStore: Sendable {
    let directory: URL

    /// In Application Support, in a folder of its own.
    static let standard = MedicationPhotoStore(
        directory: URL.applicationSupportDirectory.appending(path: "Medication Photos", directoryHint: .isDirectory)
    )

    /// Read photos, so lists don't read files again on every redraw. `nonisolated(unsafe)`
    /// is safe here: NSCache is documented as thread-safe.
    nonisolated(unsafe) private static let cache = NSCache<NSString, UIImage>()

    /// Keeps a photo and returns how to find it again.
    func save(_ image: CGImage) throws -> MedicationPhoto {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".png"
        guard let destination = CGImageDestinationCreateWithURL(url(for: name) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return .file(name)
    }

    func image(_ photo: MedicationPhoto) -> UIImage? {
        switch photo {
        case .asset(let name):
            return UIImage(named: name)
        case .file(let name):
            let key = url(for: name).path as NSString
            if let cached = Self.cache.object(forKey: key) { return cached }
            guard let image = UIImage(contentsOfFile: url(for: name).path) else { return nil }
            Self.cache.setObject(image, forKey: key)
            return image
        }
    }

    /// Deletes a photo the person took; built-in photos stay.
    func delete(_ photo: MedicationPhoto) {
        guard case .file(let name) = photo else { return }
        Self.cache.removeObject(forKey: url(for: name).path as NSString)
        try? FileManager.default.removeItem(at: url(for: name))
    }

    private func url(for name: String) -> URL {
        directory.appending(path: name, directoryHint: .notDirectory)
    }
}
