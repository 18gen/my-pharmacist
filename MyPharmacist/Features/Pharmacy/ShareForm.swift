//
//  ShareForm.swift
//  MyPharmacist
//

import SwiftUI

/// Before sharing starts: the name the pharmacy sees, and plainly what is sent and what
/// never is, how long it is kept, and that the pharmacy isn't alerted. "Start sharing" and
/// "Cancel" are the sheet's buttons.
struct ShareForm: View {
    @Binding var name: String
    /// Why the last try didn't work.
    let failure: ShareFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                LabeledField("Your name", text: $name, prompt: "First name or nickname", capitalization: .words,
                             autocorrects: false)
                Text("Shown on the pharmacy's demo screen, which may be shown to an audience. A first name or nickname is enough.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
            .onChange(of: name) { _, typed in
                if typed.count > PharmacyShare.nameLength { name = String(typed.prefix(PharmacyShare.nameLength)) }
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("The pharmacy demo sees")
                point("checkmark", Palette.ok, "The name above")
                point("checkmark", Palette.ok, "Your medications and their times")
                point("checkmark", Palette.ok, "When you took each dose, for the last 7 days")
                point("checkmark", Palette.ok, "What each scan said, like \u{201C}Don't take now\u{201D}")
                point("checkmark", Palette.ok, "The pictures of the pills you scan")
                sectionTitle("It never gets")
                    .padding(.top, 6)
                point("xmark", Palette.danger, "Your medications' own photos, your location, or anything else on this phone")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()

            VStack(alignment: .leading, spacing: 8) {
                Text("Kept until you stop sharing, the demo is reset, or 14 days pass with nothing new.")
                Text("The pharmacy isn't alerted. If you're unsure about a dose, call them.")
            }
            .font(.body)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            if let failure {
                Text(failure.startMessage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func point(_ symbol: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundStyle(Palette.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
