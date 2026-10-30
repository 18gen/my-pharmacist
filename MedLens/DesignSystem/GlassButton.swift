//
//  GlassButton.swift
//  MedLens
//

import SwiftUI

enum GlassButton {
    /// Height of the app's glass buttons (the system uses 44pt).
    static let size: CGFloat = 56
}

/// The Liquid Glass look iOS uses for bar buttons (like the back button) on iOS 26 and
/// later; a plain grey fill on earlier versions. Buttons using it are 56pt tall — larger
/// than the system's 44pt so they are easier to see and tap.
struct GlassButtonBackground<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .contentShape(shape)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .contentShape(shape)
                .background(shape.fill(Color(white: 0.94)))
        }
    }
}
