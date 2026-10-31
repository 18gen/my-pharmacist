//
//  VisionTextRecognizer.swift
//  MyPharmacist
//

import CoreMedia
import Vision

/// Reads the text in a camera frame with Apple's on-device Vision OCR.
/// This is the one place that knows how text is recognized; a different model can
/// replace it as long as it returns a `RecognizedFrame`.
nonisolated struct VisionTextRecognizer: Sendable {
    /// Text Vision is less sure about than this is dropped instead of guessed at.
    var minimumConfidence: Float = 0.5

    func recognize(_ sampleBuffer: CMSampleBuffer) -> RecognizedFrame {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Language correction could "fix" a drug name into a different word, so it is off.
        request.usesLanguageCorrection = false

        // Back camera frames arrive rotated; `.right` makes them upright for a portrait phone.
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right)
        try? handler.perform([request])

        let lines = (request.results ?? [])
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }   // top of label first
            .compactMap { observation -> RecognizedLine? in
                guard let best = observation.topCandidates(1).first, best.confidence >= minimumConfidence else { return nil }
                return RecognizedLine(text: best.string, box: observation.boundingBox)
            }

        // Frames arrive landscape; rotated upright (`.right`) width and height swap.
        var size = CGSize.zero
        if let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            size = CGSize(width: CVPixelBufferGetHeight(buffer), height: CVPixelBufferGetWidth(buffer))
        }
        return RecognizedFrame(lines: lines, size: size)
    }
}
