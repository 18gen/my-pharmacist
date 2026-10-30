//
//  Date+Formatting.swift
//  MedLens
//

import Foundation

nonisolated extension Date {
    /// The time in the phone's format, e.g. "8:00 AM".
    var shortTime: String {
        formatted(date: .omitted, time: .shortened)
    }
}
