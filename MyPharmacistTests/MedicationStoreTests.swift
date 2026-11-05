//
//  MedicationStoreTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

@MainActor
struct MedicationStoreTests {
    private let morning = TestClock.at(8)

    private func makeStore(_ storage: any DoseLogStorage = InMemoryDoseLogStorage()) -> MedicationStore {
        MedicationStore(medications: TestMedications.all, storage: storage, calendar: TestClock.calendar, now: morning)
    }

    @Test func checkingPillsUsesTodaysSchedule() {
        let store = makeStore()
        let check = store.check([TestMedications.metformin, nil], now: morning)
        #expect(check.verdicts == [.take(store.doses(on: morning).first { $0.id == "metformin-500@8:00" }!), .unidentified])
        #expect(check.missing.map(\.id) == ["lisinopril-10@8:00"])
        // Checking alone changes nothing.
        #expect(!store.todayList(now: morning).contains { $0.state.isScanned })
    }

    @Test func scannedDosesAreSavedAndCanBeRemoved() {
        let storage = InMemoryDoseLogStorage()
        let store = makeStore(storage)
        let dose = store.doses(on: morning)[0]
        store.recordScan(of: [dose], at: morning)
        #expect(storage.log == ["2026-10-14|\(dose.id)": morning])

        let reloaded = makeStore(storage)
        #expect(reloaded.todayList(now: morning).first { $0.id == dose.id }?.state == .scanned(at: morning))

        reloaded.removeScans(of: [dose])
        #expect(storage.log.isEmpty)
    }

    @Test func recordsOlderThanTwoWeeksAreDroppedOnLaunch() {
        let old = TestClock.calendar.date(byAdding: .day, value: -15, to: morning)!
        let recent = TestClock.calendar.date(byAdding: .day, value: -13, to: morning)!
        let storage = InMemoryDoseLogStorage(["old": old, "recent": recent])

        let store = makeStore(storage)
        store.recordScan(of: [store.doses(on: morning)[0]], at: morning)

        #expect(storage.log["old"] == nil)
        #expect(storage.log["recent"] == recent)
    }

    @Test func userDefaultsStorageKeepsTheSavedFormat() {
        let defaults = isolatedDefaults()
        let storage = UserDefaultsDoseLogStorage(defaults: defaults)
        storage.save(["2026-10-14|metformin-500@8:00": morning])

        // Seconds since 1970 under one key, readable without the app's types.
        let raw = defaults.dictionary(forKey: "scannedDoses") as? [String: Double]
        #expect(raw == ["2026-10-14|metformin-500@8:00": morning.timeIntervalSince1970])
        #expect(storage.load() == ["2026-10-14|metformin-500@8:00": morning])
    }
}

@MainActor
struct MedicationListTests {
    private let morning = TestClock.at(8)
    private let catalog = TestMedications.all + [TestMedications.ondansetron]

    private func makeStore(_ list: InMemoryMedicationListStorage = InMemoryMedicationListStorage()) -> MedicationStore {
        MedicationStore(medications: catalog, listStorage: list, storage: InMemoryDoseLogStorage(),
                        calendar: TestClock.calendar, now: morning)
    }

    @Test func aNewListHasTheWholeCatalogAtItsUsualTimes() {
        let store = makeStore()
        #expect(store.medications == catalog)
        #expect(store.addable.isEmpty)
    }

    @Test func removedMedicationsCanBeAddedBackAndTheListIsSaved() {
        let list = InMemoryMedicationListStorage()
        let store = makeStore(list)
        store.remove(TestMedications.lisinopril.id)
        #expect(!store.medications.contains(TestMedications.lisinopril))
        #expect(store.addable == [TestMedications.lisinopril])

        store.add(MedicationPlan(medicationID: TestMedications.lisinopril.id, doseTimes: [DoseTime(9)], isAsNeeded: false))
        #expect(store.medications.last?.id == TestMedications.lisinopril.id)
        #expect(store.medications.last?.doseTimes == [DoseTime(9)])

        // A store reading the same saved list sees the same medications.
        #expect(makeStore(list).medications == store.medications)
    }

    @Test func anEmptiedListStaysEmpty() {
        let list = InMemoryMedicationListStorage()
        let store = makeStore(list)
        for medication in catalog { store.remove(medication.id) }
        #expect(makeStore(list).medications.isEmpty)
    }

    @Test func changingTheTimesMovesTheDoses() {
        let store = makeStore()
        store.update(MedicationPlan(medicationID: TestMedications.metformin.id,
                                    doseTimes: [DoseTime(21), DoseTime(7, 30), DoseTime(21)], isAsNeeded: false))
        // In order, each once.
        #expect(store.plan(for: TestMedications.metformin.id)?.doseTimes == [DoseTime(7, 30), DoseTime(21)])
        #expect(store.doses(on: morning).filter { $0.medication.id == TestMedications.metformin.id }.map(\.id)
                == ["metformin-500@7:30", "metformin-500@21:00"])
    }

    @Test func setTimesWithNoneAreIgnored() {
        let store = makeStore()
        store.update(MedicationPlan(medicationID: TestMedications.metformin.id, doseTimes: [], isAsNeeded: false))
        #expect(store.plan(for: TestMedications.metformin.id)?.doseTimes == [DoseTime(8), DoseTime(18)])
    }

    @Test func onlyWhenNeededKeepsTheTimesForLater() {
        let store = makeStore()
        let times = [DoseTime(8), DoseTime(18)]
        store.update(MedicationPlan(medicationID: TestMedications.metformin.id, doseTimes: times, isAsNeeded: true))
        let asNeeded = store.medications.first { $0.id == TestMedications.metformin.id }
        #expect(asNeeded?.doseTimes == [])
        #expect(asNeeded?.asNeeded == MedicationStore.defaultAsNeeded)
        #expect(store.asNeededMedications.map(\.id).contains(TestMedications.metformin.id))

        store.update(MedicationPlan(medicationID: TestMedications.metformin.id, doseTimes: times, isAsNeeded: false))
        #expect(store.medications.first { $0.id == TestMedications.metformin.id }?.doseTimes == times)
    }

    @Test func anAsNeededMedicationKeepsItsOwnWords() {
        let store = makeStore()
        #expect(store.medications.first { $0.id == TestMedications.ondansetron.id }?.asNeeded == "Only when you feel sick")
        // Switched to set times, it starts with a morning dose.
        #expect(store.plan(for: TestMedications.ondansetron.id)?.doseTimes == [DoseTime(8)])
    }

    @Test func restoringBringsBackTheWholeCatalog() {
        let store = makeStore()
        store.remove(TestMedications.metformin.id)
        store.update(MedicationPlan(medicationID: TestMedications.lisinopril.id, doseTimes: [DoseTime(10)], isAsNeeded: false))
        store.restoreSampleList()
        #expect(store.medications == catalog)
    }

    @Test func userDefaultsListStorageRoundTrips() {
        let storage = UserDefaultsMedicationListStorage(defaults: isolatedDefaults())
        #expect(storage.load() == nil)
        let plans = [MedicationPlan(medicationID: "metformin-500", doseTimes: [DoseTime(8), DoseTime(18, 30)], isAsNeeded: false)]
        storage.save(plans)
        #expect(storage.load() == plans)
    }
}

