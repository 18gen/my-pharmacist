//
//  WhenNeededCard.swift
//  MyPharmacist
//

import SwiftUI

/// Medications taken only when needed, below the day's times: they belong to no time of
/// day, but it helps to remember they're there, and when they're for.
struct WhenNeededCard: View {
    let medications: [Medication]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("When needed")
                    .font(.title3.bold())
                    .foregroundStyle(Palette.textPrimary)
            } icon: {
                Image(systemName: "cross.case.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.textSecondary)
            }
            .accessibilityAddTraits(.isHeader)

            MedicationLineList(items: medications.map { ($0, false) })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
