//
//  DoseSlot.swift
//  MyPharmacist
//

import Foundation

/// The doses of one time of day, like one compartment of a pill organizer.
nonisolated struct DoseSlot: Identifiable, Hashable, Sendable {
    let time: DoseTime
    /// The time on today's date.
    let scheduled: Date
    /// In medication name order.
    let items: [ScheduledDose]
    let status: Status

    var id: DoseTime { time }

    /// Where the slot stands, without counting hours: knowing a dose is "7 hr late" doesn't
    /// tell the person what to do.
    enum Status: Hashable, Sendable {
        /// Every dose in it was scanned; `at` is the last of those times.
        case done(at: Date)
        /// Its time is close, from `DoseSchedule.earlyWindow` before it until
        /// `DoseSchedule.nowWindowAfter` after it.
        case now
        /// Past that, with doses not scanned yet.
        case notScannedYet
        /// The first slot still to come.
        case next
        /// Any slot after that.
        case later

        var isDone: Bool {
            if case .done = self { return true }
            return false
        }
    }
}
