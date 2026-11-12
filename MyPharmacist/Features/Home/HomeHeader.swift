//
//  HomeHeader.swift
//  MyPharmacist
//

import SwiftUI

/// Today's date and the large clock, with the "My Medications" button beside them.
struct HomeHeader: View {
    let now: Date
    let onShowMedications: () -> Void
    /// The time is the largest thing on screen; it still grows with the text-size setting.
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 56
    /// Tap the time to switch between "6:33 AM" and "06:33"; remembered between launches.
    @AppStorage("use24HourClock") private var use24Hour = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Like the Lock Screen: the date above, the time large below it.
            VStack(alignment: .leading, spacing: 0) {
                dateText
                timeText
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            GlassIconButton(systemName: "pills.fill", accessibilityLabel: "My medications",
                            action: onShowMedications)
        }
    }

    private var dateText: some View {
        // Full words ("Wednesday, October 14") are easier to read than abbreviations.
        Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .font(.title2.weight(.semibold))
            .foregroundStyle(Palette.textSubtitle)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }

    private var timeText: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { use24Hour.toggle() }
        } label: {
            Text(now.clockText(use24Hour: use24Hour))
                .font(Palette.largeTitle(size: timeSize))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // A quick cross-fade between "6:33 AM" and "06:33".
                .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: use24Hour)
        .accessibilityHint(use24Hour ? "Double tap to show AM and PM" : "Double tap to show 24-hour time")
    }
}
