//
//  CaptureHint.swift
//  MyPharmacist
//

import SwiftUI

/// The one thing to fix about the camera picture (or that it looks good), shown at the
/// top of the camera view. Icon and text, so it never relies on colour alone. A picture
/// problem comes first; after that, that the last photo had no pills in it.
struct CaptureHint: View {
    let status: QualityGate.Status
    /// The last photo had no pills in it.
    var foundNoPills = false

    var body: some View {
        if let content = CaptureHintPresentation.hint(for: status, foundNoPills: foundNoPills) {
            HStack(spacing: 8) {
                Image(systemName: content.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(content.color)
                    .accessibilityHidden(true)
                Text(content.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            )
            .accessibilityElement(children: .combine)
            .transition(.opacity)
            .id(content.text)
        }
    }
}

#if DEBUG
/// The raw quality numbers under the hint, for tuning the thresholds on a device.
/// Takes the model so only this view redraws for every frame.
struct QualityReadout: View {
    let model: ScannerModel

    var body: some View {
        if let m = model.latestQuality?.measurements {
            let motion = m.motion.map { String(format: "%.3f", $0) } ?? "–"
            Text(String(format: "light %.2f  clip %.1f%%  sharp %.0f/%.0f  ",
                        m.brightness, m.clippedFraction * 100, m.sharpness, m.recentBestSharpness) + "move \(motion)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5), in: Capsule())
                .accessibilityHidden(true)
        }
    }
}
#endif
