//
//  AboutPage.swift
//  MyPharmacist
//

import SwiftUI

/// "About & privacy": what the app does and doesn't do, the switch for sending pill
/// pictures to be checked, what sharing with the pharmacy demo sends, the privacy policy
/// and support links, and, for demos, "Reset demo" (with or without a sample week) and
/// "Reset intro".
struct AboutPage: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isConfirmingDemoReset = false
    @AppStorage(PillCheckConsent.key) private var allowsChecking = false

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
                PageHeader(title: "About & privacy", onBack: { dismiss() })

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
                    Text("Your medication list, its photos, when you took your doses and what your scans said are kept on this phone, and in its backups. Deleting a medication deletes its photos; deleting the app deletes everything. Your pharmacy's address is sent to Apple to show it on a map, and its name and address to Google if you open it in Google Maps.")
                }

                if model.share.isAvailable {
                    section("Sharing with the pharmacy demo") {
                        Text(sharingState)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("Off unless you turn it on in My pharmacy. While on, the name you give, your medications and their times, when you took each dose in the last 7 days, and what each scan said are sent to the pharmacy demo's server and shown on its dashboard, which may be shown to an audience. Photos never are. Stopping sharing deletes them; so does a reset of the demo, or 14 days without updates. The pharmacy isn't alerted about anything.")
                    }
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
                    // For starting a demo over, in one press: the sample medications, no
                    // dose taken, and the sample pharmacy.
                    SecondaryButton(title: "Reset demo", fillsWidth: true) {
                        isConfirmingDemoReset = true
                    }
                    // For showing the introduction again, as on a first launch: only
                    // that it was seen is forgotten. It fades in over this page at once.
                    SecondaryButton(title: "Reset intro", fillsWidth: true) {
                        Onboarding.reset()
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
        .confirmationDialog("Reset the demo?", isPresented: $isConfirmingDemoReset, titleVisibility: .visible) {
            Button("With a sample week", role: .destructive) {
                withAnimation { model.resetDemo(sampleWeek: true) }
            }
            Button("With no doses taken", role: .destructive) {
                withAnimation { model.resetDemo(sampleWeek: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your list becomes the sample medications and My pharmacy the sample pharmacy. Your own medications and their photos are deleted. A sample week also fills in the last 6 days and moves the times so a dose is due now. If you're sharing, the pharmacy demo sees the reset.")
        }
        .toolbar(.hidden, for: .navigationBar)
        .edgeSwipeBack()
    }

    /// "On, as Maria." or "Off."
    private var sharingState: String {
        if let session = model.share.session { return "On, as \(session.name)." }
        return model.share.stoppedByDemo ? "Off: the pharmacy demo was reset." : "Off."
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

#if DEBUG
#Preview {
    NavigationStack {
        AboutPage(model: AppModel(store: MedicationStore(entries: SampleMedications.demoList),
                                  pharmacy: PharmacyStore(pharmacy: .sample()),
                                  share: PharmacyShare(demo: DemoPharmacy())))
    }
}
#endif
