//
//  CameraSession.swift
//  MyPharmacist
//

import AVFoundation
import CoreMedia
import os

/// Owns the capture session, checks the picture quality of about ten frames a second,
/// and takes the photo the pills are checked in. Photos stay in memory only; nothing is
/// saved to the photo library or to disk.
/// Lives off the main actor: all camera work happens on its own queues.
///
/// `@unchecked Sendable` is safe because each mutable property is only touched on one
/// queue: `isConfigured`, `device`, `visibleAspect`, `visibleWidthMillimeters` and
/// `photoDelegates` on `sessionQueue`;
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
    /// Width over height of the part of the picture the camera view shows.
    private var visibleAspect = 9.0 / 16.0
    /// How wide that part is in real life, at the zoom the camera was started with.
    private var visibleWidthMillimeters = CapturedPhoto.assumedWidthMillimeters

    override init() {
        (quality, qualityContinuation) = AsyncStream.makeStream(of: FrameQuality.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    deinit {
        qualityContinuation.finish()
    }

    /// Configures (once) and starts the camera. Returns false if no camera is available.
    /// - Parameter visibleAspect: Width over height of the camera view. The picture fills
    ///   it, so this is the part of each photo the person sees and the part that is kept.
    func start(visibleAspect: Double) async -> Bool {
        // Forget the last session's frames, so movement and sharpness start fresh.
        videoQueue.async { self.qualityAnalyzer = FrameQualityAnalyzer() }
        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !self.isConfigured {
                    self.isConfigured = self.configure()
                }
                if self.isConfigured {
                    // Before the session starts, so the very first frame is at final zoom.
                    self.frame(for: visibleAspect)
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                }
                continuation.resume(returning: self.isConfigured)
            }
        }
    }

    func stop() {
        sessionQueue.async {
            // The light goes off with the camera; it doesn't stay on after a scan.
            self.applyTorch(false)
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// Takes a photo, kept to the part the camera view showed, for a phone held in
    /// portrait. Nil if the camera isn't running or the capture failed.
    func capturePhoto() async -> CapturedPhoto? {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self, self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let settings = AVCapturePhotoSettings()
                // A photo is the smallest size on offer unless it asks for more.
                if self.photoOutput.maxPhotoDimensions.width > 0 {
                    settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
                }
                let id = settings.uniqueID
                let visibleAspect = self.visibleAspect, width = self.visibleWidthMillimeters
                // Weak: `photoDelegates` holds the delegate until the photo arrives, and
                // the delegate must not hold the session in turn.
                let delegate = PhotoCaptureDelegate { [weak self] image in
                    if let session = self {
                        session.sessionQueue.async { session.photoDelegates[id] = nil }
                    }
                    // Photos arrive in the sensor's landscape orientation; `.right` is
                    // how they turn upright.
                    let photo = image.flatMap {
                        CapturedPhoto(source: $0, orientation: .right, visibleAspect: visibleAspect, widthMillimeters: width)
                    }
                    if let photo {
                        ScanLog.logger.info("photo kept \(Int(photo.size.width))x\(Int(photo.size.height)), \(photo.widthMillimeters, format: .fixed(precision: 1)) mm wide")
                    }
                    continuation.resume(returning: photo)
                }
                self.photoDelegates[id] = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    /// Whether the camera has a light that can be switched on (no for the Simulator and
    /// for front cameras). Known once the camera has started.
    func hasTorch() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                let device = self.device
                continuation.resume(returning: device.map { $0.hasTorch && $0.isTorchModeSupported(.on) } ?? false)
            }
        }
    }

    /// Switches the camera's light on or off. Ignored if there is no light.
    func setTorch(_ on: Bool) {
        sessionQueue.async { self.applyTorch(on) }
    }

    /// On `sessionQueue`. A torch mode the camera doesn't support raises an exception,
    /// so it is checked first, and the device is locked for the change as required.
    private func applyTorch(_ on: Bool) {
        let mode: AVCaptureDevice.TorchMode = on ? .on : .off
        guard let device, device.hasTorch, device.isTorchModeSupported(mode), device.torchMode != mode,
              (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = mode
        device.unlockForConfiguration()
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

    /// Zooms so the pills fill the part of the picture the camera view shows (see
    /// `CameraFraming`). Runs on `sessionQueue`, after the session's format is set.
    private func frame(for visibleAspect: Double) {
        guard let device else { return }
        let format = device.activeFormat
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let minimumFocus = Double(device.minimumFocusDistance)   // mm; -1 if unknown
        var framing = CameraFraming(
            longSideFieldOfView: Double(format.videoFieldOfView),   // landscape sensor, at zoom 1.0
            minimumFocusDistance: minimumFocus > 0 ? minimumFocus : nil,
            visibleAspect: visibleAspect,
            nativeZoomFactors: format.secondaryNativeResolutionZoomFactors.map { Double($0) },
            maximumDeviceZoom: Double(device.maxAvailableVideoZoomFactor)
        )
        if dimensions.width > 0, dimensions.height > 0 {
            framing.frameAspect = Double(min(dimensions.width, dimensions.height)) / Double(max(dimensions.width, dimensions.height))
        }
        self.visibleAspect = visibleAspect
        visibleWidthMillimeters = framing.visibleWidthMillimeters
        if (try? device.lockForConfiguration()) != nil {
            device.videoZoomFactor = CGFloat(framing.zoom)
            device.unlockForConfiguration()
        }
        ScanLog.logger.info("camera zoom \(framing.zoom, format: .fixed(precision: 2)), full-resolution factors \(framing.nativeZoomFactors), field of view \(framing.longSideFieldOfView, format: .fixed(precision: 1)), closest focus \(minimumFocus, format: .fixed(precision: 0)) mm, view \(framing.visibleWidthMillimeters, format: .fixed(precision: 1)) mm wide")
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
        // Photo quality: the only preset whose photos are larger than a video frame.
        session.sessionPreset = .photo
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

        // After the commit, which applies the preset's camera format (and can reset zoom,
        // which `frame(for:)` sets next): the photo sizes on offer are that format's. And
        // before the session starts, as changing the size later rebuilds the pipeline.
        let sizes = device.activeFormat.supportedMaxPhotoDimensions.map { PhotoSize(width: Int($0.width), height: Int($0.height)) }
        if let best = PhotoSize.best(of: sizes) {
            photoOutput.maxPhotoDimensions = CMVideoDimensions(width: Int32(best.width), height: Int32(best.height))
        }
        ScanLog.logger.info("photo sizes on offer \(sizes.map { "\($0.width)x\($0.height)" }), asking for up to \(self.photoOutput.maxPhotoDimensions.width)x\(self.photoOutput.maxPhotoDimensions.height)")
        if (try? device.lockForConfiguration()) != nil {
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
        let size = photo.resolvedSettings.photoDimensions
        ScanLog.logger.info("photo delivered \(size.width)x\(size.height)")
        completion(error == nil ? photo.cgImageRepresentation() : nil)
    }
}
