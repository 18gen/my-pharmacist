//
//  HomeView.swift
//  MyPharmacist
//

import SwiftUI

/// Home screen content above the scan button: date and time with the "My Medications"
/// button, then one card per time of day ("Morning · 8:00 AM"), earliest first, and the
/// medications taken only when needed. The header stays put; the cards scroll beneath it.
struct HomeView: View {
    let store: MedicationStore
    /// Opens the "My Medications" page.
    let onShowMedications: () -> Void

    private static let fadeHeight: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Done times of day the person has opened.
    @State private var openDoneSlots: Set<DoseTime> = []

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
                                DoseSlotCard(slot: slot, isExpanded: isOpen(slot.time),
                                             onOpened: { scrollIntoView(slot.id, proxy) })
                                    .id(slot.id)
                            }
                            if !asNeeded.isEmpty {
                                WhenNeededCard(medications: asNeeded)
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

    private func isOpen(_ time: DoseTime) -> Binding<Bool> {
        Binding(
            get: { openDoneSlots.contains(time) },
            set: { open in
                if open { openDoneSlots.insert(time) } else { openDoneSlots.remove(time) }
            }
        )
    }

    /// Scrolls just enough to show the whole of a card that has just opened; closing a
    /// card leaves the scroll position alone.
    private func scrollIntoView(_ id: DoseTime, _ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
            proxy.scrollTo(id, anchor: nil)
        }
    }
}
