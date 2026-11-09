//
//  ScanHeader.swift
//  MyPharmacist
//

import SwiftUI

/// Everything the person reads during a scan, above the camera view: what to do now
/// (shown as a moving picture and in a few words), that the pills are being checked, or
/// what to do with them. Nothing is drawn over the camera picture. A new instruction fades
/// in only after the old one has faded out, so two never overlap.
struct ScanHeader: View {
    let scan: ScanFlow

    private static let lineChange = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeIn(duration: 0.2).delay(0.15)),
        removal: .opacity.animation(.easeOut(duration: 0.15))
    )

    var body: some View {
        let line = line
        ZStack {
            // The picture above the words when both fit; at large text sizes or on a small
            // screen, the words alone.
            ViewThatFits(in: .vertical) {
                VStack(spacing: 12) {
                    if let pictogram = line.pictogram {
                        ScanPictogramView(pictogram: pictogram)
                    }
                    words(line.text)
                }
                words(line.text)
            }
            .id(line.text)
            .transition(Self.lineChange)
        }
        .padding(.horizontal, 24)
        // Centred in the space above the camera view.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: line.text)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func words(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // The results' line comes with its level's icon: the same one the page's
            // sections use.
            if let level {
                Image(systemName: level.icon)
                    .foregroundStyle(level.color)
                    .accessibilityHidden(true)
            }
            Text(text)
                .foregroundStyle(Palette.textPrimary)
        }
        .font(.title2.bold())
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
    }

    private var line: ScanInstruction.Line {
        switch scan.phase {
        case .aiming:
            // Without a camera there is nothing to aim, only why.
            if let message = scan.scanner.cameraMessage {
                ScanInstruction.Line(text: message, pictogram: nil)
            } else {
                ScanInstruction.whileAiming(status: scan.scanner.captureStatus)
            }
        case .finding:
            ScanInstruction.checking
        case .retake(_, let reason):
            ScanInstruction.retake(reason)
        case .checking(let count):
            ScanInstruction.checking(count: count)
        case .results(let result):
            ScanInstruction.Line(text: result.summary, pictogram: nil)
        }
    }

    private var level: ResultLevel? {
        if case .results(let result) = scan.phase { result.summaryLevel } else { nil }
    }
}
