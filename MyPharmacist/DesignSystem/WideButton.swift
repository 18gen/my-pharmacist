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
                // At the largest text sizes, smaller words rather than cut-off ones.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(tint)
    }
}
