//
//  AboutPage.swift
//  MyPharmacist
//

import SwiftUI

/// "About & privacy": what the app does and doesn't do, the switch for sending pill
/// pictures to be checked, the privacy policy and support links, and, for demos, "Reset
/// scans" and "Reset intro".
struct AboutPage: View {
    let store: MedicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isConfirmingScansReset = false
    @AppStorage(PillCheckConsent.key) private var allowsChecking = false
    /// Saying that the introduction will show again.
    @State private var didResetOnboarding = false

    private let server = PillCheckClient.Configuration.fromBundle()
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GlassIconButton(systemName: "chevron.left", accessibilityLabel: "Back") {
                    dismiss()
                }
                Text("About & privacy")
                    .font(Palette.pageTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                section("A double-check, not medical advice") {
                    Text("My Pharmacist checks the pills in your hand against your own medication list and your schedule, and says which to take now. It can be wrong. Always follow your pharmacist's or doctor's instructions, and ask them if you are unsure about a pill.")
                }

                section("Checking pills") {
                    Toggle(isOn: $allowsChecking) {
                        Text("Send pill pictures to be checked")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .tint(Palette.due)
                    Text("Pictures of the pills you scan, and your medications' names and pill photos, are sent to our server and OpenAI to recognize them. Our server keeps nothing; OpenAI may keep them up to 30 days to prevent abuse. Pills can't be checked while this is off.")
                }

                section("On this phone") {
                    Text("Your medication list, its photos and when you scanned your doses are kept only on this phone. Deleting a medication deletes its photos; deleting the app deletes everything.")
                }

                if let server {
                    VStack(alignment: .leading, spacing: 12) {
                        Link("Privacy policy", destination: server.privacyURL)
                        Link("Help and contact", destination: server.supportURL)
                    }
                    .font(.title3.weight(.semibold))
                }

                // Side by side, each half the row; one above the other at the
                // accessibility text sizes, where two no longer fit in a row.
                resetButtons {
                    // For starting a demo over: no dose shows as scanned any more.
                    SecondaryButton(title: "Reset scans", fillsWidth: true) {
                        isConfirmingScansReset = true
                    }
                    // For showing the introduction again, as on a first launch: only
                    // that it was seen is forgotten.
                    SecondaryButton(title: "Reset intro", fillsWidth: true) {
                        Onboarding.reset()
                        didResetOnboarding = true
                    }
                }

                Text(version)
                    .font(.footnote)
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .confirmationDialog("Reset all scans?", isPresented: $isConfirmingScansReset, titleVisibility: .visible) {
            Button("Reset scans", role: .destructive) {
                withAnimation { store.clearScans() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every dose goes back to not scanned. Your medications stay.")
        }
        .alert("Intro reset", isPresented: $didResetOnboarding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The introduction will show the next time you open the app. Your medications and scans are unchanged.")
        }
        .toolbar(.hidden, for: .navigationBar)
        .edgeSwipeBack()
    }

    private var resetButtons: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
                .font(.body)
                .foregroundStyle(Palette.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

#Preview {
    NavigationStack {
        AboutPage(store: MedicationStore(entries: SampleMedications.demoList, storage: InMemoryDoseLogStorage()))
    }
}
