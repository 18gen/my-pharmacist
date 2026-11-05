//
//  DoseSlotCard.swift
//  MyPharmacist
//

import SwiftUI

/// One time of day on the home screen, like one compartment of a pill organizer:
/// "Morning · 8:00 AM" with where it stands, and its medications. The slot to take now
/// is outlined. Once every dose in it is scanned it folds to its header line, and tapping
/// that opens it again.
struct DoseSlotCard: View {
    let slot: DoseSlot
    /// Whether a done slot is open; slots still to take are always open.
    @Binding var isExpanded: Bool
    /// Called once a done slot has finished opening.
    let onOpened: () -> Void

    private static let cornerRadius: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if slot.status.isDone {
                Button(action: toggle) {
                    SlotHeader(slot: slot, isExpanded: isExpanded)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? "Double tap to hide these medications" : "Double tap to show these medications")

                // Opens like a drawer: the rows stay put and the card's edge moves.
                DrawerLayout(openFraction: isExpanded ? 1 : 0) {
                    rows.padding(.top, 8)
                }
                .clipped()
                .allowsHitTesting(isExpanded)
                .accessibilityHidden(!isExpanded)
            } else {
                SlotHeader(slot: slot, isExpanded: true)
                rows.padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .overlay {
            if slot.status == .now {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(Palette.due, lineWidth: 2.5)
            }
        }
    }

    private var rows: some View {
        MedicationLineList(items: slot.items.map { ($0.dose.medication, $0.state.isScanned) })
    }

    /// Opening reports back only once the card has finished growing: a scroll started
    /// mid-animation aims at where the rows were, not where they end up.
    private func toggle() {
        withAnimation(.spring(duration: 0.4)) {
            isExpanded.toggle()
        } completion: {
            if isExpanded { onOpened() }
        }
    }
}

/// "Morning · 8:00 AM" with the time of day's symbol, and on the right where it stands.
private struct SlotHeader: View {
    let slot: DoseSlot
    let isExpanded: Bool

    var body: some View {
        // Side by side when it fits; the status under the title at large text sizes.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                title
                Spacer(minLength: 8)
                status
            }
            VStack(alignment: .leading, spacing: 4) {
                title
                status
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var title: some View {
        let period = DayPeriod(slot.time)
        return Label {
            Text("\(period.name) · \(slot.scheduled.shortTime)")
                .font(.title3.bold())
                .foregroundStyle(Palette.textPrimary)
        } icon: {
            Image(systemName: period.symbol)
                .font(.title3)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch slot.status {
        case .now:
            Text("Now")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Palette.due))
        case .next:
            Text("Next")
                .font(.headline)
                .foregroundStyle(Palette.textTertiary)
        case .later:
            EmptyView()
        case .notScannedYet:
            Text("Not scanned yet")
                .font(.headline)
                .foregroundStyle(Palette.late)
        case .done(let time):
            HStack(spacing: 6) {
                Label("Scanned \(time.shortTime)", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Palette.ok)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
        }
    }
}

/// The words and symbol for a time of day, like the labels on a pill organizer.
struct DayPeriod {
    let name: String
    let symbol: String

    init(_ time: DoseTime) {
        switch time.hour {
        case ..<11: (name, symbol) = ("Morning", "sunrise.fill")
        case ..<15: (name, symbol) = ("Midday", "sun.max.fill")
        case ..<18: (name, symbol) = ("Afternoon", "sun.min.fill")
        case ..<22: (name, symbol) = ("Evening", "moon.fill")
        default: (name, symbol) = ("Bedtime", "bed.double.fill")
        }
    }
}
