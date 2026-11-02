//
//  DoseRow.swift
//  MyPharmacist
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
        dose.scheduled.shortTime
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox with its status underneath ("2 hr" → "7:55 AM"),
            // tappable as one large target.
            Button(action: onToggle) {
                VStack(spacing: 2) {
                    Image(systemName: state.isTaken ? "checkmark.square.fill" : "square")
                        .font(.system(size: checkboxSize))
                        .foregroundStyle(state.isTaken ? Palette.taken : Palette.controlInactive)
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
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(dose.medication.strength) · \(timeText)")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .opacity(state.isPending ? 1 : 0.75)
        // VoiceOver: one element per dose, double-tap toggles.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dose.medication.displayName), \(timeText)")
        .accessibilityValue(DoseStatusFormatter.spokenStatus(state: state, scheduled: dose.scheduled, now: now))
        .accessibilityHint(state.isTaken ? "Double tap to mark as not taken" : "Double tap to mark as taken")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onToggle() }
    }
}

/// The dose's status under its checkbox, coloured by state; wording from `DoseStatusFormatter`.
private struct DoseStatusText: View {
    let state: DoseState
    let scheduled: Date
    let now: Date

    var body: some View {
        Text(DoseStatusFormatter.shortStatus(state: state, scheduled: scheduled, now: now))
            .font(.subheadline.weight(state == .upcoming ? .semibold : .bold))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var color: Color {
        switch state {
        case .upcoming: return Palette.textTertiary
        case .due: return Palette.due
        case .late: return Palette.late
        case .taken: return Palette.taken
        }
    }
}

/// Doses one under another, with dividers between them.
struct DoseRowList: View {
    let items: [ScheduledDose]
    let now: Date
    let onToggle: (ScheduledDose) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider()
                }
                DoseRow(dose: item.dose, state: item.state, now: now) {
                    onToggle(item)
                }
            }
        }
    }
}
