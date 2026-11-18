//
//  DoseSchedule.swift
//  MyPharmacist
//

import Foundation

/// Pure scheduling rules, independent of storage and UI so they can be checked in isolation.
nonisolated enum DoseSchedule {
    /// A pill may count for a dose from 1 hour before its time...
    static let earlyWindow: TimeInterval = 60 * 60
    /// ...until 2 hours after it. Later than that the dose is missed: the app never says
    /// to take it, because a late dose taken close to the next one can be a double dose.
    static let lateWindow: TimeInterval = 2 * 60 * 60

    /// Whether `now` is inside the window of a dose at `scheduled`, where a pill counts for it.
    static func isInWindow(_ scheduled: Date, now: Date) -> Bool {
        now >= scheduled.addingTimeInterval(-earlyWindow) && now <= scheduled.addingTimeInterval(lateWindow)
    }

    /// All of the given medications' doses on `day`, in time order.
    static func doses(for medications: [Medication], on day: Date, calendar: Calendar = .current) -> [Dose] {
        medications
            .flatMap { medication in
                medication.doseTimes.map { Dose(medication: medication, time: $0, day: day, calendar: calendar) }
            }
            .sorted { ($0.scheduled, $0.medication.name) < ($1.scheduled, $1.medication.name) }
    }

    /// The doses of the day before, the day and the day after `now`, in time order: enough
    /// to judge a pill around midnight, when the dose it is for may be on another day.
    static func doses(for medications: [Medication], around now: Date, calendar: Calendar = .current) -> [Dose] {
        [-1, 0, 1]
            .compactMap { calendar.date(byAdding: .day, value: $0, to: now) }
            .flatMap { doses(for: medications, on: $0, calendar: calendar) }
            .sorted { ($0.scheduled, $0.medication.name) < ($1.scheduled, $1.medication.name) }
    }

    /// The state of `dose`, given when doses were marked taken and when their pills were
    /// scanned (both keyed by `Dose.id`). A scan counts as taken even without a mark.
    static func state(of dose: Dose, scannedAt: [String: Date], takenAt: [String: Date] = [:]) -> DoseState {
        let scanned = scannedAt[dose.id]
        guard let taken = takenAt[dose.id] ?? scanned else { return .pending }
        return .taken(at: taken, scannedAt: scanned)
    }

    /// Decides what a pill of `medication` counts for now. Never more than one dose, and
    /// never a dose outside its window:
    /// 1. a dose not taken yet, from `earlyWindow` before its time to `lateWindow` after
    ///    it: take it (the latest, if several);
    /// 2. otherwise the latest dose whose window has opened: taken means this pill isn't
    ///    for it; not taken means it is missed;
    /// 3. otherwise the next dose: too early.
    /// - Parameter doses: The doses around now (`doses(for:around:)`), so a dose just
    ///   after midnight counts the evening before.
    static func decision(for medication: Medication, doses: [Dose], scannedAt: [String: Date],
                         takenAt: [String: Date] = [:], now: Date) -> DoseDecision {
        let states = withStates(doses.filter { $0.medication.id == medication.id }, scannedAt: scannedAt, takenAt: takenAt)
        guard !states.isEmpty else { return .notScheduledToday(medication) }

        if let dose = states.last(where: { $0.state.isPending && isInWindow($0.dose.scheduled, now: now) })?.dose {
            return .take(dose)
        }

        let next = states.first { $0.state.isPending && $0.dose.scheduled > now }?.dose
        // A dose taken a little before its time is the latest one, though its time is
        // still to come: the pill is judged against it, not the dose before.
        if let latest = states.last(where: { $0.dose.scheduled <= now.addingTimeInterval(earlyWindow) }) {
            if let time = latest.state.takenAt {
                return .alreadyTaken(latest.dose, at: time, next: next)
            }
            return .missed(latest.dose, next: next)
        }
        if let next {
            return .tooEarly(next: next)
        }
        return .notScheduledToday(medication)
    }

    /// The day's doses grouped by time of day, earliest first, like the compartments of a
    /// pill organizer. Each says where it stands without counting hours: done, now, not
    /// taken yet, next or later.
    static func slots(_ dayDoses: [Dose], scannedAt: [String: Date], takenAt: [String: Date] = [:], now: Date) -> [DoseSlot] {
        let byTime = Dictionary(grouping: withStates(dayDoses, scannedAt: scannedAt, takenAt: takenAt), by: \.dose.time)
        var nextIsAssigned = false
        return byTime.keys.sorted().map { time in
            let items = byTime[time, default: []].sorted { $0.dose.medication.name < $1.dose.medication.name }
            let scheduled = items[0].dose.scheduled
            let takenTimes = items.compactMap(\.state.takenAt)
            let status: DoseSlot.Status
            if takenTimes.count == items.count, let last = takenTimes.max() {
                status = .done(at: last)
            } else if now < scheduled.addingTimeInterval(-earlyWindow) {
                status = nextIsAssigned ? .later : .next
                nextIsAssigned = true
            } else if now <= scheduled.addingTimeInterval(lateWindow) {
                status = .now
            } else {
                status = .notTakenYet
            }
            return DoseSlot(time: time, scheduled: scheduled, items: items, status: status)
        }
    }

    private static func withStates(_ doses: [Dose], scannedAt: [String: Date], takenAt: [String: Date]) -> [ScheduledDose] {
        doses.map { ScheduledDose(dose: $0, state: state(of: $0, scannedAt: scannedAt, takenAt: takenAt)) }
    }
}
