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
/// medications' reference photos. With an OpenAI key in Secrets.plist, a vision model
/// does the comparing (temporary, for demos); otherwise, or if it can't be reached,
/// Vision image feature prints on the device do. This is the swap point for a model
/// trained on ePillID later.
///
/// An actor so the Vision work runs off the main thread and the references are prepared
/// once and reused.
actor PillPhotoAnalyzer {
    private let medications: [Medication]
    private let rule = PillMatchRule()
    private let cloud: OpenAIPillIdentifier?
    private var references: [(medicationID: String, print: VNFeaturePrintObservation)]?
    private var cloudCandidates: [OpenAIPillIdentifier.Candidate]?

    init(medications: [Medication],
         cloud: OpenAIPillIdentifier? = OpenAIPillIdentifier.Configuration.fromBundle().map { OpenAIPillIdentifier(configuration: $0) }) {
        self.medications = medications
        self.cloud = cloud
    }

    /// Step 2 of a scan: the separate pill-sized objects in the photo, each cut out.
    /// Empty when there are none (or Vision can't run, as in the Simulator).
    func findPills(in photo: CGImage) -> [FoundPill] {
        (try? PillFinder.find(in: photo)) ?? []
    }

    /// Step 3 of a scan: recognizes each pill, in the order given.
    func identify(_ pills: [FoundPill], in photo: CGImage) async -> [AnalyzedPill] {
        if let cloud, !pills.isEmpty {
            do {
                let photos = pills.compactMap { pill in
                    OpenAIPillIdentifier.surroundingCrop(of: pill.box, in: photo).flatMap { OpenAIPillIdentifier.jpeg($0) }
                }
                if photos.count == pills.count {
                    let ids = try await cloud.identify(photos, among: cloudReferences())
                    return zip(pills, ids).map { pill, id in
                        AnalyzedPill(box: pill.box, crop: pill.crop, match: PillMatch(medicationID: id, distance: nil))
                    }
                }
            } catch {
                // Offline, or the service failed: fall back to the device's own check,
                // which leans to "Unknown" rather than guessing.
                print("OpenAI pill check failed, checking on the device: \(error)")
            }
        }
        return identifyOnDevice(pills)
    }

    /// The medications as the cloud model sees them: a line each and their photos.
    private func cloudReferences() -> [OpenAIPillIdentifier.Candidate] {
        if let cloudCandidates { return cloudCandidates }
        let candidates = medications.map { medication in
            let description = [medication.displayName, medication.appearance].filter { !$0.isEmpty }.joined(separator: " · ")
            let photos = medication.photos.compactMap { UIImage(named: $0)?.cgImage }.compactMap { OpenAIPillIdentifier.jpeg($0, maxSide: 256) }
            return OpenAIPillIdentifier.Candidate(id: medication.id, description: description, photos: photos)
        }
        cloudCandidates = candidates
        return candidates
    }

    private func identifyOnDevice(_ pills: [FoundPill]) -> [AnalyzedPill] {
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
