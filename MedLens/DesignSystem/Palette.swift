//
//  Palette.swift
//  MedLens
//

import SwiftUI

/// Colours chosen to stay readable on the light grey card.
enum Palette {
    static let taken = Color(red: 0.10, green: 0.50, blue: 0.22)
    static let due = Color(red: 0.0, green: 0.40, blue: 0.85)
    static let late = Color(red: 0.78, green: 0.32, blue: 0.0)

    static func tint(_ tint: PillTint) -> Color {
        switch tint {
        case .blue: return Color(red: 0.15, green: 0.45, blue: 0.90)
        case .orange: return Color(red: 0.90, green: 0.45, blue: 0.10)
        case .pink: return Color(red: 0.85, green: 0.25, blue: 0.50)
        case .green: return Color(red: 0.15, green: 0.60, blue: 0.35)
        case .purple: return Color(red: 0.50, green: 0.30, blue: 0.80)
        }
    }
}
