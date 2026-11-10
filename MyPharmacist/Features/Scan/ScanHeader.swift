//
//  ScanHeader.swift
//  MyPharmacist
//

import SwiftUI

/// Everything the person reads during a scan, above the camera view: what to do now
/// (shown as a moving picture and in a few words) or that the pills are being checked.
/// The results page says what to do with the pills at its own top. Nothing is drawn over
/// the camera picture. A new instruction fades in only after the old one has faded out,
/// so two never overlap.
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
        Text(text)
            .foregroundStyle(Palette.textPrimary)
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
        case .confirming(let found):
            ScanInstruction.confirm(count: found.boxes.count)
        case .checking(let count):
            ScanInstruction.checking(count: count)
        case .results:
            // Not shown: the results page has its own heading.
            ScanInstruction.Line(text: "", pictogram: nil)
        }
    }
}
