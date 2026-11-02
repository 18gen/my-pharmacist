//
//  PillVerdict+Presentation.swift
//  MyPharmacist
//

import SwiftUI

/// How a pill's verdict is shown: icon, colour, a short title and one line of detail.
struct PillVerdictPresentation {
    let icon: String
    let color: Color
    let title: String
    let detail: String
}

extension PillVerdict {
    var presentation: PillVerdictPresentation {
        switch self {
        case .take(let dose):
            return PillVerdictPresentation(
                icon: "checkmark.circle.fill", color: Palette.taken,
                title: "Take now", detail: "\(dose.scheduled.shortTime) dose")
        case .alreadyTaken(_, let takenAt, let next):
            let nextText = next.map { " Next dose at \($0.scheduled.shortTime)." } ?? ""
            return PillVerdictPresentation(
                icon: "xmark.circle.fill", color: Palette.danger,
                title: "Don't take", detail: "Already taken at \(takenAt.shortTime).\(nextText)")
        case .tooEarly(let next):
            return PillVerdictPresentation(
                icon: "xmark.circle.fill", color: Palette.danger,
                title: "Don't take yet", detail: "Next dose is at \(next.scheduled.shortTime).")
        case .notScheduledToday:
            return PillVerdictPresentation(
                icon: "xmark.circle.fill", color: Palette.danger,
                title: "Don't take", detail: "No dose of this today.")
        case .extra:
            return PillVerdictPresentation(
                icon: "xmark.circle.fill", color: Palette.danger,
                title: "Don't take", detail: "Extra pill: one is enough.")
        case .unidentified:
            return PillVerdictPresentation(
                icon: "questionmark.circle.fill", color: Palette.danger,
                title: "Can't confirm", detail: "Not recognized as one of your medications. Check with your pharmacist.")
        }
    }
}

extension PillScanResult {
    /// One line summing up the photo, for the title and VoiceOver.
    var summary: String {
        let take = dosesToTake.count
        if notToTakeCount == 0 && missing.isEmpty {
            return take == 1 ? "This pill is right to take" : "All \(take) pills are right to take"
        }
        var parts: [String] = []
        if take > 0 { parts.append("\(take) to take") }
        if notToTakeCount > 0 { parts.append("\(notToTakeCount) not to take") }
        if !missing.isEmpty { parts.append("\(missing.count) missing") }
        return parts.joined(separator: " · ")
    }

    /// Whether everything is in order, for the haptic: success or a warning.
    var isAllClear: Bool { notToTakeCount == 0 && missing.isEmpty }
}
