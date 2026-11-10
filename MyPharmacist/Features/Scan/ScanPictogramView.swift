//
//  ScanPictogramView.swift
//  MyPharmacist
//

import SwiftUI

/// A scan instruction as a picture: a large symbol on a soft round tile that moves the way
/// the person should (a phone tilting, a phone moving away), so the instruction comes
/// across without reading. With Reduce Motion on, the picture keeps still.
///
/// On the camera picture it is white on a dark see-through badge: the picture behind it
/// can be anything (skin, a table, white paper, a dim room), and only white on dark stays
/// clear on all of them. No colour carries meaning; the words above say the same.
struct ScanPictogramView: View {
    let pictogram: ScanPictogram
    /// Drawn on the camera picture rather than on the page.
    var onCamera = false

    @ScaledMetric(relativeTo: .title2) private var tileSize: CGFloat = 76
    @ScaledMetric(relativeTo: .title2) private var badgeSize: CGFloat = 84
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
        .frame(width: side, height: side)
        .background {
            if onCamera {
                RoundedRectangle(cornerRadius: side * 0.28, style: .continuous).fill(.black.opacity(0.55))
            } else {
                Circle().fill(Palette.cardFill)
            }
        }
        .foregroundStyle(onCamera ? .white : Palette.textPrimary)
        // The words beside it say the same.
        .accessibilityHidden(true)
    }

    private var side: CGFloat { onCamera ? badgeSize : tileSize }
    private var symbolSize: CGFloat { side * 0.5 }

    /// Slow for calm instructions, a little quicker for "hold still".
    private var duration: Double {
        switch pictogram {
        case .holdStill: 0.6
        case .tilt, .moveBack, .moveCloser: 0.9
        case .aim, .noPills, .checking, .spreadApart, .toTheMiddle, .plainSurface, .again: 1.0
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
        case .spreadApart:
            HStack(spacing: 0) {
                Image(systemName: "pill.fill")
                    .offset(x: phase ? -symbolSize * 0.22 : 0)
                Image(systemName: "pill.fill")
                    .offset(x: phase ? symbolSize * 0.22 : 0)
            }
            .font(.system(size: symbolSize * 0.5))
        case .toTheMiddle:
            ZStack {
                Image(systemName: "viewfinder")
                    .font(.system(size: symbolSize * 1.25, weight: .light))
                Image(systemName: "pills.fill")
                    .font(.system(size: symbolSize * 0.5))
                    .offset(x: phase ? 0 : -symbolSize * 0.42, y: phase ? 0 : -symbolSize * 0.3)
            }
        case .moveCloser:
            Image(systemName: "iphone")
                .font(.system(size: symbolSize))
                .scaleEffect(phase ? 1.1 : 0.68)
        case .plainSurface:
            ZStack {
                Image(systemName: "rectangle")
                    .font(.system(size: symbolSize * 1.2, weight: .light))
                Image(systemName: "pills.fill")
                    .font(.system(size: symbolSize * 0.5))
                    .offset(y: phase ? 0 : -symbolSize * 0.45)
                    .opacity(phase ? 1 : 0.35)
            }
        case .again:
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: symbolSize * 0.9, weight: .semibold))
                .rotationEffect(.degrees(phase ? -40 : 20))
        }
    }
}
