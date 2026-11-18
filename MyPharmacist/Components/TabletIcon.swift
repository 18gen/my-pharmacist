//
//  TabletIcon.swift
//  MyPharmacist
//

import SwiftUI

/// The tablet from the app icon, without the magnifying glass, in one colour: a round
/// tablet seen from a little above, tilted, with its edge below the face and a score line
/// across it. The gaps are cut out, so it takes the colour around it, like a symbol.
struct TabletIcon: View {
    /// The width of the drawing; it is about two thirds as tall.
    var size: CGFloat = 22

    var body: some View {
        let faceWidth = size * 0.9
        let faceHeight = size * 0.58
        // How far the edge shows below the face.
        let depth = size * 0.14
        ZStack {
            Ellipse()
                .frame(width: faceWidth, height: faceHeight)
                .offset(y: depth)
            // The gap between face and edge, then the face itself.
            Ellipse()
                .stroke(lineWidth: size * 0.08)
                .frame(width: faceWidth, height: faceHeight)
                .blendMode(.destinationOut)
            Ellipse()
                .frame(width: faceWidth, height: faceHeight)
            Capsule()
                .frame(width: faceWidth * 0.66, height: size * 0.1)
                .blendMode(.destinationOut)
        }
        .frame(width: faceWidth, height: faceHeight + depth, alignment: .top)
        .compositingGroup()
        .rotationEffect(.degrees(-15))
        .frame(width: size, height: size * 0.72)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 24) {
        TabletIcon(size: 22)
        TabletIcon(size: 44)
        TabletIcon(size: 120)
    }
    .foregroundStyle(Palette.textPrimary)
    .padding()
    .background(Palette.background)
}
#endif
