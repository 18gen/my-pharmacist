//
//  MedicationStoreTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MyPharmacist

/// Where a dose stands on Home, as `todaySlots` shows it.
@MainActor
private func state(of dose: Dose, in store: MedicationStore, now: Date) -> DoseState? {
    store.todaySlots(now: now).flatMap(\.items).first { $0.id == dose.id }?.state
}

@MainActor
struct MedicationStoreTests {
    private let morning = TestClock.at(8)

    private func makeStore(_ storage: any DoseLogStorage = InMemoryDoseLogStorage()) -> MedicationStore {
        MedicationStore(medications: TestMedications.all, logStorage: storage, calendar: TestClock.calendar, now: morning)
    }

    @Test func checkingPillsUsesTodaysScheduleAndChangesNothing() {
        let store = makeStore()
        let verdicts = store.verdicts(for: [TestMedications.metformin, nil], now: morning)
        #expect(verdicts == [.take(store.doses(on: morning).first { $0.id == "2026-10-14|metformin-500@8:00" }!), .unidentified])
        #expect(store.doses(on: morning).allSatisfy { state(of: $0, in: store, now: morning) == .pending })
    }

    @Test func aDoseIsDueNowOnlyWhileItsTimeOfDayIsNowAndNotTaken() {
        let store = makeStore()
        #expect(store.hasDoseDueNow(now: morning))
        // 12:00: the morning is past and not taken, the evening still to come.
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
        let store = MedicationStore(medications: [midnight], calendar: TestClock.calendar, now: morning)
        let lateEvening = TestClock.at(23, 30)
        // Today's 12 AM slot is long past; tomorrow's is due now and shows as well.
        #expect(store.todaySlots(now: lateEvening).map(\.status) == [.notTakenYet, .now])
        #expect(store.hasDoseDueNow(now: lateEvening))
        // A pill now counts for tomorrow's dose.
        guard case .take(let dose) = store.verdicts(for: [midnight], now: lateEvening).first else {
            Issue.record("Expected to take tomorrow's 12 AM dose")
            return
        }
        #expect(dose.id == "2026-10-15|midnight@0:00")
    }

    @Test func tomorrowsMidnightDoseStaysOnHomeOnceTicked() throws {
        let midnight = Medication(id: "midnight", name: "Midnight", strength: "1 mg", doseTimes: [DoseTime(0)])
        let store = MedicationStore(medications: [midnight], calendar: TestClock.calendar, now: morning)
        let lateEvening = TestClock.at(23, 30)
        let tonight = try #require(store.todaySlots(now: lateEvening).last)
        store.markTaken(tonight.items.map(\.dose), at: lateEvening)
        // It doesn't vanish under the finger: still there, done.
        #expect(store.todaySlots(now: lateEvening).map(\.status) == [.notTakenYet, .done(at: lateEvening)])
    }

    @Test func yesterdaysTimeOfDayLeavesHomeOnceItsWindowCloses() {
        let late = Medication(id: "late", name: "Late", strength: "1 mg", doseTimes: [DoseTime(23)])
        let store = MedicationStore(medications: [late], calendar: TestClock.calendar, now: morning)
        let tomorrow = TestClock.calendar.date(byAdding: .day, value: 1, to: TestClock.day)!
        // 12:30 AM: last night's 11 PM dose is still in its window.
        #expect(store.todaySlots(now: TestClock.at(0, 30, on: tomorrow)).map(\.status) == [.now, .next])
        // 1:30 AM: its window has closed; only tonight's is left.
        #expect(store.todaySlots(now: TestClock.at(1, 30, on: tomorrow)).map(\.status) == [.next])
    }

    @Test func aScanIsSavedAsTakenAndScanned() {
        let storage = InMemoryDoseLogStorage()
        let store = makeStore(storage)
        let dose = store.doses(on: morning)[0]
        store.recordScan(of: [dose], at: morning)
        // Saved under the dose's id, which starts with its day.
        #expect(storage.log == ["2026-10-14|lisinopril-10@8:00": morning, "taken|2026-10-14|lisinopril-10@8:00": morning])
        #expect(state(of: dose, in: makeStore(storage), now: morning) == .taken(at: morning, scannedAt: morning))
    }

    @Test func notTakenForgetsTheScanSoTheNextScanSaysToTakeIt() {
        let storage = InMemoryDoseLogStorage()
        let store = makeStore(storage)
        let dose = store.doses(on: morning).first { $0.medication == TestMedications.metformin }!
        store.recordScan(of: [dose], at: morning, photos: [dose: testImage()])
        #expect(store.verdicts(for: [TestMedications.metformin], now: TestClock.at(8, 5)) != [.take(dose)])

        store.markNotTaken([dose])
        #expect(storage.log.isEmpty)
        #expect(store.scanPhoto(of: dose) == nil)
        #expect(state(of: dose, in: store, now: TestClock.at(8, 5)) == .pending)
        #expect(store.verdicts(for: [TestMedications.metformin], now: TestClock.at(8, 5)) == [.take(dose)])
    }

