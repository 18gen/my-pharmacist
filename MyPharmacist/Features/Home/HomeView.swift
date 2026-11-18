//
//  HomeView.swift
//  MyPharmacist
//

import SwiftUI

/// Home screen content above the scan button: date and time with the "Pharmacy" button on
/// a card with the onboarding's photo behind them, "Today" with the "Pills" button, then
/// one card per time of day ("Morning · 8:00 AM"), earliest first, the medications taken
/// only when needed, and last the way to "About & privacy". Only the time of day due now
/// is open; the rest are folded, so what to take stands out. The header and "Today" stay
/// put and the cards scroll beneath them; at the accessibility text sizes "Today"
/// scrolls with the cards.
struct HomeView: View {
    let store: MedicationStore
    /// Opens the "Pills" page, the list of medications.
    let onShowMedications: () -> Void
    /// Opens the pharmacy's card.
    let onShowPharmacy: () -> Void
    /// Opens "About & privacy".
    let onShowAbout: () -> Void
    /// Opens the camera for a keychain card's code.
    var onScanCard: () -> Void = {}
    /// Opens an empty medication page.
    var onTypeIn: () -> Void = {}

    private static let fadeHeight: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// At the accessibility text sizes "Today" and its button scroll with the cards
    /// instead of staying put, which would leave little room for the cards.
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Folded times of day the person has opened, each with the status it was opened in:
    /// when a slot moves on (next → now → done) it goes back to how that status shows,
    /// except that a card open while its doses are ticked stays open once the last is.
    @State private var openSlots: Set<String> = []
    @State private var showsWhenNeeded = false
    /// Scroll target for the "When needed" card.
    private static let whenNeededID = "whenNeeded"

    var body: some View {
        // Redraw every minute so the clock and each time of day's status stay current.
        TimelineView(.everyMinute) { context in
            let slots = store.todaySlots(now: context.date)
            let asNeeded = store.asNeededMedications

            VStack(alignment: .leading, spacing: 16) {
                HomeHeader(now: context.date, onShowPharmacy: onShowPharmacy)
                    .background { headerPhoto }
                    .clipShape(RoundedRectangle(cornerRadius: Palette.cardCornerRadius, style: .continuous))
                    .padding(.horizontal, 16)

                if !typeSize.isAccessibilitySize {
                    TodayRow(onShowPills: onShowMedications)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if typeSize.isAccessibilitySize {
                                TodayRow(onShowPills: onShowMedications)
                                    .padding(.horizontal, -16)
                            }
                            if store.medications.isEmpty {
                                FirstStepsCard(onScanCard: onScanCard, onTypeIn: onTypeIn)
                            } else if slots.isEmpty {
                                Text("No medications scheduled today.")
                                    .font(.body)
                                    .foregroundStyle(Palette.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .raisedCardBackground()
                            }
                            ForEach(slots) { slot in
                                DoseSlotCard(slot: slot, onToggleTaken: toggleTaken, scanPhoto: store.scanPhoto(of:),
                                             isExpanded: isOpen(slot),
                                             onOpened: { scrollIntoView(slot.id, proxy) })
                                    .id(slot.id)
                                    // Ticking the last dose of the time of day to take now
                                    // leaves its card open: it doesn't fold away under the
                                    // finger. Marked open as done ahead of time, so it is
                                    // open from the first frame it is done in.
                                    .onChange(of: slot.status, initial: true) { _, new in
                                        if new == .now { openSlots.insert(openKey(slot, kind: "done")) }
                                    }
                            }
                            if !asNeeded.isEmpty {
                                WhenNeededCard(items: asNeeded.map { whenNeededItem($0, on: context.date) },
                                               isExpanded: $showsWhenNeeded,
                                               onOpened: { scrollIntoView(Self.whenNeededID, proxy) })
                                    .id(Self.whenNeededID)
                            }
                            // Last of all, with or without medications.
                            Button(action: onShowAbout) {
                                Label("About & privacy", systemImage: "info.circle")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Palette.textSecondary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        // Room to scroll the last card clear of the fade.
                        .padding(.bottom, Self.fadeHeight)
                        .animation(.spring(duration: 0.45), value: slots)
                    }
                    // Fade out above the "Scan Pills" button instead of cutting off sharply.
                    .mask {
                        VStack(spacing: 0) {
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: Self.fadeHeight)
                        }
                    }
                }
            }
        }
    }

