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
    /// Why there is no camera picture, if there isn't one.
    private(set) var cameraProblem: CameraProblem?
    /// What to tell the person about `cameraProblem`.
    var cameraMessage: String? { cameraProblem?.message }
    /// Whether the picture is good enough yet, or what to fix first.
    private(set) var captureStatus: QualityGate.Status = .checking
    /// Whether the camera has a light, and whether the person turned it on. The choice
    /// lasts through retakes in one scan, and the next scan starts with it off.
    private(set) var hasLight = false
    private(set) var isLightOn = false

    @ObservationIgnored private let camera = CameraSession()
    @ObservationIgnored private var qualityGate = QualityGate()
    @ObservationIgnored private var qualityTask: Task<Void, Never>?

    var session: AVCaptureSession { camera.session }

    /// - Parameter visibleAspect: Width over height of the camera view.
    func start(visibleAspect: Double) async {
        guard await CameraPermission.request() else {
            cameraProblem = .accessDenied
            return
        }
        startReadingQuality()
        if await !camera.start(visibleAspect: visibleAspect) {
            cameraProblem = .unavailable
            return
        }
        hasLight = await camera.hasTorch()
        if isLightOn {
            camera.setTorch(true)
        }
    }

    #if DEBUG
    /// For previews: what the camera picture would be like, without a camera.
    func showForPreview(status: QualityGate.Status, hasLight: Bool, isLightOn: Bool = false) {
        captureStatus = status
        self.hasLight = hasLight
        self.isLightOn = isLightOn
    }
    #endif

    func toggleLight() {
        guard hasLight else { return }
        isLightOn.toggle()
        camera.setTorch(isLightOn)
    }

    /// The app went to the background: the system turns the light off, so say so.
    func appWentToBackground() {
        isLightOn = false
    }

    /// For a new scan: the light starts off.
    func turnLightOff() {
        isLightOn = false
        camera.setTorch(false)
    }

    func stop() {
        camera.stop()
    }

    /// Focuses on a point the user tapped, in camera device coordinates (0–1).
    func focus(at devicePoint: CGPoint) {
        camera.focus(at: devicePoint)
    }

    /// Takes the photo the pills are checked in; nil if the camera can't.
    func capturePhoto() async -> CapturedPhoto? {
        await camera.capturePhoto()
    }

    /// Forgets the previous picture so each scan starts from "checking".
    func reset() {
        cameraProblem = nil
        captureStatus = .checking
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
        let status = qualityGate.update(quality)
        // Only assign changes, so views showing the status don't redraw ten times a second.
        if status != captureStatus {
            captureStatus = status
        }
    }
}

/// Why the camera picture can't be shown.
enum CameraProblem: Equatable {
    /// The person turned camera access off for the app; it can be turned on in Settings.
    case accessDenied
    /// The device has no back camera, or it couldn't be started.
    case unavailable

    var message: String {
        switch self {
        case .accessDenied: "Allow camera in Settings"
        case .unavailable: "No camera found"
        }
    }
}
