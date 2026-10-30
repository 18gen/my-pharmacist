//
//  Medication.swift
//  MedLens
//

import Foundation

/// A medication the person takes, with the times of day they take it.
nonisolated struct Medication: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let strength: String
    let doseTimes: [DoseTime]
    /// Placeholder picture until real photos exist: an SF Symbol and a colour.
    let symbol: String
    let tint: PillTint

    var displayName: String { "\(name) \(strength)" }
}

/// Colours for the placeholder pill pictures.
nonisolated enum PillTint: String, Hashable, Sendable {
    case blue, orange, pink, green, purple
}
