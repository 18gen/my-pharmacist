//
//  DoseSchedule.swift
//  MyPharmacist
//

import Foundation

/// Pure scheduling rules, independent of storage and UI so they can be checked in isolation.
nonisolated enum DoseSchedule {
    /// "Now" means within 15 minutes either side of the dose time.
    static let dueWindow: TimeInterval = 15 * 60
    /// A pill may count for a dose up to 1 hour before its time.
    static let earlyWindow: TimeInterval = 60 * 60

    /// All of the given medications' doses on `day`, in time order.
    static func doses(for medications: [Medication], on day: Date, calendar: Calendar = .current) -> [Dose] {
        medications
            .flatMap { medication in
                medication.doseTimes.map { Dose(medication: medication, time: $0, day: day, calendar: calendar) }
            }
            .sorted { ($0.scheduled, $0.medication.name) < ($1.scheduled, $1.medication.name) }
    }

    /// The state of `dose`, given when each of the day's doses was taken (keyed by `Dose.id`).
    static func state(of dose: Dose, takenAt: [String: Date], now: Date) -> DoseState {
        if let time = takenAt[dose.id] {
            return .taken(at: time)
        }

        let untilDose = dose.scheduled.timeIntervalSince(now)
        if untilDose > dueWindow { return .upcoming }
        if untilDose >= -dueWindow { return .due }
        return .late
    }

    /// Today's list: doses still to take first (earliest on top), then taken ones.
    static func ordered(_ dayDoses: [Dose], takenAt: [String: Date], now: Date) -> [ScheduledDose] {
        let items = withStates(dayDoses, takenAt: takenAt, now: now)
        return items.filter { $0.state.isPending } + items.filter { $0.state.isTaken }
    }

    /// Decides what a pill of `medication` counts for now. Never more than one dose.
    /// If several untaken doses could fit, it picks the one closest to now, so the dose
    /// that is currently due is never left looking untaken.
    static func decision(for medication: Medication, dayDoses: [Dose], takenAt: [String: Date], now: Date) -> DoseDecision {
        let doses = dayDoses.filter { $0.medication.id == medication.id }
        guard !doses.isEmpty else { return .notScheduledToday(medication) }

        let states = withStates(doses, takenAt: takenAt, now: now)

        // The latest pending dose that is due, late, or at most `earlyWindow` away.
        let checkable = states.filter {
            $0.state.isPending && $0.dose.scheduled <= now.addingTimeInterval(earlyWindow)
        }
        if let dose = checkable.last?.dose {
            return .take(dose)
        }

        let next = states.first { $0.state.isPending }?.dose
        let lastTaken = states.last { $0.state.isTaken }
        if let lastTaken, case .taken(let time) = lastTaken.state {
            return .alreadyTaken(lastTaken.dose, at: time, next: next)
        }
        if let next {
            return .tooEarly(next: next)
        }
        return .notScheduledToday(medication)
    }

    private static func withStates(_ doses: [Dose], takenAt: [String: Date], now: Date) -> [ScheduledDose] {
        doses.map { ScheduledDose(dose: $0, state: state(of: $0, takenAt: takenAt, now: now)) }
    }
}
