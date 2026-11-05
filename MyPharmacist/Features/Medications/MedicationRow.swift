//
//  MedicationRow.swift
//  MyPharmacist
//

import SwiftUI

/// One medication on the "My Medications" page: picture, name, strength and what it's
/// for, and its daily times or, for one taken only when needed, when that is.
struct MedicationRow: View {
    let medication: Medication
    /// The row opens a page, so it shows a chevron.
    var opensPage = false
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
                Text([medication.strength, medication.purpose].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                if let asNeeded = medication.asNeeded {
                    // The same caution sign its pill gets in scan results.
                    Label(asNeeded, systemImage: "exclamationmark.triangle.fill")
                        .font(.body)
                        .foregroundStyle(Palette.caution)
                } else {
                    Label(timesText, systemImage: "clock")
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if opensPage {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 12)
        // The whole row is the tap target, not just its text and picture.
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var timesText: String {
        medication.doseTimes.sorted()
            .map { $0.date(on: Date()).shortTime }
            .joined(separator: " · ")
    }
}
