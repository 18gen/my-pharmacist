//
//  MedicationListStorage.swift
//  MyPharmacist
//

import Foundation

/// Where the person's medication list is kept. `MedicationStore` decides what goes in it;
/// this only loads and saves.
protocol MedicationListStorage {
    /// Nil when nothing was saved yet, so the list starts from the catalog. An empty list
    /// is a list the person emptied.
    func load() -> [MedicationPlan]?
    func save(_ plans: [MedicationPlan])
}

/// Saved on the device in UserDefaults, as JSON under "medicationList".
struct UserDefaultsMedicationListStorage: MedicationListStorage {
    private static let key = "medicationList"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [MedicationPlan]? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode([MedicationPlan].self, from: data)
    }

    func save(_ plans: [MedicationPlan]) {
        if let data = try? JSONEncoder().encode(plans) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

/// Kept in memory only, for tests and previews.
final class InMemoryMedicationListStorage: MedicationListStorage {
    private(set) var plans: [MedicationPlan]?

    init(_ plans: [MedicationPlan]? = nil) {
        self.plans = plans
    }

    func load() -> [MedicationPlan]? { plans }
    func save(_ plans: [MedicationPlan]) { self.plans = plans }
}
