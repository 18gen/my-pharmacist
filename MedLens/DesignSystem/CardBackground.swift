//
//  CardBackground.swift
//  MedLens
//

import SwiftUI

extension View {
    /// The app's light grey rounded card, with its standard inner padding.
    func cardBackground() -> some View {
        padding(16)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.cardFill))
    }
}
