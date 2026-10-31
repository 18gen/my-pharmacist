//
//  TestSupport.swift
//  MyPharmacistTests
//

import Foundation
@testable import MyPharmacist

/// A fixed calendar and day so schedule tests don't depend on the machine's time zone.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026-10-14, the day the project was started.
    static let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14))!

    static func at(_ hour: Int, _ minute: Int = 0, on day: Date = day, calendar: Calendar = calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
}

/// A private defaults domain per test so nothing touches the app's real data.
func isolatedDefaults() -> UserDefaults {
    let name = "MyPharmacistTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

extension SampleMedications {
    static var metformin: Medication { all.first { $0.id == "metformin-500" }! }
    static var lisinopril: Medication { all.first { $0.id == "lisinopril-10" }! }
}
