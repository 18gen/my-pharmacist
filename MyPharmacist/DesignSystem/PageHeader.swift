//
//  PageHeader.swift
//  MyPharmacist
//

import SwiftUI

/// The top of a page pushed over Home: the round back button over the page's title. The
/// system's back button can't be enlarged, so these pages hide the navigation bar and
/// draw this instead (with `edgeSwipeBack` for the swipe).
struct PageHeader: View {
    let title: String
    /// What VoiceOver calls the back button: "Back", or "Cancel" where going back drops
    /// what was being made.
    var backLabel = "Back"
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassIconButton(systemName: "chevron.left", accessibilityLabel: backLabel, action: onBack)
            Text(title)
                .font(Palette.pageTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }
}
