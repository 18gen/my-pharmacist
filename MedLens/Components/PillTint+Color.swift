//
//  PillTint+Color.swift
//  MedLens
//

import SwiftUI

extension PillTint {
    /// The colour for the placeholder pill pictures.
    var color: Color {
        switch self {
        case .blue: return Color(red: 0.15, green: 0.45, blue: 0.90)
        case .orange: return Color(red: 0.90, green: 0.45, blue: 0.10)
        case .pink: return Color(red: 0.85, green: 0.25, blue: 0.50)
        case .green: return Color(red: 0.15, green: 0.60, blue: 0.35)
        case .purple: return Color(red: 0.50, green: 0.30, blue: 0.80)
        }
    }
}
