//
//  ScannerModel.swift
//  MyPharmacist
//

import AVFoundation
import Observation

/// Runs the camera, reads each frame's text, and publishes the medication name and
/// frequency once they have been read the same way several frames in a row. Also
/// publishes whether the picture is good enough to recognize pills in.
@Observable
final class ScannerModel {
    private(set) var medicationName: String?
    private(set) var frequency: String?
    private(set) var cameraMessage: String?
    /// Text read in the latest camera frame, with positions, for the on-screen boxes.
    private(set) var lines: [RecognizedLine] = []
    /// Upright size of the camera frames the boxes are measured against.
    private(set) var frameSize: CGSize = .zero
    /// Whether the picture is good enough yet, or what to fix first.
    private(set) var captureStatus: QualityGate.Status = .checking
    /// The latest frame's quality measurements, for tuning the thresholds.
    private(set) var latestQuality: FrameQuality?

    @ObservationIgnored private let camera = CameraSession()
    @ObservationIgnored private var nameReading = StableReading()
    @ObservationIgnored private var frequencyReading = StableReading()
    @ObservationIgnored private var qualityGate = QualityGate()
    @ObservationIgnored private var readingTask: Task<Void, Never>?
    @ObservationIgnored private var qualityTask: Task<Void, Never>?

    var session: AVCaptureSession { camera.session }

    func start() async {
        guard await CameraPermission.request() else {
            cameraMessage = "Camera access is off.\nTurn it on in Settings › My Pharmacist."
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
        captureStatus = .checking
        latestQuality = nil
        qualityGate = QualityGate()
    }

    /// Reads frames for as long as the model exists. The camera's stream is single-use, so
    /// this starts once and simply waits while the camera is stopped.
    private func startReading() {
        guard readingTask == nil else { return }
        let frames = camera.frames
        let quality = camera.quality
        // `self` is weak so the loops never keep the model alive; the streams end when the
        // camera (owned by the model) goes away.
        readingTask = Task { [weak self] in
            for await frame in frames {
                guard let self else { return }
                self.read(frame)
            }
        }
        qualityTask = Task { [weak self] in
            for await frameQuality in quality {
                guard let self else { return }
                self.judge(frameQuality)
            }
        }
    }

    private func judge(_ quality: FrameQuality) {
        latestQuality = quality
        let status = qualityGate.update(quality)
        // Only assign changes, so views showing the status don't redraw ten times a second.
        if status != captureStatus {
            captureStatus = status
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
