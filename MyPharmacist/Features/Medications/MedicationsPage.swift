//
//  MedicationsPage.swift
//  MyPharmacist
//

import SwiftUI

/// "Pills": every medication on the list with what it's for and when it's taken.
/// Tapping one opens its page to change it or remove it. Under the list, "Add a
/// medication" has its two ways: "Scan" adds one from the code on its keychain card,
/// and "Type" opens an empty page. Opened from Home's "Pills" button;
/// slides in from the right. A large round "‹" button (or a swipe from the left edge)
/// goes back.
struct MedicationsPage: View {
    let store: MedicationStore
    /// Opens the camera for a keychain card's code.
    var onScanCard: () -> Void = {}
    /// Opens an empty medication page.
    var onTypeIn: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    /// Said where a medication would be added once the list holds as many as one check of
    /// pills can compare (`CheckLimits.medications`).
    static let listIsFull = "You can have up to \(CheckLimits.medications) medications. Remove one to add another."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(title: "Pills", onBack: { dismiss() })

                list

                VStack(alignment: .leading, spacing: 12) {
                    Text("Add a medication")
                        .font(.title2.bold())
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if store.canAddMore {
                        AddMedicationButtons(onScanCard: onScanCard, onTypeIn: onTypeIn)
                    } else {
                        Text(Self.listIsFull)
                            .font(.body)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

#if DEBUG
#Preview {
    NavigationStack {
        MedicationsPage(store: MedicationStore(entries: SampleMedications.demoList))
    }
}
#endif
