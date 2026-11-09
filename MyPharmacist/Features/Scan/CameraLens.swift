//
//  CameraLens.swift
//  MyPharmacist
//

import SwiftUI

/// One black shape that is the camera button's circle when closed and grows into the
/// rounded scan view when open. Being a single view, it animates size and corner radius
/// smoothly instead of cross-fading between two shapes. Inside: the live camera while
/// aiming and the photo for the moment its pills are looked for. Once pills are found
/// the camera is done: the black turns into the white of the page, and the results
/// appear on it. The words to go with each step are in `ScanHeader`, above this view.
struct CameraLens: View {
    let scan: ScanFlow
    let isOpen: Bool
    /// Size of the camera view when open.
    let openSize: CGSize
    /// Closes the scan from the results page.
    var onDone: () -> Void = {}
    /// The button's colour while closed: blue when something is due now.
    var closedColor: Color = .black

    /// Where the user last tapped to focus, shown briefly as a square.
    @State private var focusMark: CGPoint?
    @State private var focusTapCount = 0

    private var model: ScannerModel { scan.scanner }

    var body: some View {
        ZStack {
            isOpen ? (scan.phase.step.isPage ? Palette.background : Color.black) : closedColor

            if isOpen {
                content
                    // Closing: gone before the shape has shrunk much, so the page's rows
                    // never squeeze into the small circle.
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .opacity.animation(.easeOut(duration: 0.1))))
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
        case .aiming, .finding(nil):
            liveCamera
        case .finding(let photo?):
            // The camera is off; the photo it took shows in its place.
            frozen(photo)
        case .noPills(let photo):
            frozen(photo)
                .overlay(alignment: .bottom) {
                    WideButton(title: "Retake", systemImage: "arrow.counterclockwise") {
                        Task { await scan.retake() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, ScanLayout.lensButtonBottomPadding)
                    .accessibilityHint("Opens the camera again")
                }
        case .checking:
            ProgressView()
                .controlSize(.large)
                .transition(.opacity)
        case .results(let result):
            PillResultsView(result: result, onDone: onDone, onScanAgain: scanAgain)
                .padding(.horizontal, 6)
                .padding(.bottom, ScanLayout.pageBottomPadding)
                .transition(.opacity)
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

            // No camera: the header says why; here, just a sign that there is no picture.
            if model.cameraMessage != nil {
                Image(systemName: "video.slash")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
    }

    /// The photo that was taken, a little dimmed, while its pills are looked for.
    private func frozen(_ photo: CGImage) -> some View {
        Image(decorative: photo, scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: openSize.width, height: openSize.height)
            .clipped()
            .overlay(Color.black.opacity(0.3))
            .transition(.opacity)
    }

    private func scanAgain() {
        Task { await scan.scanAgain() }
    }
}
