//
//  TodayRow.swift
//  MyPharmacist
//

import SwiftUI

/// "Today" over the time-of-day cards, saying what they are, with the "Pills" button
/// beside it: the way to every medication, not only today's. It stays put while the
/// cards scroll under it. A grey button, so the scan button stays the one strong thing
/// to press on Home. At the accessibility text sizes the button goes under the word.
struct TodayRow: View {
    /// Opens the list of medications.
    let onShowPills: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 24

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            Text("Today")
                .font(.system(.title, design: .serif, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            pillsButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    /// Like `SecondaryButton`, with the app icon's tablet before the word.
    private var pillsButton: some View {
        Button(action: onShowPills) {
            HStack(spacing: 8) {
                TabletIcon(size: iconSize)
                Text("Pills")
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(1)
            .frame(minHeight: 34)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Palette.textMuted)
        .fixedSize()
        .accessibilityLabel("Pills")
        .accessibilityHint("Shows all your medications")
    }
}

#if DEBUG
#Preview {
    TodayRow(onShowPills: {})
        .padding(.vertical)
        .background(Palette.background)
}
#endif
