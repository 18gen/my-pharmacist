//
//  ScanSessionRecord.swift
//  MyPharmacist
//

import Foundation

/// What one scanning session (from opening the camera to closing it) marked taken.
///
/// When the person takes the photo again, its pills are judged as if this session hadn't
/// marked anything, so the same pill still says to take it. Only what shows up OK again
/// is recorded again: a dose marked taken by the first photo whose pill isn't in the
/// second (it was swallowed in between, say) keeps its tick.
nonisolated struct ScanSessionRecord: Equatable, Sendable {
    private(set) var doses: Set<Dose> = []
    /// Medications taken only when needed, by ID, with the day each was marked taken on.
    private(set) var asNeeded: [AsNeeded] = []

    struct AsNeeded: Equatable, Sendable {
        let medicationID: String
        let day: Date
    }

    var isEmpty: Bool { doses.isEmpty && asNeeded.isEmpty }

    mutating func add(_ doses: [Dose]) {
        self.doses.formUnion(doses)
    }

    mutating func add(asNeeded medicationID: String, on day: Date) {
        asNeeded.append(AsNeeded(medicationID: medicationID, day: day))
    }

    /// Where everything recorded is kept in `DoseLog`.
    func keys(calendar: Calendar) -> [DoseLog.Key] {
        doses.map(DoseLog.Key.dose) + asNeeded.map { .asNeeded($0.medicationID, on: $0.day, calendar: calendar) }
    }
}
