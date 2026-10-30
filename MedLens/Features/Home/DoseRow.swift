//
//  DoseRow.swift
//  MedLens
//

import SwiftUI

/// One dose: checkbox with its status, pill picture, name, strength and time.
struct DoseRow: View {
    let dose: Dose
    let state: DoseState
    let now: Date
    let onToggle: () -> Void

    /// Width of the checkbox + status column; grows with the text-size setting.
    @ScaledMetric(relativeTo: .subheadline) private var statusColumnWidth: CGFloat = 76
    @ScaledMetric(relativeTo: .title3) private var checkboxSize: CGFloat = 30
    @Environment(\.dynamicTypeSize) private var typeSize

    private var timeText: String {
        dose.scheduled.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox with its status underneath ("in 2 hr" → "Taken 7:55 AM"),
            // tappable as one large target.
            Button(action: onToggle) {
                VStack(spacing: 2) {
                    Image(systemName: state.isTaken ? "checkmark.square.fill" : "square")
                        .font(.system(size: checkboxSize))
                        .foregroundStyle(state.isTaken ? Palette.taken : Color(white: 0.3))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(height: checkboxSize + 6)
                    DoseStatusText(state: state, scheduled: dose.scheduled, now: now)
                }
                .frame(width: statusColumnWidth)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // At accessibility text sizes the picture gives its room to the name.
            if !typeSize.isAccessibilitySize {
                PillImage(medication: dose.medication, size: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(dose.medication.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(dose.medication.strength) · \(timeText)")
                    .font(.body)
                    .foregroundStyle(Color(white: 0.35))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .opacity(state.isPending ? 1 : 0.75)
        // VoiceOver: one element per dose, double-tap toggles.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dose.medication.displayName), \(timeText)")
        .accessibilityValue(DoseStatusText.spokenStatus(state: state, scheduled: dose.scheduled, now: now))
        .accessibilityHint(state.isTaken ? "Double tap to mark as not taken" : "Double tap to mark as taken")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onToggle() }
    }
}

/// "in 2 hr", "Now", "1 hr late", or the time it was taken ("8:02 AM").
private struct DoseStatusText: View {
    let state: DoseState
    let scheduled: Date
    let now: Date

    var body: some View {
        switch state {
        case .upcoming:
            label("\(Self.duration(scheduled.timeIntervalSince(now)))", color: Color(white: 0.4))
        case .due:
            label("Now", color: Palette.due, weight: .bold)
        case .late:
            label("\(Self.duration(now.timeIntervalSince(scheduled))) late", color: Palette.late, weight: .bold)
        case .taken(let time):
            // The "Taken" section header says what this time means.
            label(time.formatted(date: .omitted, time: .shortened), color: Palette.taken, weight: .bold)
        }
    }

    private func label(_ text: String, color: Color, weight: Font.Weight = .semibold) -> some View {
        Text(text)
            .font(.subheadline.weight(weight))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Rounded to whole minutes under an hour, otherwise whole hours.
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(max(minutes, 1)) min" }
        return "\(Int((Double(minutes) / 60).rounded())) hr"
    }

    static func spokenStatus(state: DoseState, scheduled: Date, now: Date) -> String {
        func spoken(_ seconds: TimeInterval) -> String {
            duration(seconds).replacingOccurrences(of: "hr", with: "hours").replacingOccurrences(of: "min", with: "minutes")
        }
        switch state {
        case .upcoming: return "Not taken. Due in \(spoken(scheduled.timeIntervalSince(now)))"
        case .due: return "Not taken. Due now"
        case .late: return "Not taken. \(spoken(now.timeIntervalSince(scheduled))) late"
        case .taken(let time): return "Taken at \(time.formatted(date: .omitted, time: .shortened))"
        }
    }
}
