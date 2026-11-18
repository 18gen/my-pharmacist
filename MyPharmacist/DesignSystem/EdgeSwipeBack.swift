//
//  EdgeSwipeBack.swift
//  MyPharmacist
//

import SwiftUI

extension View {
    /// Hiding the system navigation bar also turns off its swipe-back, so pages that draw
    /// their own header use this: a swipe right from the left edge goes back.
    /// - Parameter action: What going back does; dismissing the page unless given, for a
    ///   page that has something to do on its way out.
    func edgeSwipeBack(perform action: (() -> Void)? = nil) -> some View {
        modifier(EdgeSwipeBack(action: action))
    }
}

private struct EdgeSwipeBack: ViewModifier {
    let action: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    /// As wide as the page's side margin, so it never covers the back button beside it.
    private static let width: CGFloat = 16

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Color.clear
                .frame(width: Self.width)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width > 80 { (action ?? { dismiss() })() }
                        }
                )
                .accessibilityHidden(true)
        }
    }
}
