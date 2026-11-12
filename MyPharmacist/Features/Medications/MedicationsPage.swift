//
//  MedicationsPage.swift
//  MyPharmacist
//

import SwiftUI

/// "My Medications": every medication on the list with what it's for and when it's taken.
/// Tapping one opens its page to change it or remove it; "Add a medication" opens an
/// empty one, and "Sample" beside it loads the sample list, for demos. Opened from the
/// pills button; slides in from the right. A large round "‹" button (or a swipe from the
/// left edge) goes back.
struct MedicationsPage: View {
    let store: MedicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingSample = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Same size and style as the medications button on the home screen.
                GlassIconButton(systemName: "chevron.left", accessibilityLabel: "Back") {
                    dismiss()
                }

                Text("My Medications")
                    .font(Palette.pageTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                list

                // "Sample" takes three parts of the row to "Add a medication"'s seven. At
                // the accessibility text sizes two no longer fit in a row: the main
                // button first, then the other under it.
                if typeSize.isAccessibilitySize {
                    addButton
                    sampleButton
                } else {
                    SplitRow(shares: [3, 7]) {
                        sampleButton
                        addButton
                    }
                }

                NavigationLink(value: AppRoute.about) {
                    Label("About & privacy", systemImage: "info.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .confirmationDialog("Load the sample list?", isPresented: $isConfirmingSample, titleVisibility: .visible) {
            Button("Load sample list", role: .destructive) {
                withAnimation { store.loadSampleList() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your list becomes four sample medications with sample times, for trying the app. Your own medications and their photos are deleted.")
        }
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

    /// For trying the app, and for App Review, without one's own pills. One word, to fit
    /// its narrow part of the row; what it does is asked about before it is done.
    private var sampleButton: some View {
        SecondaryButton(title: "Sample", fillsWidth: true) {
            isConfirmingSample = true
        }
        .accessibilityLabel("Load sample list")
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
