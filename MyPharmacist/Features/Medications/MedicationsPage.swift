//
//  MedicationsPage.swift
//  MyPharmacist
//

import SwiftUI

/// "My Medications": every registered medication with its strength and daily times.
/// Opened from the bottle button; slides in from the right. A large round "‹" button
/// (or a swipe from the left edge) goes back.
struct MedicationsPage: View {
    let medications: [Medication]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Same size and style as the medications button on the home screen.
                GlassIconButton(systemName: "chevron.left", accessibilityLabel: "Back") {
                    dismiss()
                }

                Text("My Medications")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(medications.enumerated()), id: \.element.id) { index, medication in
                        if index > 0 { Divider() }
                        MedicationRow(medication: medication)
                    }
                }
                .cardBackground()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Palette.background)
        // The system back button can't be enlarged, so this page draws its own header.
        .toolbar(.hidden, for: .navigationBar)
        .edgeSwipeBack()
    }
}

#Preview {
    NavigationStack {
        MedicationsPage(medications: SampleMedications.all)
    }
}
