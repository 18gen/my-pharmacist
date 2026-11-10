//
//  PillCheckConsent.swift
//  MyPharmacist
//

import SwiftUI

/// Whether the person allowed pill pictures to be sent to be checked. Asked before the
/// first scan; can be turned off on the About & privacy page. Saved on the device.
enum PillCheckConsent {
    /// The UserDefaults key, for `@AppStorage`.
    static let key = "pillCheckConsent.v1"
}

/// Asked before the first scan: what is sent, to whom, and what is kept, with the choice
/// to allow it or not. Without it, pills can't be checked.
struct PillCheckConsentSheet: View {
    let onAllow: () -> Void
    let onNotNow: () -> Void

    private let privacyURL = PillCheckClient.Configuration.fromBundle()?.privacyURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Palette.due)
                    .accessibilityHidden(true)
                Text("Before you check pills")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 14) {
                    point("photo.on.rectangle", "To recognize your pills, pictures of them and of your medications' pills, with their names, are sent to our server and to OpenAI.")
                    point("trash", "Our server keeps nothing. OpenAI may keep them up to 30 days to prevent abuse, then deletes them, and doesn't use them to train its models.")
                    point("iphone", "Your medication list and photos otherwise stay on this phone. The camera's full photo is never sent.")
                    point("person.crop.circle.badge.questionmark", "This is a double-check, not medical advice. Always follow your pharmacist's or doctor's instructions.")
                }
                if let privacyURL {
                    Link("Read the privacy policy", destination: privacyURL)
                        .font(.body.weight(.semibold))
                }
                Text("You can turn this off any time in My Medications › About & privacy.")
                    .font(.body)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 4) {
                    WideButton(title: "Allow and continue", systemImage: "checkmark", action: onAllow)
                    Button("Not now", action: onNotNow)
                        .font(.title3)
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Palette.background)
        .interactiveDismissDisabled()
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundStyle(Palette.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
