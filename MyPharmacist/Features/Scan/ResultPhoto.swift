//
//  ResultPhoto.swift
//  MyPharmacist
//

import SwiftUI

/// The photo at the top of the results page, cropped to where the pills are, with each
/// pill ringed in its level's colour and marked with the same symbol as its section: so
/// "put back the ones ringed in red" works by looking at the photo alone, and two pills
/// that look alike can still be told apart. No numbers to match up.
struct ResultPhoto: View {
    let photo: CGImage
    let pills: [ScannedPill]
    /// The pill whose row was tapped: its ring stands out and the others step back.
    var highlighted: Int?

    static let height: CGFloat = 170

    var body: some View {
        GeometryReader { proxy in
            let region = PhotoFraming.region(
                around: pills.map(\.box),
                imageSize: CGSize(width: photo.width, height: photo.height),
                aspect: proxy.size.width / max(proxy.size.height, 1)
            )
            if let cropped = photo.cropping(to: region.integral) {
                Image(decorative: cropped, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        GeometryReader { shown in
                            ForEach(pills) { pill in
                                ring(pill, region: region, shownSize: shown.size)
                            }
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .frame(height: Self.height)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: highlighted)
        // The rows below say the same in words.
        .accessibilityHidden(true)
    }

    private func ring(_ pill: ScannedPill, region: CGRect, shownSize: CGSize) -> some View {
        let level = pill.verdict.level
        let rect = PhotoFraming.shown(pill.box, imageSize: CGSize(width: photo.width, height: photo.height),
                                      region: region, shownWidth: shownSize.width)
            .insetBy(dx: -6, dy: -6)
        let isHighlighted = highlighted == pill.id
        return Capsule()
            .strokeBorder(level.color, lineWidth: isHighlighted ? 5 : 3)
            .background(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: isHighlighted ? 7 : 5))
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: .topTrailing) {
                Image(systemName: level.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(level.color)
                    .background(Circle().fill(.white).padding(1))
                    .offset(x: 6, y: -6)
            }
            .position(x: rect.midX, y: rect.midY)
            .opacity(highlighted == nil || isHighlighted ? 1 : 0.3)
    }
}
