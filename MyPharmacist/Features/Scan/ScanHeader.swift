//
//  ScanHeader.swift
//  MyPharmacist
//

import SwiftUI

/// The title above the camera view: what to do now, or what the photo showed.
struct ScanHeader: View {
    let phase: ScanFlow.Phase

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Palette.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Palette.textBody)
            }
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .animation(.easeInOut(duration: 0.2), value: phase.step)
    }

    private var title: String {
        switch phase {
        case .aiming: "Show the pills you're about to take"
        case .checking: "Checking your pills…"
        case .results(let result): result.summary
        case .noPills: "No pills found"
        }
    }

    private var subtitle: String? {
        switch phase {
        case .aiming:
            "Spread them apart in your hand or on a plain surface."
        case .checking:
            nil
        case .results(let result):
            result.isAllClear ? nil : "Put back any pill marked in red."
        case .noPills:
            "Spread the pills apart on a plain surface and try again."
        }
    }
}
