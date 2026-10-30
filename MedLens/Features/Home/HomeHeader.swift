//
//  HomeHeader.swift
//  MedLens
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

            Button(action: onShowMedications) {
                Image(systemName: "cross.vial.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: GlassButton.size, height: GlassButton.size)
                    .modifier(GlassButtonBackground(shape: Circle()))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("My medications")
        }
    }

    private var dateText: some View {
        // Full words ("Wednesday, October 14") are easier to read than abbreviations.
        Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .font(.title2.weight(.semibold))
            .foregroundStyle(Color(white: 0.25))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }

    private var timeText: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { use24Hour.toggle() }
        } label: {
            Text(Self.clockText(now, use24Hour: use24Hour))
                .font(.system(size: timeSize, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // A quick cross-fade between "6:33 AM" and "06:33".
                .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: use24Hour)
        .accessibilityHint(use24Hour ? "Double tap to show AM and PM" : "Double tap to show 24-hour time")
    }

    /// "6:33 AM", or "06:33" / "18:33" in 24-hour time regardless of the phone's region.
    static func clockText(_ date: Date, use24Hour: Bool) -> String {
        guard use24Hour else { return date.formatted(date: .omitted, time: .shortened) }
        let style = Date.VerbatimFormatStyle(
            format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            timeZone: .current,
            calendar: .current
        )
        return date.formatted(style)
    }
}
