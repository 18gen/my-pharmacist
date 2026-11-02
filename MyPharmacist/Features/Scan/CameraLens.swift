//
//  CameraLens.swift
//  MyPharmacist
//

import SwiftUI

/// One black shape that is the camera button's circle when closed and grows into the
/// rounded scan view when open. Being a single view, it animates size and corner radius
/// smoothly instead of cross-fading between two shapes. Inside: the live camera while
/// aiming, then the photo being checked, then the results.
struct CameraLens: View {
    let scan: ScanFlow
    let isOpen: Bool
    /// Size of the camera view when open.
    let openSize: CGSize
    var onConfirm: () -> Void = {}

    /// Where the user last tapped to focus, shown briefly as a square.
    @State private var focusMark: CGPoint?
    @State private var focusTapCount = 0

    private var model: ScannerModel { scan.scanner }

    var body: some View {
        ZStack {
            Color.black

            if isOpen {
                content
            }
        }
        .animation(.spring(duration: 0.4), value: scan.phase.step)
        .frame(width: isOpen ? openSize.width : ScanLayout.buttonSize,
               height: isOpen ? openSize.height : ScanLayout.buttonSize)
        // Closed: half the size, i.e. a circle.
        .clipShape(RoundedRectangle(cornerRadius: isOpen ? ScanLayout.lensCornerRadius : ScanLayout.buttonSize / 2,
                                    style: .continuous))
        // Open: same gap from the bottom as from the sides.
        .padding(.bottom, isOpen ? ScanLayout.lensEdgeGap : ScanLayout.buttonBottomInset)
        .ignoresSafeArea(edges: .bottom)
        .accessibilityHidden(!isOpen)
        // Hide the focus square a moment after each tap.
        .task(id: focusTapCount) {
            guard focusMark != nil else { return }
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.easeOut(duration: 0.3)) { focusMark = nil }
        }
        .animation(.easeOut(duration: 0.2), value: focusTapCount)
    }

    @ViewBuilder
    private var content: some View {
        switch scan.phase {
        case .aiming, .checking(nil):
            liveCamera
        case .checking(let photo?):
            frozen(photo) {
                ProgressView("Checking pills…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .font(.headline)
            }
        case .results(let result):
            PillResultsView(result: result, onConfirm: onConfirm, onScanAgain: scanAgain)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, ScanLayout.contentBottomPadding)
                .transition(.opacity)
        case .noPills(let photo):
            frozen(photo) {
                ScanActionButtons(takeCount: 0, onConfirm: {}, onScanAgain: scanAgain)
                    .frame(maxWidth: 220)
            }
        }
    }

    private var liveCamera: some View {
        ZStack {
            CameraPreview(session: model.session) { devicePoint, viewPoint in
                model.focus(at: devicePoint)
                focusMark = viewPoint
                focusTapCount += 1
            }
            .transition(.opacity)

            if let focusMark {
                FocusMark()
                    .position(focusMark)
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
            }

            if let message = model.cameraMessage {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .transition(.opacity)
            } else {
                VStack(spacing: 6) {
                    CaptureHint(status: model.captureStatus)
                    #if DEBUG
                    QualityReadout(model: model)
                    #endif
                    Spacer()
                    ShutterButton(isBusy: scan.phase.step == .checking, action: scan.capture)
                }
                .padding(.top, 16)
                .padding(.horizontal, 12)
                .padding(.bottom, ScanLayout.contentBottomPadding)
                .animation(.easeInOut(duration: 0.2), value: model.captureStatus)
            }
        }
    }

    /// The photo that was taken, dimmed, with something on top of it.
    private func frozen(_ photo: CGImage, @ViewBuilder overlay: () -> some View) -> some View {
        ZStack {
            Image(decorative: photo, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: openSize.width, height: openSize.height)
                .clipped()
                .overlay(Color.black.opacity(0.45))
            overlay()
        }
        .transition(.opacity)
    }

    private func scanAgain() {
        Task { await scan.scanAgain() }
    }
}

/// Takes the photo now instead of waiting for the picture to be judged good: the photo
/// is also taken by itself once it is.
private struct ShutterButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Take photo", systemImage: "camera.shutter.button")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(.white))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.5 : 1)
        .accessibilityHint("The photo is also taken by itself once the picture looks good")
    }
}
