//
//  Train.swift
//  pill-detector
//
//  Trains the pill detector with Create ML on this Mac, from the pictures and
//  annotations.json that `pill-bench train-data` writes. One label, "pill". Training can
//  be stopped and picked up again: its session (checkpoints) is kept beside the model.
//
//    pill-detector <pictures folder> <model.mlmodel> [iterations] [yolo|transfer]
//

import Combine
import CreateML
import Foundation

@main
struct Train {
    static func main() throws {
        // Each line as it comes, also when written to a file.
        setvbuf(stdout, nil, _IONBF, 0)
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            print("pill-detector <pictures folder> <model.mlmodel> [iterations] [yolo|transfer]")
            exit(2)
        }
        let pictures = URL(filePath: arguments[1], directoryHint: .isDirectory)
        let model = URL(filePath: arguments[2])
        let iterations = arguments.count > 3 ? Int(arguments[3]) ?? 3000 : 3000
        let transfer = arguments.count > 4 && arguments[4] == "transfer"
        let session = model.deletingPathExtension().appendingPathExtension("session")

        let parameters = MLObjectDetector.ModelParameters(
            validation: .split(strategy: .automatic), batchSize: nil, maxIterations: iterations,
            gridSize: CGSize(width: 13, height: 13),
            algorithm: transfer ? .transferLearning(.objectPrint(revision: 1)) : .darknetYolo)
        let job = try MLObjectDetector.train(
            trainingData: .directoryWithImagesAndJsonAnnotation(at: pictures),
            annotationType: .boundingBox(units: .pixel, origin: .topLeft, anchor: .center),
            parameters: parameters,
            sessionParameters: MLTrainingSessionParameters(sessionDirectory: session, reportInterval: 50,
                                                           checkpointInterval: 250, iterations: iterations))
        print("Training \(transfer ? "on Vision's object features" : "a YOLO network") for \(iterations) iterations")

        var watching = Set<AnyCancellable>()
        var lastShown = -1
        // Create ML reports from its own threads; these run on the main one.
        job.progress.publisher(for: \.fractionCompleted)
            .receive(on: RunLoop.main)
            .sink { fraction in
                let percent = Int(fraction * 100)
                if percent > lastShown {
                    lastShown = percent
                    print("\(percent)% \(Date.now.formatted(date: .omitted, time: .standard))")
                }
            }
            .store(in: &watching)
        job.result
            .receive(on: RunLoop.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Training failed: \(error)")
                    exit(1)
                }
            } receiveValue: { detector in
                print("Training mAP (IoU 50%): \(detector.trainingMetrics.meanAveragePrecision.IoU50)")
                print("Validation mAP (IoU 50%): \(detector.validationMetrics.meanAveragePrecision.IoU50)")
                do {
                    try detector.write(to: model, metadata: MLModelMetadata(
                        author: "My Pharmacist", shortDescription: "Finds pills in a photo of a hand or a table.", version: "1"))
                    print("Written to \(model.path)")
                    exit(0)
                } catch {
                    print("Can't write the model: \(error)")
                    exit(1)
                }
            }
            .store(in: &watching)
        RunLoop.main.run()
    }
}
