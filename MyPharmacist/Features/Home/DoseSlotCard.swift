//
//  DoseSlotCard.swift
//  MyPharmacist
//

import SwiftUI

/// One time of day on the home screen, like one compartment of a pill organizer:
/// "Morning · 8:00 AM" with where it stands, and its medications. Only the time of day to
/// take now is open, and outlined; every other one is folded to its header line, which
/// opens it on a tap.
struct DoseSlotCard: View {
    let slot: DoseSlot
    /// Whether a folded slot has been opened; the slot to take now is always open.
    @Binding var isExpanded: Bool
    /// Called once a folded slot has finished opening.
    let onOpened: () -> Void

    private static let cornerRadius: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if slot.status.isFolded {
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
                SlotHeader(slot: slot, isExpanded: nil)
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
        MedicationLineList(items: slot.items.map { item in
            if case .scanned(let time) = item.state { (item.dose.medication, time) } else { (item.dose.medication, nil) }
        })
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

/// "Morning · 8:00 AM" with the time of day's symbol, and on the right where it stands,
/// with a chevron when the card folds.
private struct SlotHeader: View {
    let slot: DoseSlot
    /// Nil for a card that is always open.
    let isExpanded: Bool?

    var body: some View {
        // Side by side when it fits; the status under the title at large text sizes.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                title
                Spacer(minLength: 8)
                status
                chevron
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    title
                    Spacer(minLength: 8)
                    chevron
                }
                status
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// The darkest text only for the time of day to take now, so it stands out from the
    /// rest, which are in the date's softer black.
    private var title: some View {
        let period = DayPeriod(slot.time)
        let colour = slot.status == .now ? Palette.textPrimary : Palette.textSubtitle
        return Label {
            Text("\(period.name) · \(slot.scheduled.shortTime)")
                .font(.title3.bold())
                .foregroundStyle(colour)
        } icon: {
            Image(systemName: period.symbol)
                .font(.title3)
                .foregroundStyle(colour)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch slot.status {
        case .now:
            Text("Now")
                .font(.headline)
                .foregroundStyle(Palette.onDue)
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
            Label("Scanned \(time.shortTime)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Palette.ok)
        }
    }

    @ViewBuilder
    private var chevron: some View {
        if let isExpanded {
            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textMuted)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .accessibilityHidden(true)
        }
    }
}

/// The words and symbol for a time of day, like the labels on a pill organizer.
struct DayPeriod {
    let name: String
    let symbol: String

    init(_ time: DoseTime) {
        switch time.hour {
        // Midnight and the small hours belong with the night before, not the morning.
        case ..<5: (name, symbol) = ("Bedtime", "bed.double.fill")
        case ..<11: (name, symbol) = ("Morning", "sunrise.fill")
        case ..<15: (name, symbol) = ("Midday", "sun.max.fill")
        case ..<18: (name, symbol) = ("Afternoon", "sun.min.fill")
        case ..<22: (name, symbol) = ("Evening", "moon.fill")
        default: (name, symbol) = ("Bedtime", "bed.double.fill")
        }
    }
}

#if DEBUG
/// For the canvas: the sample morning medications at 8 AM today, in each state.
private enum SlotPreview {
    static func slot(_ status: DoseSlot.Status, scanned: Bool = false) -> DoseSlot {
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        let medications = SampleMedications.demoList.map(\.medication).filter { $0.doseTimes.contains(DoseTime(8)) }.prefix(2)
        let items = medications.enumerated().map { index, medication in
            ScheduledDose(dose: Dose(medication: medication, time: DoseTime(8), day: morning),
                          state: scanned ? .scanned(at: morning.addingTimeInterval(Double(index + 2) * 60)) : .due)
        }
        return DoseSlot(time: DoseTime(8), scheduled: morning, items: Array(items), status: status)
    }
}

#Preview("Now, then scanned") {
    let now = Calendar.current.date(bySettingHour: 8, minute: 3, second: 0, of: Date()) ?? Date()
    ScrollView {
        VStack(spacing: 16) {
            DoseSlotCard(slot: SlotPreview.slot(.now), isExpanded: .constant(true), onOpened: {})
            DoseSlotCard(slot: SlotPreview.slot(.done(at: now), scanned: true), isExpanded: .constant(true), onOpened: {})
            DoseSlotCard(slot: SlotPreview.slot(.next), isExpanded: .constant(false), onOpened: {})
        }
        .padding()
    }
}
#endif
