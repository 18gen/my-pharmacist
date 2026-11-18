//
//  DayPeriod.swift
//  MyPharmacist
//

import Foundation

/// The words and symbol for a time of day, like the labels on a pill organizer.
nonisolated struct DayPeriod: Sendable {
    let name: String
    let symbol: String

    init(_ time: DoseTime) {
        switch time.hour {
        // Midnight and the small hours belong with the night before, not the morning.
        case ..<5: (name, symbol) = ("Bedtime", "bed.double.fill")
        case ..<11: (name, symbol) = ("Morning", "sunrise.fill")
        case ..<15: (name, symbol) = ("Midday", "sun.max.fill")
        case ..<18: (name, symbol) = ("Afternoon", "sun.min.fill")
        case ..<22: (name, symbol) = ("Evening", "moon.fill")
        default: (name, symbol) = ("Bedtime", "bed.double.fill")
        }
    }
}
