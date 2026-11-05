//
//  ScanHeader.swift
//  MyPharmacist
//

import SwiftUI

/// Everything the person reads during a scan, in one line above the camera view: what
/// to do now, that the pills are being checked, or what to do with them. Nothing is
/// written over the camera picture. A new line fades in only after the old one has faded
/// out, so two never overlap.
struct ScanHeader: View {
    let scan: ScanFlow

    private static let lineChange = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeIn(duration: 0.2).delay(0.15)),
        removal: .opacity.animation(.easeOut(duration: 0.15))
    )

    var body: some View {
        let title = title
        ZStack {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // The results' line comes with its level's icon: the same one the
                // page's sections use.
                if let level {
                    Image(systemName: level.icon)
                        .foregroundStyle(level.color)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .foregroundStyle(Palette.textPrimary)
            }
            .font(.title2.bold())
            .id(title)
            .transition(Self.lineChange)
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 24)
        // Centred in the space above the camera view.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: title)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var title: String {
        switch scan.phase {
        case .aiming:
            // Without a camera there is nothing to aim, only why.
            scan.scanner.cameraMessage
                ?? ScanInstruction.whileAiming(status: scan.scanner.captureStatus, foundNoPills: scan.foundNoPills)
        case .finding:
            ScanInstruction.checking
        case .checking(let count):
            ScanInstruction.checking(count: count)
        case .results(let result):
            result.summary
        }
    }

    private var level: ResultLevel? {
        if case .results(let result) = scan.phase { result.summaryLevel } else { nil }
    }
}
