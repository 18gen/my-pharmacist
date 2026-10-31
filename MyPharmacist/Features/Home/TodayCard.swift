//
//  TodayCard.swift
//  MyPharmacist
//

import SwiftUI

/// Today's doses: still to take first, then a "Taken" section. Tapping a row toggles it.
struct TodayCard: View {
    let store: MedicationStore
    let now: Date
    @State private var doseToUncheck: Dose?

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
        let firstTakenIndex = items.firstIndex { $0.state.isTaken }

        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index == firstTakenIndex {
                    sectionHeader("Taken", isFirst: index == 0)
                } else if index > 0 {
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
}

extension TodayCard {
    fileprivate func sectionHeader(_ title: String, isFirst: Bool) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.textMuted)
            .padding(.top, isFirst ? 0 : 14)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }
}
