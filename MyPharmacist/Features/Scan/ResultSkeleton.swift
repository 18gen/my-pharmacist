//
//  ResultSkeleton.swift
//  MyPharmacist
//

import SwiftUI

/// The list's shape while the pills are checked: a heading and one row per pill, in the
/// sizes of the real ones, in grey. The levels aren't known yet, so neither are the
/// headings or the order: no pictures or words, only where they will be. The blocks
/// slowly breathe, and hold still with Reduce Motion.
struct ResultSkeleton: View {
    let count: Int

    @ScaledMetric(relativeTo: .title3) private var pictureSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title3) private var headingSize: CGFloat = 22
    @ScaledMetric(relativeTo: .title3) private var titleHeight: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var reasonHeight: CGFloat = 14
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                blocks
            } else {
                PhaseAnimator([false, true]) { dimmed in
                    blocks.opacity(dimmed ? 0.45 : 1)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
            }
        }
        // The heading above says the pills are being checked.
        .accessibilityHidden(true)
    }

    private var blocks: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .frame(width: headingSize, height: headingSize)
                Capsule()
                    .frame(width: 150, height: headingSize * 0.75)
            }
            .foregroundStyle(Palette.skeleton)
            ForEach(0..<count, id: \.self) { _ in
                row
            }
        }
    }

    /// In the shape of `ResultRow`.
    private var row: some View {
        HStack(spacing: 14) {
            if !typeSize.isAccessibilitySize {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .frame(width: pictureSize, height: pictureSize)
            }
            VStack(alignment: .leading, spacing: 10) {
                Capsule()
                    .frame(maxWidth: 170)
                    .frame(height: titleHeight)
                Capsule()
                    .frame(maxWidth: 110)
                    .frame(height: reasonHeight)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.skeleton)
        .padding(12)
        .frame(minHeight: pictureSize + 24)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.cardFill))
    }
}
