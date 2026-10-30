//
//  PillImage.swift
//  MedLens
//

import SwiftUI

/// Placeholder medication picture: a coloured pill symbol on a soft tile.
struct PillImage: View {
    let medication: Medication
    var size: CGFloat = 48

    var body: some View {
        let color = Palette.tint(medication.tint)
        Image(systemName: medication.symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).fill(color.opacity(0.15)))
            .accessibilityHidden(true)
    }
}
