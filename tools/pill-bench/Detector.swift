//
//  Detector.swift
//  pill-bench
//
//  The trained pill detector (tools/pill-detector), run on a photo through Vision as the
//  app would run it, for comparing what it finds with what is really there.
//

import CoreGraphics
import CoreML
import Foundation
import Vision

final class PillDetectorModel {
    /// One pill the detector sees: normalized, origin at the top left.
    struct Detection {
        let box: CGRect
        let confidence: Float
    }

    private let model: VNCoreMLModel

    init?(url: URL) {
        do {
            let compiled = url.pathExtension == "mlmodelc" ? url : try MLModel.compileModel(at: url)
            model = try VNCoreMLModel(for: MLModel(contentsOf: compiled))
        } catch {
            print("Can't load the detector \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    func detect(in image: CGImage) -> [Detection] {
        let request = VNCoreMLRequest(model: model)
        // Stretched to the network's square, as Create ML trains it.
        request.imageCropAndScaleOption = .scaleFill
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            print("The detector failed: \(error.localizedDescription)")
            return []
        }
        let found = request.results as? [VNRecognizedObjectObservation] ?? []
        return found.map { observation in
            // Vision's boxes start at the bottom left.
            let box = observation.boundingBox
            return Detection(box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height),
                             confidence: observation.confidence)
        }
    }
}
