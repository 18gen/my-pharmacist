//
//  CameraLens.swift
//  MyPharmacist
//

import SwiftUI

/// One black shape that is the camera button's circle when closed and grows into the
/// rounded live camera view when open. Being a single view, it animates size and
/// corner radius smoothly instead of cross-fading between two shapes.
struct CameraLens: View {
    let model: ScannerModel
    let isOpen: Bool
    /// Size of the camera view when open.
    let openSize: CGSize
    /// Result of the latest scan, shown as a banner above the close button.
    var outcome: ScanOutcome? = nil
    var onUndo: () -> Void = {}

    /// Where the user last tapped to focus, shown briefly as a square.
    @State private var focusMark: CGPoint?
    @State private var focusTapCount = 0

    var body: some View {
        ZStack {
            Color.black

            if isOpen {
                CameraPreview(session: model.session) { devicePoint, viewPoint in
                    model.focus(at: devicePoint)
                    focusMark = viewPoint
                    focusTapCount += 1
                }
                .transition(.opacity)

                TextBoxOverlay(lines: model.lines, frameSize: model.frameSize)
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
                }

                if let outcome {
                    VStack {
                        Spacer()
                        ScanOutcomeBanner(outcome: outcome, onUndo: onUndo)
                    }
                    .padding(.horizontal, 12)
                    // Sit just above the close button.
                    .padding(.bottom, ScanLayout.bannerBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(outcome)
                }
            }
        }
        .animation(.spring(duration: 0.4), value: outcome)
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
}
