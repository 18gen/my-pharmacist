//
//  MedicationRow.swift
//  MedLens
//

import SwiftUI

/// One medication on the "My Medications" page: picture, name, strength and daily times.
struct MedicationRow: View {
    let medication: Medication
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 14) {
            // At accessibility text sizes the picture gives its room to the name.
            if !typeSize.isAccessibilitySize {
                PillImage(medication: medication, size: 56)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(medication.strength)
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                Label(timesText, systemImage: "clock")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var timesText: String {
        medication.doseTimes.sorted()
            .map { $0.date(on: Date()).shortTime }
            .joined(separator: " · ")
    }
}
