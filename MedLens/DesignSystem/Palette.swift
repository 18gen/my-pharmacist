//
//  Palette.swift
//  MedLens
//

import SwiftUI

/// Colours chosen to stay readable on the white screen and the light grey card.
/// Views use these names instead of raw greys so the whole app can be retuned in one place.
enum Palette {
    // MARK: Status

    static let taken = Color(red: 0.10, green: 0.50, blue: 0.22)
    static let due = Color(red: 0.0, green: 0.40, blue: 0.85)
    static let late = Color(red: 0.78, green: 0.32, blue: 0.0)

    // MARK: Text, darkest first

    static let textPrimary = Color.black
    /// The "Scan Pills" hint.
    static let textProminent = Color(white: 0.1)
    /// The date above the clock.
    static let textSubtitle = Color(white: 0.25)
    /// Supporting lines inside the scan banner.
    static let textBody = Color(white: 0.3)
    /// Strength, dose times.
    static let textSecondary = Color(white: 0.35)
    /// Counts, empty states, time until a dose.
    static let textTertiary = Color(white: 0.4)
    /// Section headers and neutral icons.
    static let textMuted = Color(white: 0.45)

    // MARK: Surfaces and strokes

    static let background = Color.white
    static let cardFill = Color(white: 0.96)
    /// Stand-in for Liquid Glass before iOS 26.
    static let glassFallbackFill = Color(white: 0.94)
    /// An unticked checkbox.
    static let controlInactive = Color(white: 0.3)
    /// The hand-drawn scan arrow.
    static let drawing = Color(white: 0.15)
}
