//
//  SecondaryButton.swift
//  MyPharmacist
//

import SwiftUI

/// The second choice beside a `WideButton`, such as Close or Cancel: grey, the same
/// height, and only as wide as its word, so the main button keeps most of the row.
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .frame(minHeight: 34)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Palette.textMuted)
        .fixedSize()
    }
}
