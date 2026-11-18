//
//  DoseSlotCard.swift
//  MyPharmacist
//

import SwiftUI

/// One time of day on the home screen, like one compartment of a pill organizer:
/// "Morning · 8:00 AM" with where it stands, and its medications. Only the time of day to
/// take now is open, and outlined; every other one is folded to its header line, which
/// opens it on a tap. Each medication has a box to tick once it is taken, except in
/// a time of day still to come.
struct DoseSlotCard: View {
    let slot: DoseSlot
    /// Ticks or unticks one dose's "taken" box. Nil: no boxes.
    var onToggleTaken: ((ScheduledDose) -> Void)? = nil
    /// The pill of a scanned dose as it was scanned, if still in memory.
    var scanPhoto: (Dose) -> CGImage? = { _ in nil }
    /// Whether a folded slot has been opened; the slot to take now is always open.
    @Binding var isExpanded: Bool
    /// Called once a folded slot has finished opening.
    let onOpened: () -> Void

    private static let cornerRadius: CGFloat = 24

    var body: some View {
        // One build for every status, so going from "Now" to done changes what the card
        // says without rebuilding it: no jump under the finger after the last tick.
        let folds = slot.status.isFolded
        let open = !folds || isExpanded
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                SlotHeader(slot: slot, isExpanded: folds ? isExpanded : nil)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(folds)
            .accessibilityRemoveTraits(folds ? [] : .isButton)
            .accessibilityHint(!folds ? "" : isExpanded ? "Double tap to hide these medications" : "Double tap to show these medications")

            // Opens like a drawer: the rows stay put and the card's edge moves.
            DrawerLayout(openFraction: open ? 1 : 0) {
                rows.padding(.top, 8)
            }
            .clipped()
            .allowsHitTesting(open)
            .accessibilityHidden(!open)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .raisedCardBackground()
        .overlay {
            if slot.status == .now {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(Palette.due, lineWidth: 2.5)
            }
        }
    }

    private var rows: some View {
        MedicationLineList(items: slot.items.map { item in
            MedicationLineList.Item(medication: item.dose.medication, scannedAt: item.state.scannedAt,
                                    scanPhoto: item.state.scannedAt == nil ? nil : scanPhoto(item.dose),
                                    takenAt: item.state.takenAt,
                                    onToggleTaken: canTick ? onToggleTaken.map { toggle in { toggle(item) } } : nil)
        })
    }

    /// A dose can be ticked once its time of day has come: not while it is next or later.
    private var canTick: Bool {
        switch slot.status {
        case .next, .later: false
        case .now, .notTakenYet, .done: true
        }
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
/// with a chevron when the card folds. Folded once everything in it is taken, it reads
/// "Morning ✓ Taken 8:04 AM" instead; open, the rows show each time, so nothing stands
/// beside the title.
private struct SlotHeader: View {
    let slot: DoseSlot
    /// Nil for a card that is always open.
    let isExpanded: Bool?

    /// A finished time of day while folded: when its last dose was taken.
    private var summary: Date? {
        if isExpanded == false, case .done(let time) = slot.status { return time }
        return nil
    }

    var body: some View {
        // Side by side when it fits; the status under the title at large text sizes.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                title
                Spacer(minLength: 8)
                reserved { status }
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

    /// Always as tall as the "Now" capsule, whatever stands there, so the header line
    /// never moves when the status changes. Only its height is kept, not its width, so
    /// the title keeps its room at large text sizes.
    private func reserved(@ViewBuilder _ content: () -> some View) -> some View {
        ZStack(alignment: .trailing) {
            nowCapsule.fixedSize().frame(width: 0).hidden()
            content()
        }
    }

    private var nowCapsule: some View {
        Text("Now")
            .font(.headline)
            .foregroundStyle(Palette.onDue)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Palette.due))
    }

    /// "✓ Taken 8:04 AM".
    private func summaryLabel(_ time: Date) -> some View {
        Label("Taken \(time.shortTime)", systemImage: "checkmark.circle.fill")
            .font(.headline)
            .monospacedDigit()
            .foregroundStyle(Palette.ok)
    }

    /// The darkest text only for the time of day to take now, so it stands out from the
    /// rest, which are in the date's softer black. Folded and finished, "Midday" alone:
    /// the taken time beside it says more than the planned one, and both fit on one line.
    private var title: some View {
        let period = DayPeriod(slot.time)
        let colour = slot.status == .now ? Palette.textPrimary : Palette.textSubtitle
        let words = summary != nil ? period.name : "\(period.name) · \(slot.scheduled.shortTime)"
        return Label {
            Text(words)
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
            nowCapsule
        case .next:
            Text("Next")
                .font(.headline)
                .foregroundStyle(Palette.textTertiary)
        case .later:
            EmptyView()
        case .notTakenYet:
            Text("Not taken yet")
                .font(.headline)
                .foregroundStyle(Palette.late)
        case .done:
            if let summary { summaryLabel(summary) }
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

#if DEBUG
/// For the canvas: the sample morning medications at 8 AM today, in each state.
private enum SlotPreview {
    static func slot(_ status: DoseSlot.Status, taken: Bool = false) -> DoseSlot {
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        let medications = SampleMedications.demoList.map(\.medication).filter { $0.doseTimes.contains(DoseTime(8)) }.prefix(2)
        let items = medications.enumerated().map { index, medication in
            ScheduledDose(dose: Dose(medication: medication, time: DoseTime(8), day: morning),
                          state: taken ? .taken(at: morning.addingTimeInterval(Double(index + 2) * 60), scannedAt: nil) : .pending)
        }
        return DoseSlot(time: DoseTime(8), scheduled: morning, items: Array(items), status: status)
    }
}

#Preview("Now, then taken") {
    let now = Calendar.current.date(bySettingHour: 8, minute: 3, second: 0, of: Date()) ?? Date()
    ScrollView {
        VStack(spacing: 16) {
            DoseSlotCard(slot: SlotPreview.slot(.now), isExpanded: .constant(true), onOpened: {})
            DoseSlotCard(slot: SlotPreview.slot(.done(at: now), taken: true), isExpanded: .constant(true), onOpened: {})
            DoseSlotCard(slot: SlotPreview.slot(.next), isExpanded: .constant(false), onOpened: {})
        }
        .padding()
    }
}
#endif
