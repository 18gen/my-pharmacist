//
//  CameraLens.swift
//  MyPharmacist
//

import SwiftUI

/// The camera button's circle when closed, and the scan when open. One shape grows from
/// the button straight into the camera picture's place: it stays black the whole way, so
/// the button becomes the picture and nothing else black moves. Being a single view, it
/// animates size, place and corner radius smoothly instead of cross-fading between two
/// shapes. In the picture: the live camera, then the photo while its pills are looked
/// for, with the moving picture of what to do at its top. Under it, outside the shape:
/// the light, or Retake and Cancel, beside the close button (`CameraButton`, drawn by the
/// screen where the closed button was). For the confirm step, checking and the results,
/// the shape becomes the white page instead. The words to go with each step are in
/// `ScanHeader`, above this view.
///
/// With Reduce Motion on, nothing grows: the closed button and the open scan cross-fade.
struct CameraLens: View {
    let scan: ScanFlow
    let isOpen: Bool
    /// Size of the camera view when open: the picture and the bar under it, or the page.
    let openSize: CGSize
    /// Closes the scan from the results page.
    var onDone: () -> Void = {}
    /// The button's colour while closed: blue when something is due now.
    var closedColor: Color = .black

    /// Where the user last tapped to focus, shown briefly as a square.
    @State private var focusMark: CGPoint?
    @State private var focusTapCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var model: ScannerModel { scan.scanner }

    var body: some View {
        Group {
            if reduceMotion {
                ZStack(alignment: .bottom) {
                    if isOpen {
                        lens(open: true).transition(.opacity)
                    } else {
                        lens(open: false).transition(.opacity)
                    }
                }
            } else {
                lens(open: isOpen)
            }
        }
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

    /// While the camera picture shows: aiming, the photo being searched, or a retake.
    private var showsPicture: Bool {
        switch scan.phase {
        case .aiming, .finding, .retake: true
        case .confirming, .checking, .results: false
        }
    }

    /// The whole view, closed or open. The frame and its bottom padding put the closed
    /// circle on the button and the open view over the screen's bottom part; the shape
    /// sits at the top of that frame, as tall as the button, the picture or the page.
    private func lens(open: Bool) -> some View {
        let picture = open && showsPicture
        let corner = !open ? ScanLayout.buttonSize / 2
            : (picture ? ScanLayout.pictureCornerRadius : ScanLayout.lensCornerRadius)
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        let shapeHeight = !open ? ScanLayout.buttonSize
            : (picture ? max(0, openSize.height - ScanLayout.controlBarHeight) : openSize.height)
        return ZStack(alignment: .top) {
            shape
                .fill(!open ? closedColor : (picture ? Color.black : Palette.background))
                .overlay {
                    if open {
                        surfaceContent
                            // Closing: gone before the shape has shrunk much, so nothing
                            // squeezes into the small circle.
                            .transition(.asymmetric(insertion: .opacity,
                                                    removal: .opacity.animation(.easeOut(duration: 0.1))))
                    }
                }
                .clipShape(shape)
                .frame(height: shapeHeight)

            if picture {
                // The bar's height is fixed, like the Camera app's, so its words stop
                // growing at the largest standard text size instead of squeezing each
                // other out. It arrives once the picture has mostly grown.
                bar
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.asymmetric(insertion: .opacity.animation(.easeIn(duration: 0.2).delay(0.15)),
                                            removal: .opacity.animation(.easeOut(duration: 0.1))))
            }
        }
        // Top-aligned, so the picture starts at the top of the camera view whatever the bar
        // under it holds. Centred, a bar with nothing in it (while "Checking…") let the
        // stack shrink to the picture and drop it by half the bar's height.
        .frame(width: open ? openSize.width : ScanLayout.buttonSize,
               height: open ? openSize.height : ScanLayout.buttonSize,
               alignment: .top)
        // Open: same gap from the bottom as from the sides.
        .padding(.bottom, open ? ScanLayout.lensEdgeGap : ScanLayout.buttonBottomInset)
        .animation(.spring(duration: 0.4), value: scan.phase.step)
    }

    /// What is inside the shape: the camera picture, or the page.
    @ViewBuilder
    private var surfaceContent: some View {
        switch scan.phase {
        case .aiming, .finding(nil):
            withInstruction(liveCamera)
        case .finding(let photo?):
            // The camera is off; the photo it took shows in its place.
            withInstruction(frozen(photo))
        case .retake(let photo, _):
            withInstruction(frozen(photo))
        case .confirming(let found):
            PillConfirmView(found: found, size: openSize,
                            onYes: { Task { await scan.confirmPills() } },
                            onNo: scanAgain)
                .transition(.opacity)
        case .checking, .results:
            // One branch for both, so the page keeps its identity when the answer comes
            // and only its contents change.
            if let content = resultsContent {
                PillResultsView(content: content, onDone: onDone, onScanAgain: scanAgain)
                    .padding(.horizontal, 6)
                    .padding(.bottom, ScanLayout.pageBottomPadding)
                    .transition(.opacity)
            }
        }
    }

