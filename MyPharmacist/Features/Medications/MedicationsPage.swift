//
//  MedicationsPage.swift
//  MyPharmacist
//

import SwiftUI

/// "My Medications": every medication on the list with what it's for and when it's taken.
/// Tapping one opens its page to change it or remove it; "Add a medication" opens an
/// empty one, and "Scan a card" adds one from the code on its keychain card. Opened from Home's "My Medications" button; slides in from the right. A large round "‹" button (or a swipe from the
/// left edge) goes back.
struct MedicationsPage: View {
    let store: MedicationStore
    /// Opens the camera for a keychain card's code.
    var onScanCard: () -> Void = {}
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

                addButton
                // A keychain card adds its medication, pictures and times in one scan.
                SecondaryButton(title: "Scan a card", fillsWidth: true, action: onScanCard)
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

    /// Its page is declared in `RootView`, with every other pushed page.
    private var addButton: some View {
        NavigationLink(value: AppRoute.newMedication) {
            Label("Add a medication", systemImage: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.onButton)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Palette.button)
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
