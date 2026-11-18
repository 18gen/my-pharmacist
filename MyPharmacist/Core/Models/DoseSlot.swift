//
//  DoseSlot.swift
//  MyPharmacist
//

import Foundation

/// The doses of one time of day, like one compartment of a pill organizer.
nonisolated struct DoseSlot: Identifiable, Hashable, Sendable {
    let time: DoseTime
    /// The time on its day: today's, or the day before or after around midnight.
    let scheduled: Date
    /// In medication name order. Never empty.
    let items: [ScheduledDose]
    let status: Status

    /// The day and the time, "2026-10-14@8:00": unique even when the same time of day
    /// shows for two days (around midnight), and when the clocks change.
    var id: String {
        let day = items.first.map { String($0.dose.id.prefix { $0 != "|" }) } ?? ""
        return "\(day)@\(time.hour):" + String(format: "%02d", time.minute)
    }

    /// Where the slot stands, without counting hours: knowing a dose is "7 hr late" doesn't
    /// tell the person what to do.
    enum Status: Hashable, Sendable {
        /// Every dose in it was taken; `at` is the last of those times.
        case done(at: Date)
        /// Its time is close, from `DoseSchedule.earlyWindow` before it until
        /// `DoseSchedule.lateWindow` after it: the same window a pill counts in.
        case now
        /// Past that, with doses not taken yet.
        case notTakenYet
        /// The first slot still to come.
        case next
        /// Any slot after that.
        case later

        /// Only the time of day to take now is shown open; every other one folds to its
        /// header line, so what to take stands out.
        var isFolded: Bool { self != .now }
    }
}
