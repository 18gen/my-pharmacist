//
//  GlassIconButton.swift
//  MyPharmacist
//

import SwiftUI

/// A round glass button with one symbol, like the home screen's medications button and
/// the back button. 56pt across — larger than the system's 44pt so it is easier to see and tap.
struct GlassIconButton: View {
    static let size: CGFloat = 56

    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: Self.size, height: Self.size)
                .modifier(GlassButtonBackground(shape: Circle()))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
