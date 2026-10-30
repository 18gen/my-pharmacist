//
//  Dose.swift
//  MedLens
//

import Foundation

/// One scheduled dose of a medication on a specific day.
nonisolated struct Dose: Identifiable, Hashable, Sendable {
    let medication: Medication
    let time: DoseTime
    let scheduled: Date
    /// Stable within a day, e.g. "metformin-500@8:00"; combined with the day for storage.
    let id: String

    init(medication: Medication, time: DoseTime, day: Date, calendar: Calendar = .current) {
        self.medication = medication
        self.time = time
        self.scheduled = time.date(on: day, calendar: calendar)
        self.id = "\(medication.id)@\(time.hour):\(String(format: "%02d", time.minute))"
    }
}

/// Where a dose stands right now.
nonisolated enum DoseState: Hashable, Sendable {
    /// More than `dueWindow` before its time.
    case upcoming
    /// Within `dueWindow` of its time.
    case due
    /// More than `dueWindow` past its time and not taken. It stays on the list to take,
    /// because the person may still take it later.
    case late
    case taken(at: Date)

    var isTaken: Bool {
        if case .taken = self { return true }
        return false
    }

    /// Doses still to take: upcoming, due, or late.
    var isPending: Bool {
        switch self {
        case .upcoming, .due, .late: return true
        case .taken: return false
        }
    }
}
