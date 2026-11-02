//
//  TodayCard.swift
//  MyPharmacist
//

import SwiftUI

/// Today's doses still to take, earliest first, with how many of the day's doses are
/// taken. Shows every row at full height; the home screen scrolls, not the card.
struct TodayCard: View {
    let toTake: [ScheduledDose]
    /// All of today's doses, taken or not.
    let totalCount: Int
    let now: Date
    let onCheck: (ScheduledDose) -> Void

    var body: some View {
        let allDone = totalCount > 0 && toTake.isEmpty

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if allDone {
                    Label("All done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Palette.taken)
                } else if totalCount > 0 {
                    Text("\(totalCount - toTake.count) of \(totalCount) taken")
                        .font(.headline)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .accessibilityElement(children: .combine)

            if totalCount == 0 {
                Text("No medications scheduled today.")
                    .font(.body)
                    .foregroundStyle(Palette.textTertiary)
            } else {
                DoseRowList(items: toTake, now: now, onToggle: onCheck)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

/// Today's taken doses in a card of their own below "Today": folded to a single row
/// (a peek at the pictures and a count) until tapped open. Tapping a taken row offers
/// to uncheck it.
struct TakenCard: View {
    let taken: [ScheduledDose]
    let now: Date
    @Binding var isExpanded: Bool
    let onUncheck: (ScheduledDose) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TakenDosesToggle(doses: taken.map(\.dose), isExpanded: $isExpanded)
            if isExpanded {
                DoseRowList(items: taken, now: now, onToggle: onUncheck)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
