//
//  GlassButtonBackground.swift
//  MyPharmacist
//

import SwiftUI

/// The Liquid Glass look iOS uses for bar buttons (like the back button) on iOS 26 and
/// later; a plain grey fill on earlier versions.
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
                .background(shape.fill(Palette.glassFallbackFill))
        }
    }
}
