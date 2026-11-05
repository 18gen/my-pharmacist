//
//  WideButton.swift
//  MyPharmacist
//

import SwiftUI

/// A page's main button: full width, large, black like the camera button.
struct WideButton: View {
    let title: String
    let systemImage: String
    var tint: Color = Palette.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(tint)
    }
}
