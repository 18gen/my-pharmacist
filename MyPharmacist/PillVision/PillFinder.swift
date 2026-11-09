//
//  PillFinder.swift
//  MyPharmacist
//

import CoreImage
import Vision

/// One pill found in a photo: where it is and a cut-out of just the pill.
nonisolated struct FoundPill: Sendable {
    /// Normalized 0–1, origin at the top left of the photo.
    let box: CGRect
    /// The pill alone, cropped to it, with everything around it transparent.
    let crop: CGImage
}

/// What looking for pills in a photo came to.
nonisolated enum PillSearch: Sendable {
    /// At least one pill, in reading order (top row first, left to right).
    case found([FoundPill])
    /// The photo was searched and has no pills in it.
    case noPills
    /// The search itself didn't work (Vision can't run in the Simulator, for one), so
    /// whether there are pills isn't known. Never to be shown as "no pills".
    case failed
}

/// Finds the separate objects in a photo with Vision's subject lifting (the same as
/// touching and holding a photo's subject) and keeps the ones that are pill-sized.
nonisolated enum PillFinder {
    /// Bigger objects are a hand, a plate or a table, not a pill. Starting points to tune.
    static let maximumArea = 0.12
    static let minimumArea = 0.0004

    private static let context = CIContext()

    static func find(in photo: CGImage) -> PillSearch {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: photo)
        do {
            try handler.perform([request])
        } catch {
            return .failed
        }
        // No result at all: Vision saw nothing that stands out from the background.
        guard let observation = request.results?.first else { return .noPills }

        let boxes = instanceBoxes(observation.instanceMask)
        var pills: [FoundPill] = []
        for instance in observation.allInstances {
            guard let found = boxes[instance], (minimumArea...maximumArea).contains(found.area) else { continue }
            // A pill that can't be cut out fails the whole search: leaving it out would
            // show the rest as if they were all the pills there are.
            guard let masked = try? observation.generateMaskedImage(ofInstances: [instance], from: handler, croppedToInstancesExtent: true) else {
                return .failed
            }
            let image = CIImage(cvPixelBuffer: masked)
            guard let crop = context.createCGImage(image, from: image.extent) else { return .failed }
            pills.append(FoundPill(box: found.box, crop: crop))
        }
        guard !pills.isEmpty else { return .noPills }
        return .found(InstanceBoxes.readingOrder(pills.map(\.box)).map { pills[$0] })
    }

    /// Copies Vision's low-resolution instance mask (one byte per pixel: the instance
    /// number) and measures each instance.
    private static func instanceBoxes(_ mask: CVPixelBuffer) -> [Int: (box: CGRect, area: Double)] {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return [:] }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var labels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                labels[y * width + x] = bytes[y * bytesPerRow + x]
            }
        }
        return InstanceBoxes.boxes(labels: labels, width: width, height: height)
    }
}
