//
//  CameraPreview.swift
//  MyPharmacist
//

import AVFoundation
import SwiftUI
import UIKit

/// Shows the live camera feed from an `AVCaptureSession`. Tapping it reports the point in
/// camera device coordinates (for focusing) and in view coordinates (for the focus square).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var onTap: ((_ devicePoint: CGPoint, _ viewPoint: CGPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.onTap = onTap
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var onTap: ((CGPoint, CGPoint) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            let viewPoint = gesture.location(in: self)
            // Accounts for the preview's rotation and aspect-fill crop.
            let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint)
            onTap?(devicePoint, viewPoint)
        }
    }
}
