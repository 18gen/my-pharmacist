//
//  Dose.swift
//  MyPharmacist
//

import Foundation

/// One scheduled dose of a medication on a specific day.
nonisolated struct Dose: Identifiable, Hashable, Sendable {
    let medication: Medication
    let time: DoseTime
    let scheduled: Date
    /// The day, the medication and the time, e.g. "2026-10-14|metformin-500@8:00": unique
    /// across days, and the key a scan of it is saved under.
    let id: String

    init(medication: Medication, time: DoseTime, day: Date, calendar: Calendar = .current) {
        self.medication = medication
        self.time = time
        self.scheduled = time.date(on: day, calendar: calendar)
        self.id = Self.dayKey(scheduled, calendar: calendar)
            + "|\(medication.id)@\(time.hour):\(String(format: "%02d", time.minute))"
    }

    /// "2026-10-14" for any time on that day.
    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// A dose together with where it stands, as listed on the home screen.
nonisolated struct ScheduledDose: Identifiable, Hashable, Sendable {
    let dose: Dose
    let state: DoseState

    var id: String { dose.id }
}

/// Where a dose stands right now.
nonisolated enum DoseState: Hashable, Sendable {
    /// More than `dueWindow` before its time.
    case upcoming
    /// Within `dueWindow` of its time.
    case due
    /// More than `dueWindow` past its time and not scanned. It stays on the list to take,
    /// because the person may still take it later.
    case late
    /// A scan found this dose's pill, OK to take, at this time. The app can't know
    /// whether it was swallowed, only that it was scanned.
    case scanned(at: Date)
    /// The person said they took it, at this time: on Home, or after a scan. When its
    /// pill was scanned too, that time is kept beside it.
    case taken(at: Date, scannedAt: Date?)

    /// When this dose's pill was scanned, whether or not it was then marked taken.
    var scannedAt: Date? {
        switch self {
        case .scanned(let time): time
        case .taken(_, let scannedAt): scannedAt
        case .upcoming, .due, .late: nil
        }
    }

    /// When the person marked this dose taken; nil if they didn't.
    var takenAt: Date? {
        if case .taken(let time, _) = self { return time }
        return nil
    }

    var isScanned: Bool { scannedAt != nil }

    /// Doses neither scanned nor marked taken yet: upcoming, due, or late.
    var isPending: Bool {
        switch self {
        case .upcoming, .due, .late: return true
        case .scanned, .taken: return false
        }
    }
}
