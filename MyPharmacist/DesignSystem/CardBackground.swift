//
//  CardBackground.swift
//  MyPharmacist
//

import SwiftUI

extension View {
    /// The app's flat beige rounded card, with its standard inner padding.
    func cardBackground() -> some View {
        padding(16)
            .background(RoundedRectangle(cornerRadius: Palette.cardCornerRadius, style: .continuous).fill(Palette.cardFill))
    }

    /// A card lifted off the page: white, with a thin warm edge and a soft shadow under
    /// it, so it reads as something to press. Home's cards, whose times of day open on a
    /// tap. The shadow is under the card only, not its words.
    func raisedCardBackground() -> some View {
        let shape = RoundedRectangle(cornerRadius: Palette.cardCornerRadius, style: .continuous)
        return padding(16)
            .background {
                shape.fill(Palette.raisedFill)
                    .shadow(color: Palette.espresso.opacity(0.10), radius: 3, y: 2)
                    .overlay(shape.strokeBorder(Palette.raisedEdge, lineWidth: 1))
            }
    }
}
