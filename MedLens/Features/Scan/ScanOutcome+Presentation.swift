//
//  ScanOutcome+Presentation.swift
//  MedLens
//

import SwiftUI

/// How a scan outcome is shown: the banner's icon, colour and wording.
struct ScanOutcomePresentation {
    let icon: String
    let color: Color
    let title: String
    let message: String
}

extension ScanOutcome {
    var presentation: ScanOutcomePresentation {
        switch self {
        case .checked(let dose):
            return ScanOutcomePresentation(
                icon: "checkmark.circle.fill", color: Palette.taken,
                title: "Checked: \(dose.medication.displayName)",
                message: "\(dose.scheduled.shortTime) dose marked as taken.")
        case .alreadyTaken(let dose, let takenAt, let next):
            let nextText = next.map { "Next dose at \($0.scheduled.shortTime)." } ?? "No more doses today."
            return ScanOutcomePresentation(
                icon: "exclamationmark.triangle.fill", color: Palette.late,
                title: "Already taken today",
                message: "\(dose.medication.displayName) was taken at \(takenAt.shortTime). \(nextText)")
        case .tooEarly(let next):
            return ScanOutcomePresentation(
                icon: "clock.fill", color: Palette.late,
                title: "Not time yet",
                message: "Next \(next.medication.displayName) dose is at \(next.scheduled.shortTime).")
        case .notScheduledToday(let medication):
            return ScanOutcomePresentation(
                icon: "info.circle.fill", color: Palette.textMuted,
                title: "No dose to take now",
                message: "\(medication.displayName) has no more doses today.")
        case .notOnList(let scannedName):
            return ScanOutcomePresentation(
                icon: "questionmark.circle.fill", color: Palette.textMuted,
                title: "Not on your list",
                message: "\(scannedName) isn't one of your medications.")
        case .unsure:
            return ScanOutcomePresentation(
                icon: "questionmark.circle.fill", color: Palette.textMuted,
                title: "Not sure which medication",
                message: "Check the label and try again.")
        }
    }

    /// Spoken by VoiceOver when the banner appears.
    var announcement: String {
        "\(presentation.title). \(presentation.message)"
    }

    /// The vibration that comes with the banner: success, a warning to stop, or an error.
    var feedback: SensoryFeedback {
        switch self {
        case .checked: return .success
        case .alreadyTaken, .tooEarly: return .warning
        case .notOnList, .unsure, .notScheduledToday: return .error
        }
    }
}
