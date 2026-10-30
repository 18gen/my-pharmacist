//
//  EdgeSwipeBack.swift
//  MedLens
//

import SwiftUI

extension View {
    /// Hiding the system navigation bar also turns off its swipe-back, so pages that draw
    /// their own header use this: a swipe right from the left edge dismisses the page.
    func edgeSwipeBack() -> some View {
        modifier(EdgeSwipeBack())
    }
}

private struct EdgeSwipeBack: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Color.clear
                .frame(width: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width > 80 { dismiss() }
                        }
                )
                .accessibilityHidden(true)
        }
    }
}
