//
//  TestSupport.swift
//  MedLensTests
//

import Foundation
@testable import MedLens

/// A fixed calendar and day so schedule tests don't depend on the machine's time zone.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026-10-14, the day MedLens was started.
    static let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14))!

    static func at(_ hour: Int, _ minute: Int = 0, on day: Date = day, calendar: Calendar = calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
}

extension SampleMedications {
    static var metformin: Medication { all.first { $0.id == "metformin-500" }! }
    static var lisinopril: Medication { all.first { $0.id == "lisinopril-10" }! }
}
