//
//  MedicationStoreTests.swift
//  MedLensTests
//

import Foundation
import Testing
@testable import MedLens

@MainActor
struct MedicationStoreTests {
    private let morning = TestClock.at(8)

    private func makeStore(_ storage: any DoseLogStorage = InMemoryDoseLogStorage()) -> MedicationStore {
        MedicationStore(storage: storage, calendar: TestClock.calendar, now: morning)
    }

    @Test func scanningARegisteredLabelMarksTheDoseTaken() {
        let store = makeStore()
        let outcome = store.recordScan(scannedName: "METFORMIN HCL 500 MG", now: morning)

        guard case .checked(let dose) = outcome else {
            Issue.record("Expected a checked dose, got \(outcome)")
            return
        }
        #expect(dose.id == "metformin-500@8:00")
        #expect(store.todayList(now: morning).first { $0.id == dose.id }?.state == .taken(at: morning))
    }

    @Test func unknownAndAmbiguousLabelsChangeNothing() {
        let store = makeStore()
        #expect(store.recordScan(scannedName: "IBUPROFEN 200 MG", now: morning) == .notOnList(scannedName: "IBUPROFEN 200 MG"))
        #expect(!store.todayList(now: morning).contains { $0.state.isTaken })
    }

    @Test func takenDosesAreSavedAndCanBeUndone() {
        let storage = InMemoryDoseLogStorage()
        let store = makeStore(storage)
        let dose = store.doses(on: morning)[0]
        store.markTaken(dose, at: morning)
        #expect(storage.log == ["2026-10-14|\(dose.id)": morning])

        let reloaded = makeStore(storage)
        #expect(reloaded.todayList(now: morning).first { $0.id == dose.id }?.state == .taken(at: morning))

        reloaded.markNotTaken(dose)
        #expect(storage.log.isEmpty)
    }

    @Test func recordsOlderThanTwoWeeksAreDroppedOnLaunch() {
        let old = TestClock.calendar.date(byAdding: .day, value: -15, to: morning)!
        let recent = TestClock.calendar.date(byAdding: .day, value: -13, to: morning)!
        let storage = InMemoryDoseLogStorage(["old": old, "recent": recent])

        let store = makeStore(storage)
        store.markTaken(store.doses(on: morning)[0], at: morning)

        #expect(storage.log["old"] == nil)
        #expect(storage.log["recent"] == recent)
    }

    @Test func userDefaultsStorageKeepsTheSavedFormat() {
        let defaults = isolatedDefaults()
        let storage = UserDefaultsDoseLogStorage(defaults: defaults)
        storage.save(["2026-10-14|metformin-500@8:00": morning])

        // Same key and seconds-since-1970 values as earlier versions, so existing data still loads.
        let raw = defaults.dictionary(forKey: "takenDoses") as? [String: Double]
        #expect(raw == ["2026-10-14|metformin-500@8:00": morning.timeIntervalSince1970])
        #expect(storage.load() == ["2026-10-14|metformin-500@8:00": morning])
    }
}
