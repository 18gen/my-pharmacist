//
//  WhenNeededCard.swift
//  MyPharmacist
//

import SwiftUI

/// Medications taken only when needed, below the day's times: they belong to no time of
/// day, but it helps to remember they're there, and when they're for. Folded to its header
/// line like every card that isn't due now; tapping it opens it. One taken today (ticked,
/// or scanned, which ticks it) has a tick and the time, and the header says when the last
/// was taken, so it shows while the card is folded too.
struct WhenNeededCard: View {
    /// Each medication with when it was taken today, if it was, and what its box does.
    let items: [MedicationLineList.Item]
    @Binding var isExpanded: Bool
    /// Called once the card has finished opening.
    let onOpened: () -> Void

    var body: some View {
        FoldingCard(folds: true, isExpanded: $isExpanded, onOpened: onOpened) {
                HStack(spacing: 8) {
                    Label {
                        // Never due "now", so always in the softer black of the other
                        // times of day that aren't due.
                        Text("When needed")
                            .font(.title3.bold())
                            .foregroundStyle(Palette.textSubtitle)
                            .lineLimit(1)
                            .layoutPriority(1)
                    } icon: {
                        Image(systemName: "cross.case.fill")
                            .font(.title3)
                            .foregroundStyle(Palette.textSubtitle)
                    }
                    Spacer(minLength: 8)
                    if let lastTaken {
                        // The tick and the time only: with "Taken" too, "When needed" no
                        // longer fits on one line beside it.
                        Label(lastTaken.shortTime, systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Palette.ok)
                            .lineLimit(1)
                            .accessibilityLabel("Taken at \(lastTaken.shortTime)")
                    }
                    FoldChevron(isExpanded: isExpanded)
                }
        } rows: {
            MedicationLineList(items: items)
        }
    }

    /// The latest time today any of them was taken.
    private var lastTaken: Date? {
        items.compactMap(\.takenAt).max()
    }
}
