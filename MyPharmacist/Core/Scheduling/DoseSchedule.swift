//
//  DoseSchedule.swift
//  MyPharmacist
//

import Foundation

/// Pure scheduling rules, independent of storage and UI so they can be checked in isolation.
nonisolated enum DoseSchedule {
    /// "Now" means within 15 minutes either side of the dose time.
    static let dueWindow: TimeInterval = 15 * 60
    /// A pill may count for a dose from 1 hour before its time...
    static let earlyWindow: TimeInterval = 60 * 60
    /// ...until 2 hours after it. Later than that the dose is missed: the app never says
    /// to take it, because a late dose taken close to the next one can be a double dose.
    static let lateWindow: TimeInterval = 2 * 60 * 60

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

    /// The state of `dose`, given when each of the day's doses was scanned (keyed by `Dose.id`).
    static func state(of dose: Dose, scannedAt: [String: Date], now: Date) -> DoseState {
        if let time = scannedAt[dose.id] {
            return .scanned(at: time)
        }

        let untilDose = dose.scheduled.timeIntervalSince(now)
        if untilDose > dueWindow { return .upcoming }
        if untilDose >= -dueWindow { return .due }
        return .late
    }

    /// Today's list: doses still to take first (earliest on top), then scanned ones.
    static func ordered(_ dayDoses: [Dose], scannedAt: [String: Date], now: Date) -> [ScheduledDose] {
        let items = withStates(dayDoses, scannedAt: scannedAt, now: now)
        return items.filter { $0.state.isPending } + items.filter { $0.state.isScanned }
    }

    /// Decides what a pill of `medication` counts for now. Never more than one dose, and
    /// never a dose outside its window:
    /// 1. a dose not scanned yet, from `earlyWindow` before its time to `lateWindow`
    ///    after it: take it (the latest, if several);
    /// 2. otherwise the latest dose already past: scanned means this pill may have been
    ///    taken already; not scanned means it is missed;
    /// 3. otherwise the next dose: too early.
    /// - Parameter doses: The doses around now (`doses(for:around:)`), so a dose just
    ///   after midnight counts the evening before.
    static func decision(for medication: Medication, doses: [Dose], scannedAt: [String: Date], now: Date) -> DoseDecision {
        let states = withStates(doses.filter { $0.medication.id == medication.id }, scannedAt: scannedAt, now: now)
        guard !states.isEmpty else { return .notScheduledToday(medication) }

        let inWindow = states.filter {
            $0.state.isPending
                && $0.dose.scheduled >= now.addingTimeInterval(-lateWindow)
                && $0.dose.scheduled <= now.addingTimeInterval(earlyWindow)
        }
        if let dose = inWindow.last?.dose {
            return .take(dose)
        }

        let next = states.first { $0.state.isPending && $0.dose.scheduled > now }?.dose
        if let latest = states.last(where: { $0.dose.scheduled <= now }) {
            if case .scanned(let time) = latest.state {
                return .alreadyScanned(latest.dose, at: time, next: next)
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
    /// scanned yet, next or later.
    static func slots(_ dayDoses: [Dose], scannedAt: [String: Date], now: Date) -> [DoseSlot] {
        let byTime = Dictionary(grouping: withStates(dayDoses, scannedAt: scannedAt, now: now), by: \.dose.time)
        var nextIsTaken = false
        return byTime.keys.sorted().map { time in
            let items = byTime[time, default: []].sorted { $0.dose.medication.name < $1.dose.medication.name }
            let scheduled = items[0].dose.scheduled
            let scanTimes = items.compactMap { item -> Date? in
                if case .scanned(let time) = item.state { time } else { nil }
            }
            let status: DoseSlot.Status
            if scanTimes.count == items.count, let last = scanTimes.max() {
                status = .done(at: last)
            } else if now < scheduled.addingTimeInterval(-earlyWindow) {
                status = nextIsTaken ? .later : .next
                nextIsTaken = true
            } else if now <= scheduled.addingTimeInterval(lateWindow) {
                status = .now
            } else {
                status = .notScannedYet
            }
            return DoseSlot(time: time, scheduled: scheduled, items: items, status: status)
        }
    }

    private static func withStates(_ doses: [Dose], scannedAt: [String: Date], now: Date) -> [ScheduledDose] {
        doses.map { ScheduledDose(dose: $0, state: state(of: $0, scannedAt: scannedAt, now: now)) }
    }
}
