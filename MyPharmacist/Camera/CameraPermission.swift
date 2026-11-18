//
//  CameraPermission.swift
//  MyPharmacist
//

import AVFoundation

enum CameraPermission {
    enum Access: Equatable {
        case allowed
        /// The person turned it off for this app; Settings can turn it back on.
        case denied
        /// Not allowed on this iPhone at all (Screen Time, a managed phone): Settings for
        /// this app can't change it.
        case restricted
    }

    /// Whether the app may use the camera, asking the person the first time.
    static func request() async -> Access {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .allowed
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .denied
        case .restricted: return .restricted
        default: return .denied
        }
    }
}