    @Test func aScanSavedBeforeAScanCountedAsTakenLoadsAsTaken() {
        let dose = makeStore().doses(on: morning)[0]
        let storage = InMemoryDoseLogStorage([dose.id: morning])
        #expect(state(of: dose, in: makeStore(storage), now: TestClock.at(9)) == .taken(at: morning, scannedAt: morning))
    }

    @Test func recordsOlderThanTwoWeeksAreDroppedOnLaunch() {
        let old = TestClock.calendar.date(byAdding: .day, value: -15, to: morning)!
        let recent = TestClock.calendar.date(byAdding: .day, value: -13, to: morning)!
        let storage = InMemoryDoseLogStorage(["taken|old": old, "taken|recent": recent])

        let store = makeStore(storage)
        store.markTaken([store.doses(on: morning)[0]], at: morning)

        #expect(storage.log["taken|old"] == nil)
        #expect(storage.log["taken|recent"] == recent)
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
        MedicationStore(entries: entries, listStorage: list, photoStore: photoStore, calendar: TestClock.calendar, now: morning)
    }

    private func entry(_ name: String = "Metformin", times: [DoseTime] = [DoseTime(8)], photos: [MedicationPhoto] = []) -> MedicationEntry {
        MedicationEntry(name: name, strength: "500 mg", photos: photos, doseTimes: times)
    }