    /// The results page's contents: the pills being checked, or what they are.
    private var resultsContent: PillResultsView.Content? {
        switch scan.phase {
        case .checking(let found): .checking(found)
        case .results(let result): .ready(result)
        default: nil
        }
    }

    /// Under the picture, beside the close button: the light while aiming, Retake and
    /// Cancel for a photo to take again. An empty bar is `Color.clear`, not `EmptyView`:
    /// it still takes its room, so the layout never depends on what the bar holds.
    @ViewBuilder
    private var bar: some View {
        switch scan.phase {
        case .aiming where model.cameraProblem == .accessDenied: openSettingsButton
        case .aiming: lightButton
        case .retake: retakeButtons
        default: Color.clear
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

    /// The camera picture filling the shape, with what to do drawn at its top.
    private func withInstruction(_ picture: some View) -> some View {
        let instruction = scan.instruction
        return Color.clear
            .overlay { picture }
            .overlay(alignment: .top) {
                if let pictogram = instruction.pictogram, model.cameraMessage == nil {
                    ScanPictogramView(pictogram: pictogram, onCamera: true)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .id(pictogram)
                        .padding(.top, 28)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: instruction.pictogram)
    }

    /// On the bar's left, beside the close button: the phone's light, with its word, so
    /// it is found without knowing the symbol. Only while the camera is live, and only
    /// on phones with a light.
    @ViewBuilder
    private var lightButton: some View {
        if model.hasLight, case .aiming = scan.phase {
            HStack {
                Button { model.toggleLight() } label: {
                    VStack(spacing: 4) {
                        // On: the colours swap, so it shows by shape and word, not by
                        // colour alone.
                        Image(systemName: model.isLightOn ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(model.isLightOn ? Palette.background : Palette.textPrimary)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(model.isLightOn ? Palette.textPrimary : Palette.cardFill))
                        Text(model.isLightOn ? "Light on" : "Light")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize()
                    }
                    .frame(minWidth: 72, minHeight: 72)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Light")
                .accessibilityValue(model.isLightOn ? "On" : "Off")
                .accessibilityHint("Switches the phone's light on or off")
                .sensoryFeedback(.selection, trigger: model.isLightOn)
                Spacer()
            }
            .padding(.leading, 22)
            .closeButtonRow()
        } else {
            // No light: the bar's room stays taken (see `bar`).
            Color.clear
        }
    }

    /// Camera access is off: the one thing that helps is turning it on in Settings. The
    /// camera starts by itself on coming back (`ScanFlow.appBecameActive`).
    private var openSettingsButton: some View {
        HStack {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(minHeight: 34)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Palette.textMuted)
            .accessibilityHint("Opens this app's settings to allow the camera")
            Spacer()
        }
        .padding(.leading, 22)
        .closeButtonRow()
    }

    /// In place of the close button, for a photo that has to be taken again: Retake
    /// first, and a smaller Cancel that closes the camera, as on the results page. A
    /// photo that was fine but couldn't be checked is checked again instead.
    private var retakeButtons: some View {
        HStack(spacing: 10) {
            if case .retake(_, .checkFailed) = scan.phase {
                WideButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await scan.checkAgain() }
                }
                .accessibilityHint("Checks the same photo again")
            } else {
                WideButton(title: "Retake", systemImage: "arrow.counterclockwise", action: scanAgain)
                .accessibilityHint("Opens the camera again")
            }
            SecondaryButton(title: "Cancel", action: onDone)
                .accessibilityHint("Closes the camera")
        }
        .padding(.horizontal, 20)
        .closeButtonRow()
    }

    /// The photo that was taken, a little dimmed, while its pills are looked for.
    private func frozen(_ photo: CGImage) -> some View {
        Image(decorative: photo, scale: 1)
            .resizable()
            .scaledToFill()
            .overlay(Color.black.opacity(0.3))
            .transition(.opacity)
    }

    private func scanAgain() {
        Task { await scan.scanAgain() }
    }
}

private extension View {
    /// Puts the bar's buttons in one row at the close button's height, so they line up
    /// with it. The close button is drawn by the screen at the home screen's camera
    /// button's place, which is the bottom of the bar.
    func closeButtonRow() -> some View {
        frame(height: ScanLayout.buttonSize)
            .padding(.bottom, ScanLayout.buttonGapInLens)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
