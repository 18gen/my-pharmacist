//
//  HomeView.swift
//  MyPharmacist
//

import SwiftUI

/// Home screen content above the scan button: date and time with the "My Medications"
/// button, then one card per time of day ("Morning · 8:00 AM"), earliest first, and the
/// medications taken only when needed. Only the time of day due now is open; the rest are
/// folded, so what to take stands out. The header stays put; the cards scroll beneath it.
struct HomeView: View {
    let store: MedicationStore
    /// Opens the "My Medications" page.
    let onShowMedications: () -> Void

    private static let fadeHeight: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Folded times of day the person has opened, each with the status it was opened in:
    /// when a slot moves on (next → now → scanned) it goes back to how that status shows.
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
                HomeHeader(now: context.date, onShowMedications: onShowMedications)
                    .padding(.horizontal, 16)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if slots.isEmpty {
                                Text("No medications scheduled today.")
                                    .font(.body)
                                    .foregroundStyle(Palette.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .cardBackground()
                            }
                            ForEach(slots) { slot in
                                DoseSlotCard(slot: slot, isExpanded: isOpen(slot),
                                             onOpened: { scrollIntoView(slot.id, proxy) })
                                    .id(slot.id)
                            }
                            if !asNeeded.isEmpty {
                                WhenNeededCard(medications: asNeeded, isExpanded: $showsWhenNeeded,
                                               onOpened: { scrollIntoView(Self.whenNeededID, proxy) })
                                    .id(Self.whenNeededID)
                            }
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

    private func isOpen(_ slot: DoseSlot) -> Binding<Bool> {
        let key = "\(slot.time.hour):\(slot.time.minute) \(slot.status)"
        return Binding(
            get: { openSlots.contains(key) },
            set: { open in
                if open { openSlots.insert(key) } else { openSlots.remove(key) }
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
