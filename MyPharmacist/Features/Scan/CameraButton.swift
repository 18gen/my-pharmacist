//
//  CameraButton.swift
//  MyPharmacist
//

import SwiftUI

/// One button in one place: a camera icon on the home screen, an X on the camera screen.
/// On the home screen a "Scan Pills" hint and a hand-drawn arrow point to it; they are
/// part of the same button, so tapping the hint opens the camera too.
struct CameraButton: View {
    /// Leave quickly as the camera grows; return once it has shrunk back.
    static let hintTransition = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeIn(duration: 0.25).delay(0.3)),
        removal: .opacity.animation(.easeOut(duration: 0.12))
    )

    let isScanning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 28) {
                if !isScanning {
                    Text("Scan Pills")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Palette.textProminent)
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
                                .fill(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    // The arrow curls from under the text into the button's left side.
                    .overlay(alignment: .leading) {
                        if !isScanning {
                            ScanArrow()
                                .frame(width: 56, height: 78)
                                .offset(x: -62, y: -24)
                                .transition(Self.hintTransition)
                        }
                    }
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(isScanning ? "Close camera" : "Scan pills")
        .accessibilityHint(isScanning ? "" : "Opens the camera to check the pills you're about to take")
        // A light tap of vibration each time the camera opens or closes.
        .sensoryFeedback(.impact(weight: .light), trigger: isScanning)
        .padding(.bottom, ScanLayout.buttonBottomInset)
        .ignoresSafeArea(edges: .bottom)
    }
}
