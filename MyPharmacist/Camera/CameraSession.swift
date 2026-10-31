//
//  CameraSession.swift
//  MyPharmacist
//

import AVFoundation

/// Owns the capture session and hands a few video frames a second to the text recognizer.
/// Lives off the main actor: all camera work happens on its own queues.
///
/// `@unchecked Sendable` is safe because each mutable property is only touched on one
/// queue: `isConfigured` and `device` on `sessionQueue`, `lastScan` on `videoQueue`.
/// Everything else is immutable, and the stream's continuation is thread-safe.
nonisolated final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    /// Text read from the camera while it runs. Only the newest frame waits to be read,
    /// so a slow reader skips frames instead of falling behind the camera.
    let frames: AsyncStream<RecognizedFrame>
    private let framesContinuation: AsyncStream<RecognizedFrame>.Continuation
    private let recognizer = VisionTextRecognizer()

    private let sessionQueue = DispatchQueue(label: "MyPharmacist.session")
    private let videoQueue = DispatchQueue(label: "MyPharmacist.video")
    private var isConfigured = false
    private var device: AVCaptureDevice?
    private var lastScan = Date.distantPast

    override init() {
        (frames, framesContinuation) = AsyncStream.makeStream(of: RecognizedFrame.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    deinit {
        framesContinuation.finish()
    }

    /// Configures (once) and starts the camera. Returns false if no camera is available.
    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !self.isConfigured {
                    self.isConfigured = self.configure()
                }
                if self.isConfigured && !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume(returning: self.isConfigured)
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// Focuses (and exposes) on a point in device coordinates, e.g. from a tap.
    func focus(at devicePoint: CGPoint) {
        sessionQueue.async {
            guard let device = self.device, (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }
            // Set the point first, then the mode: setting the mode starts focusing there.
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .continuousAutoExposure
            }
        }
    }

    /// Label text width we want to fill most of the preview: about 5 cm, at ~80% of the width.
    private static let labelWidthMillimeters: Float = 50
    private static let labelFillFraction: Float = 0.8

    /// If the camera can't focus close enough to fill the view with a label, zoom in so the
    /// label fills it from a distance the camera can focus at (Apple's barcode-scanning
    /// approach). People then naturally hold the phone where the text is sharp.
    private static func startingZoom(for device: AVCaptureDevice) -> CGFloat {
        let horizontalFOV = device.activeFormat.videoFieldOfView   // landscape sensor, at zoom 1.0
        let minimumFocus = Float(device.minimumFocusDistance)       // mm; -1 if unknown
        guard horizontalFOV > 0, minimumFocus > 0 else { return 1 }

        // In portrait the preview's width is the sensor's short side (16:9 frames).
        let halfWidthTangent = tan(horizontalFOV / 2 * .pi / 180) * 9 / 16
        // Distance at which the label fills the target fraction of the width at zoom 1.0.
        let fillDistance = (labelWidthMillimeters / labelFillFraction / 2) / halfWidthTangent
        let focusZoom = CGFloat(minimumFocus / fillDistance)

        return min(max(1, focusZoom), min(device.maxAvailableVideoZoomFactor, 3))
    }

    private func configure() -> Bool {
        // The single main camera only. Multi-lens cameras switch lenses while focusing,
        // and the lenses' different positions make the picture visibly jump.
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return false
        }
        self.device = device

        session.beginConfiguration()
        session.sessionPreset = .high
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()

        // After the commit (which applies the preset's camera format, and can reset zoom)
        // and before the session starts, so the very first frame is already at final zoom.
        if (try? device.lockForConfiguration()) != nil {
            device.videoZoomFactor = Self.startingZoom(for: device)
            // Labels are read up close, so prefer near focus where supported.
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            device.unlockForConfiguration()
        }
        return true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // A few reads per second is plenty and saves battery.
        let now = Date()
        guard now.timeIntervalSince(lastScan) > 0.3 else { return }
        lastScan = now

        // Recognition runs right here on the video queue; frames that arrive meanwhile
        // are dropped (`alwaysDiscardsLateVideoFrames`).
        framesContinuation.yield(recognizer.recognize(sampleBuffer))
    }
}
