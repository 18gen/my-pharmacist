//
//  DoseTime.swift
//  MedLens
//

import Foundation

/// A time of day, independent of date.
nonisolated struct DoseTime: Hashable, Comparable, Sendable {
    let hour: Int
    let minute: Int

    init(_ hour: Int, _ minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }

    static func < (lhs: DoseTime, rhs: DoseTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }

    /// This time on the given day.
    func date(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
