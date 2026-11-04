//
//  PillPhotoAnalyzer.swift
//  MyPharmacist
//

import UIKit
import Vision

/// One pill from the photo and what it was recognized as.
nonisolated struct AnalyzedPill: Sendable {
    let box: CGRect
    let crop: CGImage
    let match: PillMatch
}

/// Finds the pills in a photo and recognizes each one by comparing it with the
/// medications' reference photos (Vision image feature prints, all on the device).
/// This is the swap point for a stronger identifier later, such as a cloud model.
///
/// An actor so the Vision work runs off the main thread and the reference prints are
/// computed once and reused.
actor PillPhotoAnalyzer {
    private let medications: [Medication]
    private let rule = PillMatchRule()
    private var references: [(medicationID: String, print: VNFeaturePrintObservation)]?

    init(medications: [Medication]) {
        self.medications = medications
    }

    /// Step 2 of a scan: the separate pill-sized objects in the photo, each cut out.
    /// Empty when there are none (or Vision can't run, as in the Simulator).
    func findPills(in photo: CGImage) -> [FoundPill] {
        (try? PillFinder.find(in: photo)) ?? []
    }

    /// Step 3 of a scan: recognizes each cut-out on its own, in the order given.
    func identify(_ pills: [FoundPill]) -> [AnalyzedPill] {
        let references = loadReferences()
        return pills.map { pill in
            var distances: [String: Float] = [:]
            if let print = Self.featurePrint(of: pill.crop, padding: Self.cropPadding) {
                for reference in references {
                    var distance: Float = 0
                    guard (try? print.computeDistance(&distance, to: reference.print)) != nil else { continue }
                    distances[reference.medicationID] = min(distances[reference.medicationID] ?? .infinity, distance)
                }
            }
            return AnalyzedPill(box: pill.box, crop: pill.crop, match: rule.match(distances))
        }
    }

    private func loadReferences() -> [(medicationID: String, print: VNFeaturePrintObservation)] {
        if let references { return references }
        var loaded: [(medicationID: String, print: VNFeaturePrintObservation)] = []
        for medication in medications {
            for name in medication.photos {
                guard let image = UIImage(named: name)?.cgImage, let print = Self.featurePrint(of: image, padding: 1) else { continue }
                loaded.append((medication.id, print))
            }
        }
        references = loaded
        return loaded
    }

    /// Every image is drawn the same way before comparing: centred on a small black
    /// square. Feature prints react strongly to resolution and framing (the same photo at
    /// half size measured 0.7 away), so the high-resolution reference photos and the
    /// smaller camera cut-outs are brought to one size, with the same margin around the
    /// pill. The reference photos already have that margin; tight cut-outs get it here.
    private static let normalizedSide = 128
    private static let cropPadding = 1.12

    private static func featurePrint(of image: CGImage, padding: Double) -> VNFeaturePrintObservation? {
        guard let normalized = normalized(image, padding: padding) else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        try? VNImageRequestHandler(cgImage: normalized).perform([request])
        return request.results?.first
    }

    private static func normalized(_ image: CGImage, padding: Double) -> CGImage? {
        let side = Double(normalizedSide)
        let scale = side / (Double(max(image.width, image.height)) * padding)
        let width = Double(image.width) * scale, height = Double(image.height) * scale
        guard let context = CGContext(data: nil, width: normalizedSide, height: normalizedSide, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.draw(image, in: CGRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height))
        return context.makeImage()
    }
}
