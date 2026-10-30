//
//  ScannerModel.swift
//  MedLens
//

import AVFoundation
import Observation

/// Runs the camera, reads text with Vision, and publishes what it found.
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

    var session: AVCaptureSession { camera.session }

    func start() async {
        guard await Self.hasCameraPermission() else {
            cameraMessage = "Camera access is off.\nTurn it on in Settings › MedLens."
            return
        }
        camera.onText = { [weak self] lines, frameSize in
            Task { @MainActor [weak self] in self?.read(lines, frameSize: frameSize) }
        }
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

    /// Only shows a value after it has been read the same way several times in a row,
    /// so a single misread frame never reaches the screen.
    private func read(_ lines: [RecognizedLine], frameSize: CGSize) {
        let texts = lines.map(\.text)

        // Mark which lines the name and frequency come from in this frame.
        var lines = lines
        if let index = PrescriptionParser.medicationLineIndex(in: texts) {
            lines[index].role = .name
        }
        for index in PrescriptionParser.frequencyLineIndices(in: texts) where lines[index].role == .other {
            lines[index].role = .frequency
        }
        self.lines = lines
        self.frameSize = frameSize

        if let name = nameReading.confirm(PrescriptionParser.medicationName(in: texts)) {
            medicationName = name
        }
        if let frequency = frequencyReading.confirm(PrescriptionParser.frequency(in: texts)) {
            self.frequency = frequency
        }
    }

    private static func hasCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}
