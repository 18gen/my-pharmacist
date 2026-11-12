//
//  SecondaryButton.swift
//  MyPharmacist
//

import SwiftUI

/// The second choice beside a `WideButton`, such as Close or Cancel: grey, the same
/// height, and only as wide as its word, so the main button keeps most of the row.
/// Two of them can also share a row equally (`fillsWidth`).
struct SecondaryButton: View {
    let title: String
    /// As wide as the space it is given, rather than as its word; the word shrinks a
    /// little before it is cut off.
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(fillsWidth ? 0.7 : 1)
                .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 34)
                .padding(.horizontal, fillsWidth ? 0 : 6)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Palette.textMuted)
        .fixedSize(horizontal: !fillsWidth, vertical: true)
    }
}
