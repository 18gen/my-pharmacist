//
//  QualityGate+Presentation.swift
//  MyPharmacist
//

import SwiftUI

/// How the camera's quality status is shown: the hint's icon, colour and wording.
struct CaptureHintPresentation {
    let icon: String
    let color: Color
    let text: String

    static let noPills = CaptureHintPresentation(
        icon: "questionmark.circle", color: Palette.late,
        text: "No pills found. Spread them apart in view"
    )

    /// What to show while aiming: a picture problem first (step 1), then that the last
    /// photo had no pills in it (step 2), then the picture's status.
    static func hint(for status: QualityGate.Status, foundNoPills: Bool) -> CaptureHintPresentation? {
        if case .needs = status { return status.presentation }
        return foundNoPills ? noPills : status.presentation
    }
}

extension QualityGate.Status {
    /// Nil while there aren't enough frames yet to say anything.
    var presentation: CaptureHintPresentation? {
        switch self {
        case .checking:
            return nil
        case .ready:
            return CaptureHintPresentation(icon: "checkmark.circle.fill", color: Palette.taken, text: "Looks good, hold there")
        case .needs(let issue):
            return CaptureHintPresentation(icon: issue.icon, color: Palette.late, text: issue.hint)
        }
    }
}

extension QualityIssue {
    var hint: String {
        switch self {
        case .tooDark: "Too dark. Move to a brighter spot"
        case .tooBright: "Too bright. Move out of direct light"
        case .glare: "Glare. Tilt your hand a little"
        case .moving: "Hold still"
        case .focusing: "Focusing…"
        case .blurry: "Blurry. Move the phone a little farther away"
        }
    }

    var icon: String {
        switch self {
        case .tooDark: "sun.min"
        case .tooBright: "sun.max"
        case .glare: "sparkles"
        case .moving: "hand.raised"
        case .focusing: "viewfinder"
        case .blurry: "camera.aperture"
        }
    }
}
