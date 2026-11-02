//
//  CameraSession.swift
//  MyPharmacist
//

import AVFoundation
import CoreImage

/// Owns the capture session, checks the picture quality of about ten frames a second,
/// and takes the photo the pills are checked in. Photos stay in memory only; nothing is
/// saved to the photo library or to disk.
/// Lives off the main actor: all camera work happens on its own queues.
///
/// `@unchecked Sendable` is safe because each mutable property is only touched on one
/// queue: `isConfigured`, `device` and `photoDelegates` on `sessionQueue`;
/// `lastQualityCheck` and `qualityAnalyzer` on `videoQueue`.
/// Everything else is immutable, and the stream's continuation is thread-safe.
nonisolated final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    /// Picture quality (light, glare, movement, sharpness) while the camera runs. Only the
    /// newest result waits to be read, so a slow reader skips frames instead of lagging.
    let quality: AsyncStream<FrameQuality>
    private let qualityContinuation: AsyncStream<FrameQuality>.Continuation
    private var qualityAnalyzer = FrameQualityAnalyzer()

    private let sessionQueue = DispatchQueue(label: "MyPharmacist.session")
    private let videoQueue = DispatchQueue(label: "MyPharmacist.video")
    private var isConfigured = false
    private var device: AVCaptureDevice?
    private var lastQualityCheck = Date.distantPast

    private let photoOutput = AVCapturePhotoOutput()
    /// The photo output doesn't keep its delegates, so each capture's is held until it ends.
    private var photoDelegates: [Int64: PhotoCaptureDelegate] = [:]
    private static let imageContext = CIContext()

    override init() {
        (quality, qualityContinuation) = AsyncStream.makeStream(of: FrameQuality.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    deinit {
        qualityContinuation.finish()
    }

    /// Configures (once) and starts the camera. Returns false if no camera is available.
    func start() async -> Bool {
        // Forget the last session's frames, so movement and sharpness start fresh.
        videoQueue.async { self.qualityAnalyzer = FrameQualityAnalyzer() }
        return await withCheckedContinuation { continuation in
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

    /// Takes a photo and returns it upright for a phone held in portrait, or nil if the
    /// camera isn't running or the capture failed.
    func capturePhoto() async -> CGImage? {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let settings = AVCapturePhotoSettings()
                let id = settings.uniqueID
                let delegate = PhotoCaptureDelegate { [weak self] image in
                    self?.sessionQueue.async { self?.photoDelegates[id] = nil }
                    continuation.resume(returning: image.flatMap(Self.upright))
                }
                self.photoDelegates[id] = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    /// Photos arrive in the sensor's landscape orientation; `.right` turns them upright.
    private static func upright(_ image: CGImage) -> CGImage? {
        let rotated = CIImage(cgImage: image).oriented(.right)
        return imageContext.createCGImage(rotated, from: rotated.extent)
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

    /// Width of a few pills spread out, which we want to fill most of the preview: about
    /// 7 cm, at ~80% of the width.
    private static let pillsWidthMillimeters: Float = 70
    private static let pillsFillFraction: Float = 0.8

    /// If the camera can't focus close enough to fill the view with the pills, zoom in so
    /// they fill it from a distance the camera can focus at (Apple's barcode-scanning
    /// approach). People then naturally hold the phone where the pills are sharp.
    private static func startingZoom(for device: AVCaptureDevice) -> CGFloat {
        let horizontalFOV = device.activeFormat.videoFieldOfView   // landscape sensor, at zoom 1.0
        let minimumFocus = Float(device.minimumFocusDistance)       // mm; -1 if unknown
        guard horizontalFOV > 0, minimumFocus > 0 else { return 1 }

        // In portrait the preview's width is the sensor's short side (16:9 frames).
        let halfWidthTangent = tan(horizontalFOV / 2 * .pi / 180) * 9 / 16
        // Distance at which the pills fill the target fraction of the width at zoom 1.0.
        let fillDistance = (pillsWidthMillimeters / pillsFillFraction / 2) / halfWidthTangent
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
        // Full-range brightness (0–255) for the quality checks; Vision reads either range.
        if output.availableVideoPixelFormatTypes.contains(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        }
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddInput(input), session.canAddOutput(output), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)
        session.addOutput(output)
        session.addOutput(photoOutput)
        session.commitConfiguration()

        // After the commit (which applies the preset's camera format, and can reset zoom)
        // and before the session starts, so the very first frame is already at final zoom.
        if (try? device.lockForConfiguration()) != nil {
            device.videoZoomFactor = Self.startingZoom(for: device)
            // Pills are photographed up close, so prefer near focus where supported.
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            device.unlockForConfiguration()
        }
        return true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Ten checks a second is plenty and saves battery; frames that arrive while one
        // is being checked are dropped (`alwaysDiscardsLateVideoFrames`).
        let now = Date()
        guard now.timeIntervalSince(lastQualityCheck) > 0.1 else { return }
        lastQualityCheck = now
        checkQuality(of: sampleBuffer, from: connection)
    }

    private func checkQuality(of sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let image = LumaSampler.sample(buffer) else { return }
        // The device comes from the frame's own connection rather than `device`, which
        // belongs to `sessionQueue`.
        var camera = CameraState()
        if let device = (connection.inputPorts.first?.input as? AVCaptureDeviceInput)?.device {
            camera.isAdjustingFocus = device.isAdjustingFocus
            camera.exposureOffset = device.exposureTargetOffset
            let maxISO = device.activeFormat.maxISO
            camera.isoFraction = maxISO > 0 ? device.iso / maxISO : 0
        }
        qualityContinuation.yield(qualityAnalyzer.analyze(image, camera: camera))
    }
}

/// Hands one finished photo back as an image. Called on a queue chosen by the camera.
nonisolated private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: @Sendable (CGImage?) -> Void

    init(completion: @escaping @Sendable (CGImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        completion(error == nil ? photo.cgImageRepresentation() : nil)
    }
}
