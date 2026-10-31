//
//  ScanOutcomeBanner.swift
//  MyPharmacist
//

import SwiftUI

/// Tells the person what their scan did: checked a dose, warned about a double dose,
/// too early, or not one of their medications.
struct ScanOutcomeBanner: View {
    let outcome: ScanOutcome
    let onUndo: () -> Void

    var body: some View {
        let content = outcome.presentation
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: content.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(content.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(content.message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            if case .checked = outcome {
                Button("Undo", action: onUndo)
                    .font(.headline)
                    .buttonStyle(.bordered)
                    .tint(Palette.textPrimary)
                    .accessibilityHint("Marks this dose as not taken")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        )
    }
}
