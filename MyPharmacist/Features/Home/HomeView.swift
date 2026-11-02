//
//  HomeView.swift
//  MyPharmacist
//

import SwiftUI

/// Home screen content above the scan button: date and time with the "My Medications"
/// button, then today's doses still to take and, in a card of its own, the taken ones.
/// The header stays put; the two cards scroll together beneath it.
struct HomeView: View {
    let store: MedicationStore
    /// Opens the "My Medications" page.
    let onShowMedications: () -> Void

    private static let fadeHeight: CGFloat = 24

    @State private var showsTaken = false
    @State private var doseToUncheck: Dose?

    var body: some View {
        // Redraw every minute so the clock and "in 2 hr" labels stay current.
        TimelineView(.everyMinute) { context in
            let items = store.todayList(now: context.date)
            let toTake = items.filter { !$0.state.isTaken }
            let taken = items.filter { $0.state.isTaken }

            VStack(alignment: .leading, spacing: 16) {
                HomeHeader(now: context.date, onShowMedications: onShowMedications)
                    .padding(.horizontal, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        TodayCard(toTake: toTake, totalCount: items.count, now: context.date) { item in
                            store.markTaken(item.dose)
                        }
                        if !taken.isEmpty {
                            TakenCard(taken: taken, now: context.date, isExpanded: $showsTaken) { item in
                                // Unchecking could lead to a second dose, so ask first.
                                doseToUncheck = item.dose
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    // Room to scroll the last card clear of the fade.
                    .padding(.bottom, Self.fadeHeight)
                    .animation(.spring(duration: 0.45), value: items)
                    .animation(.spring(duration: 0.4), value: showsTaken)
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
            .sensoryFeedback(.impact(weight: .light), trigger: taken.count)
        }
        .confirmationDialog(
            uncheckTitle,
            isPresented: Binding(get: { doseToUncheck != nil }, set: { if !$0 { doseToUncheck = nil } }),
            titleVisibility: .visible
        ) {
            Button("Mark as Not Taken", role: .destructive) {
                if let dose = doseToUncheck { store.markNotTaken(dose) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var uncheckTitle: String {
        guard let dose = doseToUncheck else { return "" }
        return "Mark \(dose.medication.displayName) (\(dose.scheduled.shortTime)) as not taken?"
    }
}
