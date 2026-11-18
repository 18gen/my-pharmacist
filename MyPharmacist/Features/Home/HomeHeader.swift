//
//  HomeHeader.swift
//  MyPharmacist
//

import SwiftUI

/// Today's date over the large clock, with the round "Pharmacy" button beside them: a
/// cream circle with a storefront and the word under it, so it reads as a button on the photo.
/// Home puts them on a dimmed photo, so the words are cream. At the accessibility text
/// sizes the button goes under the clock, with its word beside the circle.
struct HomeHeader: View {
    let now: Date
    let onShowPharmacy: () -> Void
    /// The time is the largest thing on screen; it still grows with the text-size setting.
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 48
    /// Tap the time to switch between "6:33 AM" and "06:33"; remembered between launches.
    @AppStorage("use24HourClock") private var use24Hour = false
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Larger than the system's 44pt, like the app's other round buttons.
    private static let circle: CGFloat = 56

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    dateAndTime
                    pharmacyButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 8) {
                    dateAndTime
                    Spacer(minLength: 8)
                    pharmacyButton
                }
            }
        }
        .padding(.horizontal, 16)
        // A little below the card's middle: more room above than below.
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    /// Like the Lock Screen: the date above, the time large below it.
    private var dateAndTime: some View {
        VStack(alignment: .leading, spacing: 0) {
            fullDate
            timeText
        }
        .accessibilityElement(children: .combine)
    }

    /// "Wednesday, Nov 18": the month is short so the date fits on one line beside the
    /// Pharmacy button ("Nov." or "Nov" as the phone's region writes it). VoiceOver reads
    /// the month in full. At the accessibility sizes it may take two lines rather than shrink.
    private var fullDate: some View {
        Text(now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
            .font(.title3.weight(.semibold))
            .foregroundStyle(Palette.cream.opacity(0.92))
            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
    }

    private var timeText: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { use24Hour.toggle() }
        } label: {
            Text(now.clockText(use24Hour: use24Hour))
                .font(Palette.largeTitle(size: timeSize))
                .monospacedDigit()
                .foregroundStyle(Palette.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // A quick cross-fade between "6:33 AM" and "06:33".
                .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: use24Hour)
        .accessibilityHint(use24Hour ? "Double tap to show AM and PM" : "Double tap to show 24-hour time")
    }

    /// A storefront and the word: an icon alone would have to be guessed. Opens the pharmacy's
    /// card; it doesn't call by itself.
    private var pharmacyButton: some View {
        Button(action: onShowPharmacy) {
            let stacked = !typeSize.isAccessibilitySize
            let layout = stacked ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Palette.espresso)
                    .frame(width: Self.circle, height: Self.circle)
                    .background(Circle().fill(Palette.cream))
                Text("Pharmacy")
                    .font(stacked ? .footnote.weight(.semibold) : .body.weight(.semibold))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("My pharmacy")
        .accessibilityHint("Shows its phone number and opening hours")
    }
}
