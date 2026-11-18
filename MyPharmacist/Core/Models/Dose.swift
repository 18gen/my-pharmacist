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
    /// across days, and the key it is recorded under in `DoseLog`.
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

/// Where a dose stands: still to take, or taken.
nonisolated enum DoseState: Hashable, Sendable {
    /// Not taken yet, whether its time is still to come or has passed.
    case pending
    /// Taken at this time: ticked on Home, or its pill scanned OK to take, which ticks it.
    /// When it was scanned, the scan's time is kept beside it.
    case taken(at: Date, scannedAt: Date?)

    /// When this dose's pill was scanned; nil if it was ticked by hand or not taken.
    var scannedAt: Date? {
        if case .taken(_, let scannedAt) = self { return scannedAt }
        return nil
    }

    /// When this dose was taken; nil if it wasn't.
    var takenAt: Date? {
        if case .taken(let time, _) = self { return time }
        return nil
    }

    var isPending: Bool { self == .pending }
}
