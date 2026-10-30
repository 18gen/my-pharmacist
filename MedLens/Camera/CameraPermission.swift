//
//  CameraPermission.swift
//  MedLens
//

import AVFoundation

enum CameraPermission {
    /// Whether the app may use the camera, asking the person the first time.
    static func request() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}
