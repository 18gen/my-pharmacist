//
//  TestSupport.swift
//  MyPharmacistTests
//

import CoreGraphics
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

/// Fixed medications for tests, so tests don't change when the app's mock data does.
enum TestMedications {
    static let metformin = Medication(id: "metformin-500", name: "Metformin", strength: "500 mg",
                                      doseTimes: [DoseTime(8), DoseTime(18)])
    static let lisinopril = Medication(id: "lisinopril-10", name: "Lisinopril", strength: "10 mg",
                                       doseTimes: [DoseTime(8)])
    static let atorvastatin = Medication(id: "atorvastatin-20", name: "Atorvastatin", strength: "20 mg",
                                         doseTimes: [DoseTime(21)])
    static let all = [metformin, lisinopril, atorvastatin]
}

/// A tiny solid image, for code that needs a photo or a pill cut-out but not its pixels.
func testImage(width: Int = 4, height: Int = 4) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(gray: 0.5, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}
