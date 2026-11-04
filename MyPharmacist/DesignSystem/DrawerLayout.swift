//
//  DrawerLayout.swift
//  MyPharmacist
//

import SwiftUI

/// Shows the top part of one view: all of it when `openFraction` is 1, none of it at 0.
/// The view keeps its full height and stays put, so clipping this layout makes it open
/// and close like a drawer, with nothing sliding or fading.
///
/// Animating `openFraction` re-runs this layout on every frame, so whatever contains it
/// (the card, the scrolling page) resizes smoothly along with it. A plain frame change
/// would hand the page its final size at once, and a page scrolled to the end would jump
/// when the drawer closes.
struct DrawerLayout: Layout {
    /// 0 closed … 1 open.
    var openFraction: CGFloat

    var animatableData: CGFloat {
        get { openFraction }
        set { openFraction = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let full = fullSize(width: proposal.width, of: subviews)
        return CGSize(width: proposal.width ?? full.width, height: full.height * openFraction)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let full = fullSize(width: bounds.width, of: subviews)
        for subview in subviews {
            subview.place(at: bounds.origin, anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: full.height))
        }
    }

    /// The view's own height at this width, as tall as it wants to be.
    private func fullSize(width: CGFloat?, of subviews: Subviews) -> CGSize {
        subviews.first?.sizeThatFits(ProposedViewSize(width: width, height: nil)) ?? .zero
    }
}
