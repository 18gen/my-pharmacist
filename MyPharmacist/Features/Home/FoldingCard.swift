//
//  FoldingCard.swift
//  MyPharmacist
//

import SwiftUI

/// A card on Home that folds to its header line and opens on a tap, like a drawer: the
/// rows stay put and the card's edge moves. One that doesn't fold (the time of day to
/// take now) is always open, built the same way so that it can start folding without
/// being rebuilt under the finger.
struct FoldingCard<Header: View, Rows: View>: View {
    /// Whether it folds at all.
    let folds: Bool
    /// Whether a card that folds has been opened.
    @Binding var isExpanded: Bool
    /// Called once the card has finished opening, so the page can scroll to where the
    /// rows end up: a scroll started mid-animation aims at where they were.
    let onOpened: () -> Void
    @ViewBuilder let header: Header
    @ViewBuilder let rows: Rows

    var body: some View {
        let open = !folds || isExpanded
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                header.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(folds)
            .accessibilityAddTraits(.isHeader)
            .accessibilityRemoveTraits(folds ? [] : .isButton)
            .accessibilityHint(!folds ? "" : isExpanded ? "Double tap to hide these medications" : "Double tap to show these medications")

            DrawerLayout(openFraction: open ? 1 : 0) {
                rows.padding(.top, 8)
            }
            .clipped()
            .allowsHitTesting(open)
            .accessibilityHidden(!open)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .raisedCardBackground()
    }

    private func toggle() {
        withAnimation(.spring(duration: 0.4)) {
            isExpanded.toggle()
        } completion: {
            if isExpanded { onOpened() }
        }
    }
}

/// The arrow at the end of a folding card's header: down while folded, up while open.
struct FoldChevron: View {
    let isExpanded: Bool

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.textMuted)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .accessibilityHidden(true)
    }
}
