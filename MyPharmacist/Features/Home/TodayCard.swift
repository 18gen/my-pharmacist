//
//  TodayCard.swift
//  MyPharmacist
//

import SwiftUI

/// Today's doses still to take, then taken doses folded into a "Taken" toggle so the
/// list only shows what is left. Tapping a row checks or unchecks it.
struct TodayCard: View {
    let store: MedicationStore
    let now: Date
    @State private var doseToUncheck: Dose?
    @State private var showsTaken = false

    var body: some View {
        let items = store.todayList(now: now)
        let takenCount = items.filter { $0.state.isTaken }.count
        let allDone = !items.isEmpty && !items.contains { $0.state.isPending }

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
                } else if !items.isEmpty {
                    Text("\(takenCount) of \(items.count) taken")
                        .font(.headline)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .accessibilityElement(children: .combine)

            if items.isEmpty {
                Text("No medications scheduled today.")
                    .font(.body)
                    .foregroundStyle(Palette.textTertiary)
            } else {
                // Plain list when it fits; scrolls when it doesn't.
                ViewThatFits(in: .vertical) {
                    rows(items)
                    ScrollView { rows(items) }
                        .scrollIndicators(.visible)
                }
            }
        }
        .cardBackground()
        .animation(.spring(duration: 0.45), value: items)
        .animation(.spring(duration: 0.4), value: showsTaken)
        .sensoryFeedback(.impact(weight: .light), trigger: takenCount)
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

    @ViewBuilder
    private func rows(_ items: [ScheduledDose]) -> some View {
        let toTake = items.filter { !$0.state.isTaken }
        let taken = items.filter { $0.state.isTaken }

        VStack(alignment: .leading, spacing: 0) {
            doseRows(toTake)

            if !taken.isEmpty {
                // With nothing left to take, the header's "All done" says it already.
                TakenDosesToggle(doses: taken.map(\.dose), isExpanded: $showsTaken)
                    .padding(.top, toTake.isEmpty ? 0 : 10)
                if showsTaken {
                    doseRows(taken)
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func doseRows(_ items: [ScheduledDose]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            if index > 0 {
                Divider()
            }
            DoseRow(dose: item.dose, state: item.state, now: now) {
                if item.state.isTaken {
                    // Unchecking could lead to a second dose, so ask first.
                    doseToUncheck = item.dose
                } else {
                    store.markTaken(item.dose)
                }
            }
        }
    }
}
