//
//  ResultPhoto.swift
//  MyPharmacist
//

import SwiftUI

/// The photo at the top of the results page, cropped to where the pills are, with each
/// pill ringed in its level's colour and marked with the same symbol as its section: so
/// "put back the ones ringed in red" works by looking at the photo alone, and two pills
/// that look alike can still be told apart. No numbers to match up. While the pills are
/// being checked, each has a neutral ring (`PillRing`) in the same place.
struct ResultPhoto: View {
    /// One pill's ring: where the pill is, and its level once known.
    struct Ring: Identifiable, Equatable {
        /// The pill's number in reading order, the same as its `ScannedPill.id`.
        let id: Int
        /// Normalized 0–1, origin at the top left of the photo.
        let box: CGRect
        /// Nil while the pill is being checked.
        let level: ResultLevel?
    }

    let photo: CGImage
    let rings: [Ring]
    /// The pill whose row was tapped: its ring stands out and the others step back.
    var highlighted: Int?

    static let height: CGFloat = 170

    init(photo: CGImage, rings: [Ring], highlighted: Int? = nil) {
        self.photo = photo
        self.rings = rings
        self.highlighted = highlighted
    }

    var body: some View {
        FramedPillPhoto(photo: photo, boxes: rings.map(\.box)) { index, shown in
            ring(rings[index], shown: shown)
        }
        .frame(height: Self.height)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: highlighted)
        .animation(.easeInOut(duration: 0.3), value: rings)
        // The rows below say the same in words.
        .accessibilityHidden(true)
    }

    private func ring(_ ring: Ring, shown: CGRect) -> some View {
        let rect = shown.insetBy(dx: -6, dy: -6)
        let isHighlighted = highlighted == ring.id
        return ZStack {
            if let level = ring.level {
                Capsule()
                    .strokeBorder(level.color, lineWidth: isHighlighted ? 5 : 3)
                    .background(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: isHighlighted ? 7 : 5))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: level.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(level.color)
                            .background(Circle().fill(.white).padding(1))
                            .offset(x: 6, y: -6)
                    }
                    .transition(.opacity)
            } else {
                PillRing()
                    .transition(.opacity)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .opacity(highlighted == nil || isHighlighted ? 1 : 0.3)
    }
}
