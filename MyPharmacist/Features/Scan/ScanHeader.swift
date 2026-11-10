//
//  ScanHeader.swift
//  MyPharmacist
//

import SwiftUI

/// What the person reads during a scan, above the camera view: what to do now, in a few
/// words in very large letters, or that the pills are being checked. The moving picture
/// that goes with it is
/// drawn on the camera picture (`CameraLens`), where the person is already looking.
/// The results page says what to do with the pills at its own top. A new instruction
/// fades in only after the old one has faded out, so two never overlap.
struct ScanHeader: View {
    let scan: ScanFlow

    /// About 40 points: far larger than ordinary text, and larger still with larger
    /// text settings, up to what two lines above the camera view can hold.
    @ScaledMetric(relativeTo: .largeTitle) private var textSize: CGFloat = 40

    private static let lineChange = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeIn(duration: 0.2).delay(0.15)),
        removal: .opacity.animation(.easeOut(duration: 0.15))
    )

    var body: some View {
        let text = scan.instruction.text
        ZStack {
            Text(text)
                .font(.system(size: textSize, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .id(text)
                .transition(Self.lineChange)
        }
        .padding(.horizontal, 20)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // Low in the space above the camera view, close to the picture it is about.
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.easeInOut(duration: 0.2), value: text)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension ScanFlow {
    /// What to do now, in words and as a moving picture.
    var instruction: ScanInstruction.Line {
        switch phase {
        case .aiming:
            // Without a camera there is nothing to aim, only why.
            if let message = scanner.cameraMessage {
                ScanInstruction.Line(text: message, pictogram: nil)
            } else {
                ScanInstruction.whileAiming(status: scanner.captureStatus,
                                            canTurnOnLight: scanner.hasLight && !scanner.isLightOn)
            }
        case .finding:
            ScanInstruction.checking
        case .retake(_, let reason):
            ScanInstruction.retake(reason)
        case .confirming(let found):
            ScanInstruction.confirm(count: found.boxes.count)
        case .checking:
            ScanInstruction.checking
        case .results:
            // Not shown: the results page has its own heading.
            ScanInstruction.Line(text: "", pictogram: nil)
        }
    }
}
