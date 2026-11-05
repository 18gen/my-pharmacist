//
//  DoseLogStorage.swift
//  MyPharmacist
//

import Foundation

/// Where the record of scanned doses is kept: when each dose's pill was scanned, keyed by
/// "<day>|<Dose.id>". `MedicationStore` decides what goes in it; this only loads and saves.
protocol DoseLogStorage {
    func load() -> [String: Date]
    func save(_ log: [String: Date])
}

/// Saved on the device in UserDefaults, as seconds since 1970 under "scannedDoses".
struct UserDefaultsDoseLogStorage: DoseLogStorage {
    private static let key = "scannedDoses"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String: Date] {
        let stored = defaults.dictionary(forKey: Self.key) as? [String: Double] ?? [:]
        return stored.mapValues { Date(timeIntervalSince1970: $0) }
    }

    func save(_ log: [String: Date]) {
        defaults.set(log.mapValues(\.timeIntervalSince1970), forKey: Self.key)
    }
}

/// Kept in memory only, for tests and previews.
final class InMemoryDoseLogStorage: DoseLogStorage {
    private(set) var log: [String: Date]

    init(_ log: [String: Date] = [:]) {
        self.log = log
    }

    func load() -> [String: Date] { log }
    func save(_ log: [String: Date]) { self.log = log }
}