    /// Ticks a dose, or, once the person has said so, takes the tick off: "Not taken"
    /// forgets its scan too, so the next scan of its pill says to take it.
    private func toggleTaken(_ item: ScheduledDose) {
        if item.state.takenAt == nil {
            store.markTaken([item.dose])
        } else {
            store.markNotTaken([item.dose])
        }
    }

    /// A medication taken only when needed, as on the day shown: ticking and unticking
    /// change that day's record, the one the box shows.
    private func whenNeededItem(_ medication: Medication, on day: Date) -> MedicationLineList.Item {
        let takenAt = store.asNeededTaken(of: medication, on: day)
        return MedicationLineList.Item(medication: medication, scannedAt: store.asNeededScan(of: medication, on: day),
                                       scanPhoto: store.asNeededScanPhoto(of: medication, on: day),
                                       takenAt: takenAt) {
            if takenAt == nil {
                store.markAsNeededTaken(medication, on: day)
            } else {
                store.markAsNeededNotTaken(medication, on: day)
            }
        }
    }

    /// Behind the date and clock: the onboarding's photo of pills being scanned, soft and
    /// dimmed so the cream words on it are easy to read. Home opens on the picture the
    /// onboarding ended with.
    private var headerPhoto: some View {
        Image("OnboardingScene")
            .resizable()
            .scaledToFill()
            // Closer on the hand and the phone, which a card this wide would otherwise
            // show only a strip of.
            .scaleEffect(1.5, anchor: UnitPoint(x: 0.5, y: 0.62))
            .blur(radius: 3)
            .overlay(LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.55)],
                                    startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
    }

    /// What a slot's open state is remembered by: its time and the kind of status it has,
    /// so a card done at 12:31 and again at 12:40 is the same open card.
    private func openKey(_ slot: DoseSlot, kind given: String? = nil) -> String {
        let kind: String
        if let given {
            kind = given
        } else if case .done = slot.status {
            kind = "done"
        } else {
            kind = "\(slot.status)"
        }
        return "\(slot.scheduled.timeIntervalSince1970) \(kind)"
    }

    /// Opening a card also keeps it open once it is done, so ticking its last dose doesn't
    /// fold it away; folding it forgets both.
    private func isOpen(_ slot: DoseSlot) -> Binding<Bool> {
        let key = openKey(slot)
        let doneKey = openKey(slot, kind: "done")
        return Binding(
            get: { openSlots.contains(key) },
            set: { open in
                if open {
                    openSlots.formUnion([key, doneKey])
                } else {
                    openSlots.subtract([key, doneKey])
                }
            }
        )
    }

    /// Scrolls just enough to show the whole of a card that has just opened; closing a
    /// card leaves the scroll position alone.
    private func scrollIntoView(_ id: some Hashable, _ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
            proxy.scrollTo(id, anchor: nil)
        }
    }
}

/// What a new person sees before adding any medication: what the app does and the one
/// thing to do first.
private struct FirstStepsCard: View {
    let onScanCard: () -> Void
    let onTypeIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add your medications")
                .font(.title2.bold())
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Scan the code on each medication's card, or type a medication in with a photo of its pill and when you take it. Then scan the pills in your hand before taking them, to check they're the right ones for now.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // The same two ways as on Pills.
            AddMedicationButtons(onScanCard: onScanCard, onTypeIn: onTypeIn)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .raisedCardBackground()
    }
}
