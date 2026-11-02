//
//  ScannerModel.swift
//  MyPharmacist
//

import AVFoundation
import Observation

/// Runs the camera, publishes whether the picture is good enough to photograph the pills
/// in (or what to fix first), and takes that photo.
@Observable
final class ScannerModel {
    private(set) var cameraMessage: String?
    /// Whether the picture is good enough yet, or what to fix first.
    private(set) var captureStatus: QualityGate.Status = .checking
    /// The latest frame's quality measurements, for tuning the thresholds.
    private(set) var latestQuality: FrameQuality?

    @ObservationIgnored private let camera = CameraSession()
    @ObservationIgnored private var qualityGate = QualityGate()
    @ObservationIgnored private var qualityTask: Task<Void, Never>?

    var session: AVCaptureSession { camera.session }

    func start() async {
        guard await CameraPermission.request() else {
            cameraMessage = "Camera access is off.\nTurn it on in Settings › My Pharmacist."
            return
        }
        startReadingQuality()
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

    /// Takes the photo the pills are checked in, upright; nil if the camera can't.
    func capturePhoto() async -> CGImage? {
        await camera.capturePhoto()
    }

    /// Forgets the previous picture so each scan starts from "checking".
    func reset() {
        cameraMessage = nil
        captureStatus = .checking
        latestQuality = nil
        qualityGate = QualityGate()
    }

    /// Reads quality results for as long as the model exists. The camera's stream is
    /// single-use, so this starts once and simply waits while the camera is stopped.
    private func startReadingQuality() {
        guard qualityTask == nil else { return }
        let quality = camera.quality
        // `self` is weak so the loop never keeps the model alive; the stream ends when the
        // camera (owned by the model) goes away.
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
}
