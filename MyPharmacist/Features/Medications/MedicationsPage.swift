//
//  MedicationsPage.swift
//  MyPharmacist
//

import SwiftUI

/// "My Medications": every medication on the list with what it's for and when it's taken.
/// Tapping one opens its page to change the times or remove it; "Add a medication" picks
/// one from the catalog. Opened from the pills button; slides in from the right. A large
/// round "‹" button (or a swipe from the left edge) goes back.
struct MedicationsPage: View {
    let store: MedicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false
    @State private var isConfirmingRestore = false

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

                list

                WideButton(title: "Add a medication", systemImage: "plus") {
                    isAdding = true
                }
                .disabled(store.addable.isEmpty)
                if store.addable.isEmpty {
                    Text("Every medication the app knows is already on your list.")
                        .font(.body)
                        .foregroundStyle(Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }

                // For starting a demo over.
                Button("Restore the sample list") {
                    isConfirmingRestore = true
                }
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .sheet(isPresented: $isAdding) {
            AddMedicationSheet(store: store)
        }
        .confirmationDialog("Restore the sample list?", isPresented: $isConfirmingRestore, titleVisibility: .visible) {
            Button("Restore", role: .destructive) {
                withAnimation { store.restoreSampleList() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your list becomes capecitabine, dexamethasone, allopurinol and ondansetron at their sample times, replacing your changes.")
        }
        // The system back button can't be enlarged, so this page draws its own header.
        .toolbar(.hidden, for: .navigationBar)
        .edgeSwipeBack()
    }

    @ViewBuilder
    private var list: some View {
        if store.medications.isEmpty {
            Text("No medications yet. Add one below.")
                .font(.body)
                .foregroundStyle(Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    .accessibilityHint("Opens its times")
                }
            }
            .cardBackground()
        }
    }
}

/// "Add a medication": the catalog medications not on the list yet. Choosing one opens its
/// page to set the times before adding it.
struct AddMedicationSheet: View {
    let store: MedicationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        Text("Add a medication")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Palette.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 8)
                        GlassIconButton(systemName: "xmark", accessibilityLabel: "Cancel") {
                            dismiss()
                        }
                    }

                    if store.addable.isEmpty {
                        Text("Every medication the app knows is already on your list.")
                            .font(.body)
                            .foregroundStyle(Palette.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardBackground()
                    } else {
                        Text("Choose one. You can set its times next.")
                            .font(.body)
                            .foregroundStyle(Palette.textSecondary)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(store.addable.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 { Divider() }
                                NavigationLink(value: AppRoute.medication(id: entry.id)) {
                                    MedicationRow(medication: entry, opensPage: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .cardBackground()
                    }
                }
                .padding(16)
            }
            .background(Palette.background)
            // The sheet has a stack of its own, so the same route opens the page in its
            // "add" form here.
            .navigationDestination(for: AppRoute.self) { route in
                if case .medication(let id) = route, let entry = store.catalogEntry(id) {
                    MedicationEditor(store: store, entry: entry, mode: .add, onAdded: { dismiss() })
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    NavigationStack {
        MedicationsPage(store: MedicationStore(startingIDs: SampleMedications.startingIDs, storage: InMemoryDoseLogStorage()))
    }
}
