//
//  MedicationPlan.swift
//  MyPharmacist
//

import Foundation

/// One medication on the person's list: which one from the catalog, and when it's taken.
/// Everything else (name, strength, photos) comes from the catalog.
nonisolated struct MedicationPlan: Identifiable, Hashable, Codable, Sendable {
    let medicationID: String
    /// Kept while it's taken only when needed, so switching back brings them back.
    var doseTimes: [DoseTime]
    var isAsNeeded: Bool

    var id: String { medicationID }

    init(medicationID: String, doseTimes: [DoseTime], isAsNeeded: Bool) {
        self.medicationID = medicationID
        self.doseTimes = doseTimes
        self.isAsNeeded = isAsNeeded
    }

    /// How a catalog medication starts out: its usual times, or only when needed. One taken
    /// only when needed gets a morning time to start from if it's switched to set times.
    init(preset: Medication) {
        self.init(medicationID: preset.id,
                  doseTimes: preset.doseTimes.isEmpty ? [DoseTime(8)] : preset.doseTimes,
                  isAsNeeded: preset.asNeeded != nil)
    }

    /// The times in order, each once: two doses at the same time would be the same dose.
    var orderedTimes: [DoseTime] {
        Array(Set(doseTimes)).sorted()
    }
}
