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

    /// The state of `dose`, given when each of the day's doses was scanned and when each
    /// was marked taken (both keyed by `Dose.id`).
    static func state(of dose: Dose, scannedAt: [String: Date], takenAt: [String: Date] = [:], now: Date) -> DoseState {
        if let time = takenAt[dose.id] {
            return .taken(at: time, scannedAt: scannedAt[dose.id])
        }
        if let time = scannedAt[dose.id] {
            return .scanned(at: time)
        }

        let untilDose = dose.scheduled.timeIntervalSince(now)
        if untilDose > dueWindow { return .upcoming }
        if untilDose >= -dueWindow { return .due }
        return .late
    }

    /// Today's list: doses still to take first (earliest on top), then those scanned or
    /// marked taken.
    static func ordered(_ dayDoses: [Dose], scannedAt: [String: Date], takenAt: [String: Date] = [:], now: Date) -> [ScheduledDose] {
        let items = withStates(dayDoses, scannedAt: scannedAt, takenAt: takenAt, now: now)
        return items.filter { $0.state.isPending } + items.filter { !$0.state.isPending }
    }

    /// Decides what a pill of `medication` counts for now. Never more than one dose, and
    /// never a dose outside its window:
    /// 1. a dose neither scanned nor marked taken yet, from `earlyWindow` before its time
    ///    to `lateWindow` after it: take it (the latest, if several);
    /// 2. otherwise the latest dose whose window has opened: marked taken means this pill
    ///    isn't for it; scanned means this pill may have been taken already; neither
    ///    means it is missed;
    /// 3. otherwise the next dose: too early.
    /// - Parameter doses: The doses around now (`doses(for:around:)`), so a dose just
    ///   after midnight counts the evening before.
    static func decision(for medication: Medication, doses: [Dose], scannedAt: [String: Date],
                         takenAt: [String: Date] = [:], now: Date) -> DoseDecision {
        let states = withStates(doses.filter { $0.medication.id == medication.id }, scannedAt: scannedAt,
                                takenAt: takenAt, now: now)
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
        // A dose scanned or taken a little before its time is the latest one, though its
        // time is still to come: the pill is judged against it, not the dose before.
        if let latest = states.last(where: { $0.dose.scheduled <= now.addingTimeInterval(earlyWindow) }) {
            switch latest.state {
            case .taken(let time, _): return .alreadyTaken(latest.dose, at: time, next: next)
            case .scanned(let time): return .alreadyScanned(latest.dose, at: time, next: next)
            case .upcoming, .due, .late: return .missed(latest.dose, next: next)
            }
        }
        if let next {
            return .tooEarly(next: next)
        }
        return .notScheduledToday(medication)
    }

    /// The day's doses grouped by time of day, earliest first, like the compartments of a
    /// pill organizer. Each says where it stands without counting hours: done, now, not
    /// scanned yet, next or later.
    static func slots(_ dayDoses: [Dose], scannedAt: [String: Date], takenAt: [String: Date] = [:], now: Date) -> [DoseSlot] {
        let byTime = Dictionary(grouping: withStates(dayDoses, scannedAt: scannedAt, takenAt: takenAt, now: now),
                                by: \.dose.time)
        var nextIsTaken = false
        return byTime.keys.sorted().map { time in
            let items = byTime[time, default: []].sorted { $0.dose.medication.name < $1.dose.medication.name }
            let scheduled = items[0].dose.scheduled
            // For each dose that is done: when it was taken, or else when it was scanned.
            let doneTimes = items.compactMap { $0.state.takenAt ?? $0.state.scannedAt }
            let status: DoseSlot.Status
            if doneTimes.count == items.count, let last = doneTimes.max() {
                status = .done(at: last, taken: items.allSatisfy { $0.state.takenAt != nil })
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

    private static func withStates(_ doses: [Dose], scannedAt: [String: Date], takenAt: [String: Date],
                                   now: Date) -> [ScheduledDose] {
        doses.map { ScheduledDose(dose: $0, state: state(of: $0, scannedAt: scannedAt, takenAt: takenAt, now: now)) }
    }
}
