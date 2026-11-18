//
//  TodayRow.swift
//  MyPharmacist
//

import SwiftUI

/// "Today" over the time-of-day cards, saying what they are, with the "Pills" button
/// beside it: the way to every medication, not only today's. It stays put while the
/// cards scroll under it. At the accessibility text sizes the button goes under the word.
///
/// The button must not read as a second tab beside "Today", or as another card:
/// - it is raised, white with a thin edge and a soft shadow, where the cards are flat beige;
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
                .font(.title.bold())
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
        .buttonStyle(RaisedButtonStyle())
        .fixedSize()
        .accessibilityLabel("Pills")
        .accessibilityHint("Shows all your medications")
    }
}

/// White and lifted a little off the page, so it looks like something to press, and
/// pressed flat when touched.
private struct RaisedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()
        configuration.label
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .frame(minHeight: 48)
            .background(shape.fill(Palette.raisedFill))
            .overlay(shape.strokeBorder(Palette.raisedEdge, lineWidth: 1))
            .shadow(color: Palette.espresso.opacity(configuration.isPressed ? 0 : 0.10),
                    radius: 3, y: configuration.isPressed ? 0 : 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
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
