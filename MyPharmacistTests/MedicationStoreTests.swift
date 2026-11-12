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
        #expect(check.verdicts == [.take(store.doses(on: morning).first { $0.id == "2026-10-14|metformin-500@8:00" }!), .unidentified])
        #expect(check.missing.map(\.id) == ["2026-10-14|lisinopril-10@8:00"])
        // Checking alone changes nothing.
        #expect(!store.todayList(now: morning).contains { $0.state.isScanned })
    }

    @Test func aDoseIsDueNowOnlyWhileItsTimeOfDayIsNowAndNotScanned() {
        let store = makeStore()
        #expect(store.hasDoseDueNow(now: morning))
        // 12:00: the morning is past and not scanned, the evening still to come.
        #expect(!store.hasDoseDueNow(now: TestClock.at(12)))
        store.recordScan(of: store.doses(on: morning).filter { $0.time == DoseTime(8) }, at: morning)
        #expect(!store.hasDoseDueNow(now: TestClock.at(8, 30)))
    }

    @Test func onlyTheTimeOfDayToTakeNowIsOpen() {
        let slots = makeStore().todaySlots(now: morning)
        #expect(slots.map(\.status.isFolded) == [false, true, true])
    }

    @Test func justBeforeMidnightTheMidnightDoseIsDueNow() {
        let midnight = Medication(id: "midnight", name: "Midnight", strength: "1 mg", doseTimes: [DoseTime(0)])
        let store = MedicationStore(medications: [midnight], storage: InMemoryDoseLogStorage(), calendar: TestClock.calendar,
                                    now: morning)
        let lateEvening = TestClock.at(23, 30)
        // Today's 12 AM slot is long past; tomorrow's is due now and shows as well.
        let slots = store.todaySlots(now: lateEvening)
        #expect(slots.map(\.status) == [.notScannedYet, .now])
        #expect(store.hasDoseDueNow(now: lateEvening))
        // A pill now counts for tomorrow's dose.
        let check = store.check([midnight], now: lateEvening)
        guard case .take(let dose) = check.verdicts.first else {
            Issue.record("Expected to take tomorrow's 12 AM dose, got \(check.verdicts)")
            return
        }
        #expect(dose.id == "2026-10-15|midnight@0:00")
    }

    @Test func scannedDosesAreSavedAndCanBeRemoved() {
        let storage = InMemoryDoseLogStorage()
        let store = makeStore(storage)
        let dose = store.doses(on: morning)[0]
        store.recordScan(of: [dose], at: morning)
        // Saved under the dose's id, which starts with its day.
        #expect(storage.log == ["2026-10-14|lisinopril-10@8:00": morning])
        #expect(dose.id == "2026-10-14|lisinopril-10@8:00")

        let reloaded = makeStore(storage)
        #expect(reloaded.todayList(now: morning).first { $0.id == dose.id }?.state == .scanned(at: morning))

        reloaded.removeScans(of: [dose])
        #expect(storage.log.isEmpty)
    }

    @Test func resettingScansForgetsThemAllAndKeepsTheList() {
        let storage = InMemoryDoseLogStorage()
        let store = makeStore(storage)
        store.recordScan(of: store.doses(on: morning), at: morning)
        #expect(store.todayList(now: morning).contains { $0.state.isScanned })

        store.clearScans()
        #expect(storage.log.isEmpty)
        #expect(!store.todayList(now: morning).contains { $0.state.isScanned })
        #expect(store.medications == TestMedications.all)
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

    private func makeStore(_ list: InMemoryMedicationListStorage = InMemoryMedicationListStorage(),
                           entries: [MedicationEntry] = [], photoStore: MedicationPhotoStore = temporaryPhotoStore()) -> MedicationStore {
        MedicationStore(entries: entries, listStorage: list, storage: InMemoryDoseLogStorage(), photoStore: photoStore,
                        calendar: TestClock.calendar, now: morning)
    }

    private func entry(_ name: String = "Metformin", times: [DoseTime] = [DoseTime(8)], photos: [MedicationPhoto] = []) -> MedicationEntry {
        MedicationEntry(name: name, strength: "500 mg", photos: photos, doseTimes: times)
    }

    @Test func aNewPersonStartsWithAnEmptyList() {
        #expect(makeStore().medications.isEmpty)
    }

    @Test func aSavedListIsWhatLoads() {
        let saved = entry()
        let store = makeStore(InMemoryMedicationListStorage([saved]), entries: [entry("Something else")])
        #expect(store.entries == [saved])
    }

    @Test func aMedicationNeedsANameAndTimesUnlessTakenWhenNeeded() {
        let list = InMemoryMedicationListStorage()
        let store = makeStore(list)
        #expect(!store.add(entry("   ")))
        #expect(!store.add(entry(times: [])))
        var asNeeded = entry(times: [])
        asNeeded.isAsNeeded = true
        #expect(store.add(asNeeded))
        let metformin = entry()
        #expect(store.add(metformin))
        // The same one twice is still one.
        #expect(!store.add(metformin))
        #expect(list.entries?.count == 2)
    }

    @Test func aMedicationIsSavedTidy() {
        let store = makeStore()
        store.add(entry("  Metformin ", times: [DoseTime(21), DoseTime(7, 30), DoseTime(21)]))
        #expect(store.entries[0].name == "Metformin")
        #expect(store.medications[0].doseTimes == [DoseTime(7, 30), DoseTime(21)])
        #expect(store.doses(on: morning).map(\.id) == ["2026-10-14|\(store.entries[0].id)@7:30", "2026-10-14|\(store.entries[0].id)@21:00"])
    }

    @Test func aMedicationNeverSilentlyStopsBeingDue() {
        let store = makeStore()
        let metformin = entry(times: [DoseTime(8), DoseTime(18)])
        store.add(metformin)
        var noTimes = metformin
        noTimes.doseTimes = []
        store.update(noTimes)
        #expect(store.medications[0].doseTimes == [DoseTime(8), DoseTime(18)])
    }

    @Test func onlyWhenNeededKeepsTheTimesForLater() {
        let store = makeStore()
        var metformin = entry(times: [DoseTime(8), DoseTime(18)])
        store.add(metformin)
        metformin.isAsNeeded = true
        store.update(metformin)
        #expect(store.medications[0].doseTimes == [])
        #expect(store.medications[0].asNeeded == MedicationEntry.defaultAsNeeded)
        #expect(store.asNeededMedications.map(\.id) == [metformin.id])
        // Back to set times: the times are still there.
        metformin.isAsNeeded = false
        store.update(metformin)
        #expect(store.medications[0].doseTimes == [DoseTime(8), DoseTime(18)])
    }

    @Test func anAsNeededMedicationKeepsItsOwnWords() {
        let store = makeStore(entries: [MedicationEntry(TestMedications.ondansetron)])
        #expect(store.medications[0].asNeeded == "Only when you feel sick")
        #expect(store.entries[0].doseTimes == [DoseTime(8)])
    }

    @Test func removingAMedicationDeletesItsPhotos() throws {
        let photos = temporaryPhotoStore()
        let photo = try photos.save(testImage(width: 8, height: 8))
        let store = makeStore(photoStore: photos)
        let metformin = entry(photos: [photo, .asset("exemestane-25-1")])
        store.add(metformin)
        #expect(photos.image(photo) != nil)
        store.remove(metformin.id)
        #expect(store.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: photos.directory.appending(path: fileName(photo)).path))
    }

    @Test func replacingAPhotoDeletesTheOldOne() throws {
        let photos = temporaryPhotoStore()
        let old = try photos.save(testImage(width: 8, height: 8))
        let new = try photos.save(testImage(width: 8, height: 8))
        let store = makeStore(photoStore: photos)
        var metformin = entry(photos: [old])
        store.add(metformin)
        metformin.photos = [new]
        store.update(metformin)
        #expect(!FileManager.default.fileExists(atPath: photos.directory.appending(path: fileName(old)).path))
        #expect(FileManager.default.fileExists(atPath: photos.directory.appending(path: fileName(new)).path))
    }

    @Test func loadingTheSampleListReplacesTheList() throws {
        let photos = temporaryPhotoStore()
        let photo = try photos.save(testImage(width: 8, height: 8))
        let store = makeStore(photoStore: photos)
        store.add(entry(photos: [photo]))
        store.loadSampleList()
        #expect(store.medications.map(\.id) == ["capecitabine-500", "dexamethasone-4", "allopurinol-300", "ondansetron-8"])
        #expect(store.medications.map(\.doseTimes) == [[DoseTime(12, 30), DoseTime(20)], [DoseTime(12, 30)], [DoseTime(20)], []])
        #expect(store.asNeededMedications.map(\.id) == ["ondansetron-8"])
        #expect(!FileManager.default.fileExists(atPath: photos.directory.appending(path: fileName(photo)).path))
    }

    @Test func midnightIsBedtimeNotMorning() {
        #expect(DayPeriod(DoseTime(0)).name == "Bedtime")
        #expect(DayPeriod(DoseTime(4, 59)).name == "Bedtime")
        #expect(DayPeriod(DoseTime(5)).name == "Morning")
        #expect(DayPeriod(DoseTime(22)).name == "Bedtime")
    }

    @Test func userDefaultsListStorageRoundTrips() {
        let storage = UserDefaultsMedicationListStorage(defaults: isolatedDefaults())
        #expect(storage.load() == nil)
        let entries = [
            MedicationEntry(name: "Metformin", photos: [.file("a.png"), .asset("exemestane-25-1")],
                            doseTimes: [DoseTime(8), DoseTime(18, 30)]),
            MedicationEntry(name: "Ondansetron", doseTimes: [DoseTime(8)], isAsNeeded: true, asNeededNote: "When sick"),
        ]
        storage.save(entries)
        #expect(storage.load() == entries)
    }

    private func fileName(_ photo: MedicationPhoto) -> String {
        if case .file(let name) = photo { name } else { "" }
    }
}
