//
//  MedicationStoreRecordTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

/// What sharing with the pharmacy demo reads from the store: each dose's state on any day,
/// a call after every change, and a reset to a given list.
@MainActor
struct MedicationStoreRecordTests {
    private let morning = TestClock.at(8)

    private func makeStore() -> MedicationStore {
        MedicationStore(medications: TestMedications.all, calendar: TestClock.calendar, now: morning)
    }

    private func dose(_ id: String, in store: MedicationStore, on day: Date) -> Dose {
        store.doses(on: day).first { $0.id == id }!
    }

    @Test func aDoseIsPendingUntilTakenAndKnowsWhetherItWasScanned() {
        let store = makeStore()
        let metformin = dose("2026-10-14|metformin-500@8:00", in: store, on: morning)
        let lisinopril = dose("2026-10-14|lisinopril-10@8:00", in: store, on: morning)
        #expect(store.state(of: metformin) == .pending)

        let scanned = morning.addingTimeInterval(5 * 60)
        store.recordScan(of: [metformin], at: scanned)
        store.markTaken([lisinopril], at: scanned)
        #expect(store.state(of: metformin) == .taken(at: scanned, scannedAt: scanned))
        #expect(store.state(of: lisinopril) == .taken(at: scanned, scannedAt: nil))

        store.markNotTaken([metformin])
        #expect(store.state(of: metformin) == .pending)
    }

    @Test func earlierDaysKeepTheirRecord() {
        let store = makeStore()
        let yesterday = TestClock.calendar.date(byAdding: .day, value: -1, to: morning)!
        let dose = dose("2026-10-13|metformin-500@18:00", in: store, on: yesterday)
        let taken = TestClock.at(18, 12, on: yesterday)
        store.markTaken([dose], at: taken)
        #expect(store.state(of: dose) == .taken(at: taken, scannedAt: nil))
    }

    @Test func everyChangeToTheListOrTheRecordIsReported() {
        let store = makeStore()
        var changes = 0
        store.onChange = { changes += 1 }

        store.markTaken([dose("2026-10-14|metformin-500@8:00", in: store, on: morning)], at: morning)
        #expect(changes == 1)
        store.add(MedicationEntry(TestMedications.ondansetron))
        #expect(changes == 2)
        store.markAsNeededTaken(TestMedications.ondansetron, on: morning, at: morning)
        #expect(changes == 3)
        store.remove(TestMedications.ondansetron.id)
        #expect(changes == 4)
    }

    @Test func resettingToAListReplacesItAndForgetsEveryDose() {
        let store = makeStore()
        store.recordScan(of: store.doses(on: morning), at: morning)
        var moved = MedicationEntry(TestMedications.atorvastatin)
        moved.doseTimes = [DoseTime(9, 30)]

        store.reset(to: [moved])
        #expect(store.medications.map(\.id) == ["atorvastatin-20"])
        #expect(store.medications.first?.doseTimes == [DoseTime(9, 30)])
        #expect(store.doses(on: morning).allSatisfy { store.state(of: $0) == .pending })
    }
}
