//
//  Date+Formatting.swift
//  MyPharmacist
//

import Foundation

nonisolated extension Date {
    /// The time in the phone's format, e.g. "8:00 AM".
    var shortTime: String {
        formatted(date: .omitted, time: .shortened)
    }

    /// "6:33 AM", or "06:33" / "18:33" in 24-hour time regardless of the phone's region.
    func clockText(use24Hour: Bool, timeZone: TimeZone = .current, calendar: Calendar = .current) -> String {
        guard use24Hour else { return shortTime }
        let style = Date.VerbatimFormatStyle(
            format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            timeZone: timeZone,
            calendar: calendar
        )
        return formatted(style)
    }
}
