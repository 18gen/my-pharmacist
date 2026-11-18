//
//  SubjectMask.swift
//  MyPharmacist
//

import CoreGraphics
import CoreVideo
import Vision

/// Vision's subject lifting (the same as touching and holding a photo's subject) on one
/// picture: the things that stand out from the background, each numbered, with where
/// each is and how much of the picture it covers. What finds pills in a scan
/// (`PillFinder`) and what cuts out a medication's own tablet (`PillReferencePhoto`) both
/// start from it.
nonisolated struct SubjectMask {
    let observation: VNInstanceMaskObservation
    /// What the observation's masks are made from.
    let handler: VNImageRequestHandler
    /// Vision's low-resolution label map.
    let labels: (values: [UInt8], width: Int, height: Int)
    /// Each object's box (normalized, origin at the top left) and share of the picture,
    /// by its number in `labels`.
    let objects: [Int: (box: CGRect, area: Double)]

    /// Nil when nothing stands out from the background.
    /// - Throws: When Vision can't run at all, as in the Simulator.
    init?(of picture: CGImage) throws {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: picture)
        try handler.perform([request])
        guard let observation = request.results?.first else { return nil }
        self.observation = observation
        self.handler = handler
        labels = Self.labels(of: observation.instanceMask)
        objects = InstanceBoxes.boxes(labels: labels.values, width: labels.width, height: labels.height)
    }

    /// Copies Vision's low-resolution label map: one byte per pixel, the number of the
    /// object it belongs to, 0 for the background.
    private static func labels(of mask: CVPixelBuffer) -> (values: [UInt8], width: Int, height: Int) {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        guard let base = CVPixelBufferGetBaseAddress(mask), width > 0, height > 0 else { return ([], 0, 0) }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var labels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                labels[y * width + x] = bytes[y * bytesPerRow + x]
            }
        }
        return (labels, width, height)
    }
}
