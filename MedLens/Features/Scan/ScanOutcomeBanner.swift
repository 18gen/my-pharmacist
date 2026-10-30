//
//  ScanOutcomeBanner.swift
//  MedLens
//

import SwiftUI

/// Tells the person what their scan did: checked a dose, warned about a double dose,
/// too early, or not one of their medications.
struct ScanOutcomeBanner: View {
    let outcome: ScanOutcome
    let onUndo: () -> Void

    var body: some View {
        let content = Self.content(for: outcome)
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: content.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(content.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(content.message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            if case .checked = outcome {
                Button("Undo", action: onUndo)
                    .font(.headline)
                    .buttonStyle(.bordered)
                    .tint(Palette.textPrimary)
                    .accessibilityHint("Marks this dose as not taken")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        )
    }

    /// Spoken by VoiceOver when the banner appears.
    static func announcement(for outcome: ScanOutcome) -> String {
        let content = content(for: outcome)
        return "\(content.title). \(content.message)"
    }

    private static func content(for outcome: ScanOutcome) -> (icon: String, color: Color, title: String, message: String) {
        func time(_ date: Date) -> String { date.shortTime }

        switch outcome {
        case .checked(let dose):
            return ("checkmark.circle.fill", Palette.taken,
                    "Checked: \(dose.medication.displayName)",
                    "\(time(dose.scheduled)) dose marked as taken.")
        case .alreadyTaken(let dose, let takenAt, let next):
            let nextText = next.map { "Next dose at \(time($0.scheduled))." } ?? "No more doses today."
            return ("exclamationmark.triangle.fill", Palette.late,
                    "Already taken today",
                    "\(dose.medication.displayName) was taken at \(time(takenAt)). \(nextText)")
        case .tooEarly(let next):
            return ("clock.fill", Palette.late,
                    "Not time yet",
                    "Next \(next.medication.displayName) dose is at \(time(next.scheduled)).")
        case .notScheduledToday(let medication):
            return ("info.circle.fill", Palette.textMuted,
                    "No dose to take now",
                    "\(medication.displayName) has no more doses today.")
        case .notOnList(let scannedName):
            return ("questionmark.circle.fill", Palette.textMuted,
                    "Not on your list",
                    "\(scannedName) isn't one of your medications.")
        case .unsure:
            return ("questionmark.circle.fill", Palette.textMuted,
                    "Not sure which medication",
                    "Check the label and try again.")
        }
    }
}
