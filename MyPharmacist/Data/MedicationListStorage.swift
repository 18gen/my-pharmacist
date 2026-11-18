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

    /// A list that can't be read loads as empty rather than as the samples: the person
    /// had a list of their own, which is kept aside (`UserDefaults.saved`).
    func load() -> [MedicationEntry]? {
        switch defaults.saved([MedicationEntry].self, forKey: Self.key) {
        case .none: nil
        case .value(let entries): entries
        case .unreadable: []
        }
    }

    func save(_ entries: [MedicationEntry]) {
        defaults.save(entries, forKey: Self.key)
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
