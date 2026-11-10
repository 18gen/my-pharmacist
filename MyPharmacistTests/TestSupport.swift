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
    /// Taken only when needed; not in `all`, so the scheduled tests stay as they are.
    static let ondansetron = Medication(id: "ondansetron-8", name: "Ondansetron", strength: "8 mg",
                                        doseTimes: [], asNeeded: "Only when you feel sick")
}

/// A tiny solid image, for code that needs a photo or a pill cut-out but not its pixels.
func testImage(width: Int = 4, height: Int = 4) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(gray: 0.5, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// A picture made of solid rectangles, for checking where pixels end up.
/// - Parameter paint: Rectangles in pixels with the origin at the top left, and their
///   colours as (red, green, blue) from 0 to 1. Later ones cover earlier ones.
func paintedImage(width: Int, height: Int, background: (Double, Double, Double) = (0, 0, 0),
                  _ paint: [(rect: CGRect, color: (Double, Double, Double))] = []) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(red: background.0, green: background.1, blue: background.2, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    for item in paint {
        context.setFillColor(red: item.color.0, green: item.color.1, blue: item.color.2, alpha: 1)
        // Core Graphics counts up from the bottom.
        context.fill(CGRect(x: item.rect.minX, y: CGFloat(height) - item.rect.maxY, width: item.rect.width, height: item.rect.height))
    }
    return context.makeImage()!
}

/// The colour of one pixel as (red, green, blue) from 0 to 255, origin at the top left.
func pixel(of image: CGImage, x: Int, y: Int) -> (red: Int, green: Int, blue: Int) {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    let index = (y * image.width + x) * 4
    return (Int(bytes[index]), Int(bytes[index + 1]), Int(bytes[index + 2]))
}

/// A photo store in a new temporary folder, so tests never touch the app's photos.
func temporaryPhotoStore() -> MedicationPhotoStore {
    MedicationPhotoStore(directory: FileManager.default.temporaryDirectory
        .appending(path: "MyPharmacistTests-\(UUID().uuidString)", directoryHint: .isDirectory))
}
