//
//  Palette.swift
//  MyPharmacist
//

import SwiftUI

/// The app's colours and title fonts: the onboarding's cream and dark brown carried
/// through, with dark brown words on a cream page and serif titles. Each colour is chosen
/// to stay readable on the cream page and the warmer card.
/// Views use these names instead of raw colours so the whole app can be retuned in one place.
enum Palette {
    // MARK: The two the look is built on

    /// The page's lightest warm tone: words and buttons on dark pictures and dark buttons.
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.90)
    /// A brown close to black: the darkest words, the main buttons, the onboarding's page.
    static let espresso = Color(red: 0.13, green: 0.08, blue: 0.06)

    // MARK: Status

    /// OK to take, and a dose that was scanned.
    static let ok = Color(red: 0.08, green: 0.42, blue: 0.18)
    static let due = Color(red: 0.0, green: 0.36, blue: 0.78)
    static let late = Color(red: 0.66, green: 0.26, blue: 0.0)
    /// A pill not to take now.
    static let danger = Color(red: 0.72, green: 0.08, blue: 0.10)
    /// For the person to decide. A dark amber, because yellow text can't be read on cream;
    /// the yellow is in `cautionFill`.
    static let caution = Color(red: 0.50, green: 0.33, blue: 0.0)
    /// Words on a `due` fill.
    static let onDue = Color.white

    // MARK: Result tints, behind rows outlined in the colour above

    static let okFill = Color(red: 0.91, green: 0.95, blue: 0.87)
    static let dangerFill = Color(red: 0.99, green: 0.91, blue: 0.88)
    static let cautionFill = Color(red: 0.99, green: 0.92, blue: 0.74)

    // MARK: Text, darkest first

    static let textPrimary = espresso
    /// The "Scan Pills" hint.
    static let textProminent = Color(red: 0.18, green: 0.11, blue: 0.08)
    /// The date above the clock.
    static let textSubtitle = Color(red: 0.28, green: 0.20, blue: 0.15)
    /// Supporting lines inside the scan banner.
    static let textBody = Color(red: 0.31, green: 0.23, blue: 0.18)
    /// Strength, dose times.
    static let textSecondary = Color(red: 0.35, green: 0.27, blue: 0.22)
    /// Counts, empty states, time until a dose.
    static let textTertiary = Color(red: 0.39, green: 0.31, blue: 0.26)
    /// Section headers and neutral icons.
    static let textMuted = Color(red: 0.43, green: 0.35, blue: 0.30)

    // MARK: Surfaces and strokes

    /// The page: a paler cream than `cream`, so a whole screen of it stays calm.
    static let background = Color(red: 0.992, green: 0.972, blue: 0.925)
    static let cardFill = Color(red: 0.958, green: 0.928, blue: 0.868)
    /// Stand-in for Liquid Glass before iOS 26.
    static let glassFallbackFill = Color(red: 0.94, green: 0.905, blue: 0.84)
    /// The hand-drawn scan arrow.
    static let drawing = Color(red: 0.20, green: 0.13, blue: 0.10)
    /// Placeholder blocks where words and pictures will appear (on `cardFill`).
    static let skeleton = Color(red: 0.89, green: 0.85, blue: 0.78)

    // MARK: Buttons

    /// A page's main button, and the words on it.
    static let button = espresso
    static let onButton = cream
    /// The round scan button on Home, and the camera icon on it.
    static let scanButton = espresso
    static let onScanButton = cream

    // MARK: Titles

    /// A page's title, in serif like the onboarding's.
    static let pageTitle = Font.system(.largeTitle, design: .serif, weight: .medium)

    /// A title larger than any text style: Home's clock, the scan's instruction.
    static func largeTitle(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }
}
