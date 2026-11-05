//
//  CameraButton.swift
//  MyPharmacist
//

import SwiftUI

/// One button in one place: a camera icon on the home screen, an X on the camera screen.
/// On the home screen a "Scan Pills" hint and a hand-drawn arrow point to it; they are
/// part of the same button, so tapping the hint opens the camera too. The results page
/// has buttons of its own, so it hides there.
struct CameraButton: View {
    /// Leave quickly as the camera grows; return once it has shrunk back.
    static let hintTransition = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeIn(duration: 0.25).delay(0.3)),
        removal: .opacity.animation(.easeOut(duration: 0.12))
    )

    let isScanning: Bool
    /// The scan view has turned into the white results page, so the X needs a grey circle.
    var isOnPage = false
    var isHidden = false
    /// Something is due now: "Scan Pills", the arrow and the button (the lens behind it)
    /// turn the blue of the "Now" card, so the two read as one.
    var isDue = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                if !isScanning {
                    Text("Scan Pills")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(isDue ? Palette.due : Palette.textProminent)
                        .transition(Self.hintTransition)
                }

                Image(systemName: isScanning ? "xmark" : "camera.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(isScanning ? .black : .white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: ScanLayout.buttonSize, height: ScanLayout.buttonSize)
                    .background {
                        if isScanning {
                            Circle()
                                .fill(isOnPage ? Palette.cardFill : .white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    // The arrow curls from under the text into the button's left side.
                    .overlay(alignment: .leading) {
                        if !isScanning {
                            ScanArrow(color: isDue ? Palette.due : Palette.drawing)
                                .frame(width: 56, height: 78)
                                .offset(x: -62, y: -24)
                                .transition(Self.hintTransition)
                        }
                    }
            }
            .contentShape(Rectangle())
        }
        .opacity(isHidden ? 0 : 1)
        .allowsHitTesting(!isHidden)
        .accessibilityHidden(isHidden)
        // Out quickly before the page's own buttons fade in where it was; back in only
        // once they have gone.
        .animation(isHidden ? .easeOut(duration: 0.1) : .easeIn(duration: 0.2).delay(0.15), value: isHidden)
        .animation(.easeInOut(duration: 0.3), value: isDue)
        .accessibilityLabel(isScanning ? "Close camera" : "Scan pills")
        .accessibilityValue(!isScanning && isDue ? "Medications due now" : "")
        .accessibilityHint(isScanning ? "" : "Opens the camera to check the pills you're about to take")
        // A light tap of vibration each time the camera opens or closes.
        .sensoryFeedback(.impact(weight: .light), trigger: isScanning)
        .padding(.bottom, ScanLayout.buttonBottomInset)
        .ignoresSafeArea(edges: .bottom)
    }
}