    @Test func aListThatWasNeverSavedStartsWithWhatIsGiven() {
        #expect(makeStore().medications.isEmpty)
        let store = makeStore(entries: SampleMedications.sampleList)
        #expect(store.entries == SampleMedications.sampleList.map(\.tidied))
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

    @Test func theListHoldsAsManyMedicationsAsOneCheckCanCompare() {
        let store = makeStore()
        for index in 0..<CheckLimits.medications {
            #expect(store.add(entry("Medication \(index)")))
        }
        #expect(!store.canAddMore)
        #expect(!store.add(entry("One too many")))
        #expect(store.entries.count == CheckLimits.medications)
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

    @Test func changingADoseTimeAfterTakingItKeepsTheTick() {
        let store = makeStore()
        var metformin = entry(times: [DoseTime(8), DoseTime(18)])
        store.add(metformin)
        let eight = store.doses(on: morning)[0]
        store.recordScan(of: [eight], at: TestClock.at(8, 2))

        metformin.doseTimes = [DoseTime(8, 30), DoseTime(18)]
        store.update(metformin, now: TestClock.at(8, 10))
        let halfPast = store.doses(on: morning)[0]
        #expect(halfPast.time == DoseTime(8, 30))
        #expect(state(of: halfPast, in: store, now: TestClock.at(8, 10)) == .taken(at: TestClock.at(8, 2), scannedAt: TestClock.at(8, 2)))
        // A pill of it isn't taken a second time.
        #expect(store.verdicts(for: [store.medications[0]], now: TestClock.at(8, 10)).first?.doseToTake == nil)
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
        #expect(!exists(photo, in: photos))
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
        #expect(!exists(old, in: photos))
        #expect(exists(new, in: photos))
    }

    @Test func photoFilesNoMedicationUsesAreRemoved() throws {
        let photos = temporaryPhotoStore()
        let kept = try photos.save(testImage(width: 8, height: 8))
        let leftOver = try photos.save(testImage(width: 8, height: 8))
        let store = makeStore(photoStore: photos)
        store.add(entry(photos: [kept]))
        store.removeUnusedPhotos()
        #expect(exists(kept, in: photos))
        #expect(!exists(leftOver, in: photos))
    }

    @Test func resettingTheDemoLeavesTheSampleListWithNothingTaken() throws {
        let photos = temporaryPhotoStore()
        let photo = try photos.save(testImage(width: 8, height: 8))
        let store = makeStore(entries: SampleMedications.sampleList, photoStore: photos)
        store.add(entry(photos: [photo]))
        let doses = store.doses(on: morning)
        store.recordScan(of: doses, at: morning, photos: Dictionary(uniqueKeysWithValues: doses.map { ($0, testImage()) }))
        let ondansetron = try #require(store.asNeededMedications.first)
        store.markAsNeededTaken(ondansetron, on: morning, at: morning)

        store.resetToSamples()
        #expect(store.entries == SampleMedications.sampleList.map(\.tidied))
        #expect(store.medications.map(\.doseTimes) == [[DoseTime(12, 30), DoseTime(20)], [DoseTime(12, 30)], [DoseTime(20)], []])
        #expect(store.doses(on: morning).allSatisfy { state(of: $0, in: store, now: morning) == .pending && store.scanPhoto(of: $0) == nil })
        #expect(store.asNeededTaken(of: ondansetron, on: morning) == nil)
        #expect(!exists(photo, in: photos))
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

    private func exists(_ photo: MedicationPhoto, in photos: MedicationPhotoStore) -> Bool {
        guard case .file(let name) = photo else { return false }
        return FileManager.default.fileExists(atPath: photos.directory.appending(path: name).path)
    }
}

/// Doses ticked by hand, and medications taken only when needed.
@MainActor
struct TakenDoseStoreTests {
    private let morning = TestClock.at(8)

    private func makeStore(_ storage: any DoseLogStorage = InMemoryDoseLogStorage()) -> MedicationStore {
        MedicationStore(medications: TestMedications.all + [TestMedications.ondansetron], logStorage: storage,
                        calendar: TestClock.calendar, now: morning)
    }

    @Test func aDoseCanBeTickedWithoutAScanAndIsThenNotTakenAgain() {
        let storage = InMemoryDoseLogStorage()
        let store = makeStore(storage)
        let dose = store.doses(on: morning)[0]
        let later = TestClock.at(8, 10)
        store.markTaken([dose], at: later)
        #expect(storage.log == ["taken|" + dose.id: later])

        let reloaded = makeStore(storage)
        #expect(state(of: dose, in: reloaded, now: later) == .taken(at: later, scannedAt: nil))
        guard case .alreadyTaken(let taken, let time, _) = reloaded.verdicts(for: [dose.medication], now: later)[0] else {
            Issue.record("A pill of a dose marked taken should not be OK to take")
            return
        }
        #expect(taken == dose && time == later)
    }

    @Test func scanPhotosAreKeptInMemoryOnlyAndGoWithNotTaken() {
        let storage = InMemoryDoseLogStorage()
        let store = makeStore(storage)
        let dose = store.doses(on: morning)[0]
        let photo = testImage()
        store.recordScan(of: [dose], at: morning, photos: [dose: photo])
        #expect(store.scanPhoto(of: dose) === photo)
        // Not saved: a store opened again has the scan but not its picture.
        #expect(makeStore(storage).scanPhoto(of: dose) == nil)
        store.markNotTaken([dose])
        #expect(store.scanPhoto(of: dose) == nil)
    }

    @Test func aMedicationTakenWhenNeededIsRecordedByDay() {
        let store = makeStore()
        let ondansetron = TestMedications.ondansetron
        let photo = testImage()
        store.recordAsNeededScan(of: ondansetron, at: morning, photo: photo)
        #expect(store.asNeededTaken(of: ondansetron, on: morning) == morning)
        #expect(store.asNeededScan(of: ondansetron, on: morning) == morning)
        #expect(store.asNeededScanPhoto(of: ondansetron, on: morning) === photo)
        // Another day knows nothing of it.
        let tomorrow = TestClock.calendar.date(byAdding: .day, value: 1, to: morning)!
        #expect(store.asNeededTaken(of: ondansetron, on: tomorrow) == nil)

        store.markAsNeededNotTaken(ondansetron, on: morning)
        #expect(store.asNeededTaken(of: ondansetron, on: morning) == nil)
        #expect(store.asNeededScan(of: ondansetron, on: morning) == nil)
        #expect(store.asNeededScanPhoto(of: ondansetron, on: morning) == nil)
    }

    @Test func tickingWhenNeededGoesOnTheDayShown() {
        let store = makeStore()
        let ondansetron = TestMedications.ondansetron
        // Just past midnight, the box still shows the day before.
        let lateEvening = TestClock.at(23, 59)
        let pastMidnight = TestClock.calendar.date(byAdding: .minute, value: 2, to: lateEvening)!
        store.markAsNeededTaken(ondansetron, on: lateEvening, at: pastMidnight)
        #expect(store.asNeededTaken(of: ondansetron, on: lateEvening) == pastMidnight)
    }
}

struct MedicationEntryTests {
    @Test func anEntrySavedBeforeDirectionsStillLoads() throws {
        let saved = """
        {"id":"x","name":"Capecitabine","strength":"500 mg","purpose":"Cancer treatment","appearance":"",
         "photos":[],"doseTimes":[],"isAsNeeded":true,"asNeededNote":""}
        """
        let entry = try JSONDecoder().decode(MedicationEntry.self, from: Data(saved.utf8))
        #expect(entry.name == "Capecitabine" && entry.directions.isEmpty)
    }

    @Test func directionsAreSavedAndReachTheMedication() throws {
        let entry = MedicationEntry(name: "Capecitabine", directions: "  With water, after a meal.  ").tidied
        let loaded = try JSONDecoder().decode(MedicationEntry.self, from: JSONEncoder().encode(entry))
        #expect(loaded.medication.directions == "With water, after a meal.")
    }

    @Test func theSampleMedicationsHaveDirections() {
        #expect(SampleMedications.sampleList.allSatisfy { !$0.directions.isEmpty })
    }
}
