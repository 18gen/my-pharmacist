//
//  FoundPillsView.swift
//  MyPharmacist
//

import SwiftUI

/// Step 3 of a scan, while each pill is being checked: the photo with every pill that
/// was found outlined in white and numbered, so the person sees each one being cut out
/// before the verdicts arrive. Laid out like the results photo, which replaces it.
struct FoundPillsView: View {
    let photo: CGImage
    /// Normalized 0–1, origin at the top left, in reading order.
    let boxes: [CGRect]

    var body: some View {
        VStack(spacing: 16) {
            Image(decorative: photo, scale: 1)
                .resizable()
                .scaledToFit()
                .overlay {
                    GeometryReader { proxy in
                        ForEach(boxes.indices, id: \.self) { index in
                            outline(boxes[index], number: index + 1, in: proxy.size)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)

            ProgressView(boxes.count == 1 ? "Checking 1 pill…" : "Checking \(boxes.count) pills…")
                .tint(.white)
                .foregroundStyle(.white)
                .font(.headline)

            Spacer(minLength: 0)
        }
    }

    private func outline(_ box: CGRect, number: Int, in size: CGSize) -> some View {
        let rect = CGRect(x: box.minX * size.width, y: box.minY * size.height,
                          width: box.width * size.width, height: box.height * size.height)
            .insetBy(dx: -5, dy: -5)
        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(.white, lineWidth: 3)
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: .topLeading) {
                PillNumber(number: number, color: Palette.textMuted)
                    .offset(x: -10, y: -10)
            }
            .position(x: rect.midX, y: rect.midY)
    }
}
