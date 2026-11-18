//
//  DoseLog.swift
//  MyPharmacist
//

import Foundation

/// Which doses were taken, and which of those were scanned: what the ticks on Home and
/// "Already taken" in a scan's results come from.
///
/// A scan of a pill OK to take counts as taking it, so a scan is never recorded without a
/// taken mark, and taking the mark off ("Not taken") takes the scan off too. A dose can be
/// marked taken by hand, without a scan.
///
/// Saved as one flat record of times (`DoseLogStorage`), under keys that stay the same
/// from version to version:
/// - "2026-10-14|metformin-500@8:00" (`Dose.id`): when the dose's pill was scanned;
/// - "taken|2026-10-14|metformin-500@8:00": when the dose was marked taken;
/// - "2026-10-14|ondansetron-8@needed", and "taken|" before it: the same for a medication
///   taken only when needed, which has no doses, by day.
nonisolated struct DoseLog: Equatable, Sendable {
    /// What is recorded about: one dose, or a medication taken only when needed on a day.
    struct Key: Hashable, Sendable {
        /// The key a scan is saved under; the taken mark's is the same after "taken|".
        let scanKey: String

        var takenKey: String { DoseLog.takenPrefix + scanKey }

        static func dose(_ dose: Dose) -> Key {
            Key(scanKey: dose.id)
        }

        static func asNeeded(_ medicationID: String, on day: Date, calendar: Calendar) -> Key {
            Key(scanKey: Dose.dayKey(day, calendar: calendar) + "|\(medicationID)@needed")
        }
    }

    /// Every time recorded, under the saved keys.
    private(set) var entries: [String: Date]

    private static let takenPrefix = "taken|"

    init(_ entries: [String: Date] = [:]) {
        self.entries = entries
    }

    /// A saved record as this version reads it: anything older than `keepDays` before
    /// `now` is dropped, as only the last few days matter, and a scan saved before a scan
    /// counted as taken gets its taken mark, at the scan's time.
    init(saved: [String: Date], now: Date, keepDays: Int, calendar: Calendar) {
        let cutoff = calendar.date(byAdding: .day, value: -keepDays, to: now) ?? .distantPast
        var entries = saved.filter { $0.value >= cutoff }
        for (key, time) in entries where !key.hasPrefix(Self.takenPrefix) && entries[Self.takenPrefix + key] == nil {
            entries[Self.takenPrefix + key] = time
        }
        self.entries = entries
    }

    // MARK: Reading

    func scannedAt(_ key: Key) -> Date? {
        entries[key.scanKey]
    }

    func takenAt(_ key: Key) -> Date? {
        entries[key.takenKey]
    }

    /// When each dose's pill was scanned, by `Dose.id`.
    var scans: [String: Date] {
        entries.filter { !$0.key.hasPrefix(Self.takenPrefix) }
    }

    /// When each dose was marked taken, by `Dose.id`.
    var takenMarks: [String: Date] {
        var taken: [String: Date] = [:]
        for (key, time) in entries where key.hasPrefix(Self.takenPrefix) {
            taken[String(key.dropFirst(Self.takenPrefix.count))] = time
        }
        return taken
    }

    /// The same record without these keys, as if they had never been scanned or taken.
    func removing(_ keys: some Sequence<Key>) -> DoseLog {
        var log = self
        for key in keys { log.markNotTaken(key) }
        return log
    }

    // MARK: Changing

    /// Marked taken by hand, at `time`. A scan of it stays as it was.
    mutating func markTaken(_ key: Key, at time: Date) {
        entries[key.takenKey] = time
    }

    /// Its pill was scanned OK to take at `time`, which marks it taken then too.
    mutating func markScanned(_ key: Key, at time: Date) {
        entries[key.scanKey] = time
        entries[key.takenKey] = time
    }

    /// Not taken after all: the mark and any scan both go, so the next scan of its pill
    /// says to take it.
    mutating func markNotTaken(_ key: Key) {
        entries[key.scanKey] = nil
        entries[key.takenKey] = nil
    }

    /// Moves what is recorded about one key to another, replacing what that one had: for a
    /// dose whose time was changed after it was taken.
    mutating func move(_ source: Key, to destination: Key) {
        let scanned = entries[source.scanKey], taken = entries[source.takenKey]
        guard source != destination, scanned != nil || taken != nil else { return }
        markNotTaken(source)
        entries[destination.scanKey] = scanned
        entries[destination.takenKey] = taken
    }

    /// Forgets everything recorded.
    mutating func removeAll() {
        entries = [:]
    }
}
