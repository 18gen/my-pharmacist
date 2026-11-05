//
//  MedicationStore.swift
//  MyPharmacist
//

import Foundation
import Observation

/// The registered medications and which doses have been scanned, saved on the device.
/// There is no "taken": the app only knows a dose's pill was scanned and judged OK to take.
@Observable
final class MedicationStore {
    private(set) var medications: [Medication]

    /// When each dose was scanned, keyed by "<day>|<Dose.id>", e.g. "2026-10-14|metformin-500@8:00".
    private var scanLog: [String: Date] {
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
        self.scanLog = Self.recent(storage.load(), now: now, calendar: calendar)
    }

    // MARK: Reading

    func doses(on day: Date) -> [Dose] {
        DoseSchedule.doses(for: medications, on: day, calendar: calendar)
    }

    /// Today's doses grouped by time of day, earliest first, each group with where it stands.
    func todaySlots(now: Date) -> [DoseSlot] {
        DoseSchedule.slots(doses(on: now), scannedAt: scanTimes(on: now), now: now)
    }

    /// Medications taken only when needed, which have no place in the day's slots.
    var asNeededMedications: [Medication] {
        medications.filter { $0.asNeeded != nil }
    }

    /// Today's doses in display order (pending first, earliest on top) with their states.
    func todayList(now: Date) -> [ScheduledDose] {
        let doses = doses(on: now)
        return DoseSchedule.ordered(doses, scannedAt: scanTimes(on: now), now: now)
    }

    // MARK: Changing

    /// Records that these doses' pills were scanned, OK to take, at `time`.
    func recordScan(of doses: [Dose], at time: Date = Date()) {
        for dose in doses {
            scanLog[key(for: dose)] = time
        }
    }

    func removeScans(of doses: [Dose]) {
        for dose in doses {
            scanLog[key(for: dose)] = nil
        }
    }

    /// Decides which of the pills in a photo to take now, given what each was recognized as.
    func check(_ identities: [Medication?], now: Date = Date()) -> PillSetCheck {
        PillSetVerifier.check(identities, medications: medications, dayDoses: doses(on: now),
                              scannedAt: scanTimes(on: now), now: now)
    }

    // MARK: Storage

    /// The given day's scan times keyed by `Dose.id`.
    private func scanTimes(on day: Date) -> [String: Date] {
        let prefix = Self.dayKey(day, calendar: calendar) + "|"
        var result: [String: Date] = [:]
        for (key, time) in scanLog where key.hasPrefix(prefix) {
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
        storage.save(scanLog)
    }

    private static func recent(_ log: [String: Date], now: Date, calendar: Calendar) -> [String: Date] {
        let cutoff = calendar.date(byAdding: .day, value: -keepDays, to: now) ?? .distantPast
        return log.filter { $0.value >= cutoff }
    }
}
