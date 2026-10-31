//
//  MedicationStore.swift
//  MyPharmacist
//

import Foundation
import Observation

/// The registered medications and which doses have been taken, saved on the device.
@Observable
final class MedicationStore {
    private(set) var medications: [Medication]

    /// When each dose was taken, keyed by "<day>|<Dose.id>", e.g. "2026-10-14|metformin-500@8:00".
    private var takenLog: [String: Date] {
        didSet { save() }
    }

    @ObservationIgnored private let storage: any DoseLogStorage
    @ObservationIgnored private let calendar: Calendar
    /// Older records are dropped on launch; only today's matter.
    private static let keepDays = 14

    /// - Parameter now: when the store is created; records older than `keepDays` before it are dropped.
    init(medications: [Medication] = SampleMedications.all,
         storage: any DoseLogStorage = UserDefaultsDoseLogStorage(),
         calendar: Calendar = .current,
         now: Date = Date()) {
        self.medications = medications
        self.storage = storage
        self.calendar = calendar
        self.takenLog = Self.recent(storage.load(), now: now, calendar: calendar)
    }

    // MARK: Reading

    func doses(on day: Date) -> [Dose] {
        DoseSchedule.doses(for: medications, on: day, calendar: calendar)
    }

    /// Today's doses in display order (pending first, earliest on top) with their states.
    func todayList(now: Date) -> [ScheduledDose] {
        let doses = doses(on: now)
        return DoseSchedule.ordered(doses, takenAt: takenTimes(on: now), now: now)
    }

    // MARK: Changing

    func markTaken(_ dose: Dose, at time: Date = Date()) {
        takenLog[key(for: dose)] = time
    }

    func markNotTaken(_ dose: Dose) {
        takenLog[key(for: dose)] = nil
    }

    /// Which registered medication a name read from a label refers to.
    func match(scannedName: String) -> MedicationMatcher.Result {
        MedicationMatcher.match(scannedName: scannedName, in: medications)
    }

    /// Handles a medication name confirmed by the scanner: finds the medication, decides
    /// which dose (if any) it counts for, and marks that dose taken.
    func recordScan(scannedName: String, now: Date = Date()) -> ScanOutcome {
        recordScan(match(scannedName: scannedName), scannedName: scannedName, now: now)
    }

    /// Same as `recordScan(scannedName:now:)` for a name that has already been matched.
    func recordScan(_ match: MedicationMatcher.Result, scannedName: String, now: Date = Date()) -> ScanOutcome {
        let outcome = DoseSchedule.scanOutcome(
            for: match,
            scannedName: scannedName,
            dayDoses: doses(on: now),
            takenAt: takenTimes(on: now),
            now: now
        )
        if case .checked(let dose) = outcome {
            markTaken(dose, at: now)
        }
        return outcome
    }

    // MARK: Storage

    /// The given day's taken times keyed by `Dose.id`.
    private func takenTimes(on day: Date) -> [String: Date] {
        let prefix = Self.dayKey(day, calendar: calendar) + "|"
        var result: [String: Date] = [:]
        for (key, time) in takenLog where key.hasPrefix(prefix) {
            result[String(key.dropFirst(prefix.count))] = time
        }
        return result
    }

    private func key(for dose: Dose) -> String {
        Self.dayKey(dose.scheduled, calendar: calendar) + "|" + dose.id
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func save() {
        storage.save(takenLog)
    }

    private static func recent(_ log: [String: Date], now: Date, calendar: Calendar) -> [String: Date] {
        let cutoff = calendar.date(byAdding: .day, value: -keepDays, to: now) ?? .distantPast
        return log.filter { $0.value >= cutoff }
    }
}
