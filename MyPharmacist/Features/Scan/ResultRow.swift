//
//  ResultRow.swift
//  MyPharmacist
//

import SwiftUI

/// One line of the results page: the pill as it looked in the photo (or, for a missing
/// dose, its reference picture), its name, and one short reason. Tinted and outlined in
/// its level's colour; the section heading above says what to do with it.
struct ResultRow: View {
    let line: ResultLine
    /// Picked out in the photo above.
    var isHighlighted = false

    @ScaledMetric(relativeTo: .title3) private var pictureSize: CGFloat = 64
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let level = line.level
        HStack(spacing: 14) {
            // At accessibility text sizes the picture gives its room to the words.
            if !typeSize.isAccessibilitySize {
                picture
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(line.reason)
                    .font(.body)
                    .foregroundStyle(Palette.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(level.fill))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(level.color, lineWidth: isHighlighted ? 4 : 2))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.title)
        .accessibilityValue("\(level.title). \(line.reason)")
    }

    @ViewBuilder
    private var picture: some View {
        switch line {
        case .pill(let pill):
            Image(decorative: pill.crop, scale: 1)
                .resizable()
                .scaledToFit()
                .padding(6)
                .frame(width: pictureSize, height: pictureSize)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.85)))
        case .missing(let dose):
            PillImage(medication: dose.medication, size: pictureSize)
        }
    }
}
