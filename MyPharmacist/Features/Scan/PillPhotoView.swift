//
//  PillPhotoView.swift
//  MyPharmacist
//

import SwiftUI

/// The photo that was checked, with each pill outlined in its verdict's colour and
/// numbered to match the list below it.
struct PillPhotoView: View {
    let photo: CGImage
    let pills: [ScannedPill]

    var body: some View {
        Image(decorative: photo, scale: 1)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    ForEach(pills) { pill in
                        outline(pill, in: proxy.size)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityHidden(true)
    }

    private func outline(_ pill: ScannedPill, in size: CGSize) -> some View {
        let color = pill.verdict.presentation.color
        let rect = CGRect(x: pill.box.minX * size.width, y: pill.box.minY * size.height,
                          width: pill.box.width * size.width, height: pill.box.height * size.height)
            .insetBy(dx: -5, dy: -5)
        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(color, lineWidth: 3)
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: .topLeading) {
                PillNumber(number: pill.id, color: color)
                    .offset(x: -10, y: -10)
            }
            .position(x: rect.midX, y: rect.midY)
    }
}

/// The number badge that links a pill on the photo to its row in the list.
struct PillNumber: View {
    let number: Int
    let color: Color

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(color))
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
    }
}
