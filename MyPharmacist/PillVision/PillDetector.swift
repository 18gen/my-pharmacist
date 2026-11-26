//
//  PillDetector.swift
//  MyPharmacist
//

import CoreGraphics
import CoreML
import os
import Vision

/// The trained pill detector (tools/pill-detector, Create ML), run through Vision. It
/// gives a second opinion on the pills Vision's subject lifting and colour found
/// (`DetectorReview`). Without the model in the app, nothing changes.
nonisolated final class PillDetector: @unchecked Sendable {
    // Vision's model and requests may be used from any thread; a request is made per call.
    private let model: VNCoreMLModel

    init(model: MLModel) throws {
        self.model = try VNCoreMLModel(for: model)
    }

    /// The detector built into the app, compiled from PillDetector.mlmodel; nil when
    /// the app has none or it can't be loaded.
    static let bundled: PillDetector? = {
        guard let url = Bundle.main.url(forResource: "PillDetector", withExtension: "mlmodelc") else { return nil }
        do {
            return try PillDetector(model: MLModel(contentsOf: url))
        } catch {
            Log.scan.error("pill detector not loaded: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }()

    /// The pills it sees, in the picture's pixels, origin at the top left; nil if it
    /// couldn't run.
    func detect(in picture: CGImage) -> [PillDetection]? {
        let request = VNCoreMLRequest(model: model)
        // Stretched to the network's square, as Create ML trains it.
        request.imageCropAndScaleOption = .scaleFill
        do {
            try VNImageRequestHandler(cgImage: picture).perform([request])
        } catch {
            Log.scan.error("pill detector failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        let width = Double(picture.width), height = Double(picture.height)
        let observations = request.results as? [VNRecognizedObjectObservation] ?? []
        return observations.map { observation in
            // Vision's boxes are normalized from the bottom left.
            let box = observation.boundingBox
            return PillDetection(box: CGRect(x: box.minX * width, y: (1 - box.maxY) * height,
                                             width: box.width * width, height: box.height * height),
                                 confidence: observation.confidence)
        }
    }
}
