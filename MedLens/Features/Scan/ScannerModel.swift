//
//  ScannerModel.swift
//  MedLens
//

import AVFoundation
import Observation

/// Runs the camera, reads each frame's text, and publishes the medication name and
/// frequency once they have been read the same way several frames in a row.
@Observable
final class ScannerModel {
    private(set) var medicationName: String?
    private(set) var frequency: String?
    private(set) var cameraMessage: String?
    /// Text read in the latest camera frame, with positions, for the on-screen boxes.
    private(set) var lines: [RecognizedLine] = []
    /// Upright size of the camera frames the boxes are measured against.
    private(set) var frameSize: CGSize = .zero

    @ObservationIgnored private let camera = CameraSession()
    @ObservationIgnored private var nameReading = StableReading()
    @ObservationIgnored private var frequencyReading = StableReading()
    @ObservationIgnored private var readingTask: Task<Void, Never>?

    var session: AVCaptureSession { camera.session }

    func start() async {
        guard await CameraPermission.request() else {
            cameraMessage = "Camera access is off.\nTurn it on in Settings › MedLens."
            return
        }
        startReading()
        if await !camera.start() {
            cameraMessage = "No camera is available on this device."
        }
    }

    func stop() {
        camera.stop()
    }

    /// Focuses on a point the user tapped, in camera device coordinates (0–1).
    func focus(at devicePoint: CGPoint) {
        camera.focus(at: devicePoint)
    }

    /// Clears the previous label so each scan starts from "Scanning...".
    func reset() {
        medicationName = nil
        frequency = nil
        cameraMessage = nil
        lines = []
        nameReading = StableReading()
        frequencyReading = StableReading()
    }

    /// Reads frames for as long as the model exists. The camera's stream is single-use, so
    /// this starts once and simply waits while the camera is stopped.
    private func startReading() {
        guard readingTask == nil else { return }
        let frames = camera.frames
        // `self` is weak so the loop never keeps the model alive; the stream ends when the
        // camera (owned by the model) goes away.
        readingTask = Task { [weak self] in
            for await frame in frames {
                guard let self else { return }
                self.read(frame)
            }
        }
    }

    /// Only shows a value after it has been read the same way several times in a row,
    /// so a single misread frame never reaches the screen.
    private func read(_ frame: RecognizedFrame) {
        let reading = LabelAnalyzer.analyze(frame.lines)
        lines = reading.lines
        frameSize = frame.size

        if let name = nameReading.confirm(reading.medicationName) {
            medicationName = name
        }
        if let frequency = frequencyReading.confirm(reading.frequency) {
            self.frequency = frequency
        }
    }
}
