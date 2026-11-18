//
//  TodayRow.swift
//  MyPharmacist
//

import SwiftUI

/// "Today" over the time-of-day cards, saying what they are, with the "Pills" button
/// beside it: the way to every medication, not only today's. It stays put while the
/// cards scroll under it. At the accessibility text sizes the button goes under the word.
///
/// The button sits back so the cards lead:
/// - it is flat beige with no edge or shadow, where the cards under it are white and raised;
/// - it ends in a chevron pointing right, the iPhone's sign for "opens a page", where the
///   cards' chevrons point down (they open in place);
/// - it stays quieter than the dark scan button, the one strong thing to press on Home.
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
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                // In line with the words inside the clock and the cards, which sit 16
                // points in from their edges; the button lines up with the edges.
                .padding(.leading, 12)
                .accessibilityAddTraits(.isHeader)
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            pillsButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    /// The app icon's tablet, the word, and a chevron.
    private var pillsButton: some View {
        Button(action: onShowPills) {
            HStack(spacing: 8) {
                TabletIcon(size: iconSize)
                Text("Pills")
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Palette.textMuted)
                    .padding(.leading, 2)
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(1)
        }
        .buttonStyle(FlatButtonStyle())
        .fixedSize()
        .accessibilityLabel("Pills")
        .accessibilityHint("Shows all your medications")
    }
}

/// The flat beige the cards used to have, with no edge or shadow; a shade darker while
/// pressed.
private struct FlatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()
        configuration.label
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .frame(minHeight: 48)
            .background(shape.fill(configuration.isPressed ? Palette.skeleton : Palette.cardFill))
            .contentShape(shape)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    TodayRow(onShowPills: {})
        .padding(.vertical)
        .background(Palette.background)
}
#endif
