//
//  ScanPictogramView.swift
//  MyPharmacist
//

import SwiftUI

/// A scan instruction as a picture: a large symbol on a soft round tile that moves the way
/// the person should (a phone tilting, a phone moving away), so the instruction comes
/// across without reading. With Reduce Motion on, the picture keeps still.
struct ScanPictogramView: View {
    let pictogram: ScanPictogram

    @ScaledMetric(relativeTo: .title2) private var tileSize: CGFloat = 76
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                drawing(phase: false)
            } else {
                // Each loop goes to the moved state and back, at the instruction's pace.
                PhaseAnimator([false, true]) { phase in
                    drawing(phase: phase)
                } animation: { _ in
                    .easeInOut(duration: duration)
                }
            }
        }
        .frame(width: tileSize, height: tileSize)
        .background(Circle().fill(Palette.cardFill))
        .foregroundStyle(Palette.textPrimary)
        // The words beside it say the same.
        .accessibilityHidden(true)
    }

    private var symbolSize: CGFloat { tileSize * 0.5 }

    /// Slow for calm instructions, a little quicker for "hold still".
    private var duration: Double {
        switch pictogram {
        case .holdStill: 0.6
        case .tilt, .moveBack: 0.9
        case .aim, .noPills, .checking: 1.0
        case .moreLight, .lessLight: 1.2
        }
    }

    /// The picture at rest (`phase` false) or moved (`phase` true).
    @ViewBuilder
    private func drawing(phase: Bool) -> some View {
        switch pictogram {
        case .aim:
            ZStack {
                Image(systemName: "viewfinder")
                    .font(.system(size: symbolSize * 1.25, weight: .light))
                    .scaleEffect(phase ? 0.88 : 1)
                Image(systemName: "pills.fill")
                    .font(.system(size: symbolSize * 0.55))
            }
        case .noPills:
            ZStack {
                Image(systemName: "viewfinder")
                    .font(.system(size: symbolSize * 1.25, weight: .light))
                Image(systemName: "pills.fill")
                    .font(.system(size: symbolSize * 0.55))
                    .opacity(phase ? 0.15 : 1)
            }
        case .holdStill:
            Image(systemName: "hand.raised.fill")
                .font(.system(size: symbolSize))
                .scaleEffect(phase ? 1.1 : 1)
        case .moreLight:
            Image(systemName: "lightbulb.fill")
                .font(.system(size: symbolSize))
                .opacity(phase ? 1 : 0.45)
                .scaleEffect(phase ? 1.08 : 1)
        case .lessLight:
            Image(systemName: "sun.max.fill")
                .font(.system(size: symbolSize))
                .rotationEffect(.degrees(phase ? 30 : 0))
        case .tilt:
            Image(systemName: "iphone")
                .font(.system(size: symbolSize))
                .rotation3DEffect(.degrees(phase ? 32 : -32), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        case .moveBack:
            Image(systemName: "iphone")
                .font(.system(size: symbolSize))
                .scaleEffect(phase ? 0.68 : 1.05)
        case .checking:
            Image(systemName: "magnifyingglass")
                .font(.system(size: symbolSize * 0.9, weight: .semibold))
                .offset(x: phase ? 5 : -5, y: phase ? -3 : 3)
        }
    }
}
