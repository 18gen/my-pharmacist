//
//  MedicationsPage.swift
//  MyPharmacist
//

import SwiftUI

/// "My Medications": every medication on the list with what it's for and when it's taken.
/// Tapping one opens its page to change it or remove it. Under the list, "Add a
/// medication" has its two ways: "Scan card" adds one from the code on its keychain card,
/// and "Type it in" opens an empty page. Opened from Home's "My Medications" button;
/// slides in from the right. A large round "‹" button (or a swipe from the left edge)
/// goes back.
struct MedicationsPage: View {
    let store: MedicationStore
    /// Opens the camera for a keychain card's code.
    var onScanCard: () -> Void = {}
    /// Opens an empty medication page.
    var onTypeIn: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassIconButton(systemName: "chevron.left", accessibilityLabel: "Back") {
                    dismiss()
                }

                Text("My Medications")
                    .font(Palette.pageTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                list

                VStack(alignment: .leading, spacing: 12) {
                    Text("Add a medication")
                        .font(.title2.bold())
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    AddMedicationButtons(onScanCard: onScanCard, onTypeIn: onTypeIn)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        // The system back button can't be enlarged, so this page draws its own header.
        .toolbar(.hidden, for: .navigationBar)
        .edgeSwipeBack()
    }

    @ViewBuilder
    private var list: some View {
        if store.medications.isEmpty {
            Text("No medications yet. Add yours with photos of each pill, so a scan can recognize them.")
                .font(.body)
                .foregroundStyle(Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .cardBackground()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(store.medications.enumerated()), id: \.element.id) { index, medication in
                    if index > 0 { Divider() }
                    // Its page is declared in `RootView`, with every other pushed page.
                    NavigationLink(value: AppRoute.medication(id: medication.id)) {
                        MedicationRow(medication: medication, opensPage: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens it to change or remove")
                }
            }
            .cardBackground()
        }
    }
}

#Preview {
    NavigationStack {
        MedicationsPage(store: MedicationStore(entries: SampleMedications.demoList, storage: InMemoryDoseLogStorage()))
    }
}
