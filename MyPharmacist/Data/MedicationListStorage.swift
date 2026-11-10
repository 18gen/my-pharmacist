//
//  MedicationListStorage.swift
//  MyPharmacist
//

import Foundation

/// Where the person's medication list is kept. `MedicationStore` decides what goes in it;
/// this only loads and saves.
protocol MedicationListStorage {
    /// Nil when nothing was saved yet. An empty list is a list the person emptied.
    func load() -> [MedicationEntry]?
    func save(_ entries: [MedicationEntry])
}

/// Saved on the device in UserDefaults, as JSON under "medications.v2". (The prototype's
/// "medicationList" held catalog references and is no longer read.)
struct UserDefaultsMedicationListStorage: MedicationListStorage {
    private static let key = "medications.v2"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [MedicationEntry]? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode([MedicationEntry].self, from: data)
    }

    func save(_ entries: [MedicationEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

/// Kept in memory only, for tests, previews and demos.
final class InMemoryMedicationListStorage: MedicationListStorage {
    private(set) var entries: [MedicationEntry]?

    init(_ entries: [MedicationEntry]? = nil) {
        self.entries = entries
    }

    func load() -> [MedicationEntry]? { entries }
    func save(_ entries: [MedicationEntry]) { self.entries = entries }
}
