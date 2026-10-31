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
