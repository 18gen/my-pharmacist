//
//  SampleWeekTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

/// "Reset demo → With a sample week": a dose due now, and the same week every time.
@MainActor
struct SampleWeekTests {
    private let calendar = TestClock.calendar

    private func made(at now: Date) -> (store: MedicationStore, reports: ScanReports) {
        let store = MedicationStore(entries: SampleMedications.sampleList, calendar: calendar, now: now)
        let reports = ScanReports(calendar: calendar, now: now)
        SampleWeek.fill(store, reports: reports, now: now)
        return (store, reports)
    }

    private func day(_ offset: Int, from now: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    @Test func movesTheTimesSoADoseIsDueNow() {
        #expect(SampleWeek.times(at: TestClock.at(14, 12), calendar: calendar)
                == SampleWeek.Times(first: DoseTime(8, 10), second: DoseTime(14, 10), firstIsEarlierToday: true))
        #expect(SampleWeek.times(at: TestClock.at(10, 32), calendar: calendar)
                == SampleWeek.Times(first: DoseTime(10, 30), second: DoseTime(16, 30), firstIsEarlierToday: false))
        #expect(SampleWeek.times(at: TestClock.at(0, 3), calendar: calendar)
                == SampleWeek.Times(first: DoseTime(0, 0), second: DoseTime(6, 0), firstIsEarlierToday: false))
        #expect(SampleWeek.times(at: TestClock.at(23, 58), calendar: calendar)
                == SampleWeek.Times(first: DoseTime(17, 55), second: DoseTime(23, 55), firstIsEarlierToday: true))
    }

    @Test func theSampleListKeepsItsPairsAtTheMovedTimes() {
        let times = SampleWeek.Times(first: DoseTime(8, 10), second: DoseTime(14, 10), firstIsEarlierToday: true)
        let list = Dictionary(uniqueKeysWithValues: SampleWeek.list(times: times).map { ($0.id, $0.medication) })
        #expect(list["capecitabine-500"]?.doseTimes == [DoseTime(8, 10), DoseTime(14, 10)])
        #expect(list["dexamethasone-4"]?.doseTimes == [DoseTime(8, 10)])
        #expect(list["allopurinol-300"]?.doseTimes == [DoseTime(14, 10)])
        #expect(list["ondansetron-8"]?.asNeeded != nil)
    }

    @Test func fromNoonTheMorningIsTakenAndTheAfternoonDueNow() {
        let now = TestClock.at(14, 12)
        let (store, _) = made(at: now)
        #expect(store.hasDoseDueNow(now: now))
        let today = store.doses(on: now)
        #expect(today.filter { $0.time == DoseTime(8, 10) }.allSatisfy { store.state(of: $0) == .taken(at: TestClock.at(8, 14), scannedAt: TestClock.at(8, 14)) })
        #expect(today.filter { $0.time == DoseTime(14, 10) }.allSatisfy { store.state(of: $0) == .pending })
    }

    @Test func beforeNoonTheFirstIsDueNowAndNothingIsTakenToday() {
        let now = TestClock.at(10, 32)
        let (store, _) = made(at: now)
        #expect(store.hasDoseDueNow(now: now))
        #expect(store.doses(on: now).allSatisfy { store.state(of: $0) == .pending })
    }

    @Test func theWeekBeforeHasItsThreeMissedDoses() {
        let now = TestClock.at(14, 12)
        let (store, _) = made(at: now)
        let missed = (-6 ... -1).flatMap { offset in
            store.doses(on: day(offset, from: now)).filter { store.state(of: $0) == .pending }.map { "\(offset) \($0.medication.id)" }
        }
        #expect(missed.sorted() == ["-2 dexamethasone-4", "-4 allopurinol-300", "-4 capecitabine-500"])
        let ticked = store.doses(on: day(-5, from: now)).filter { $0.time == DoseTime(8, 10) }
        #expect(ticked.allSatisfy { store.state(of: $0).scannedAt == nil && store.state(of: $0).takenAt != nil })
    }

    @Test func theWeekHasItsScansAndWhenNeededTablets() {
        let now = TestClock.at(14, 12)
        let (store, reports) = made(at: now)
        #expect(reports.reports.map { $0.pills.map(\.outcome) } == [[.tooEarly], [.alreadyTaken], [.unknown]])
        #expect(reports.reports[0].pills[0].doseTime == DoseTime(14, 10))
        let ondansetron = SampleMedications.sampleList.first { $0.id == "ondansetron-8" }!.medication
        #expect(store.asNeededTaken(of: ondansetron, on: day(-5, from: now)) != nil)
        #expect(store.asNeededTaken(of: ondansetron, on: day(-1, from: now)) != nil)
        #expect(store.asNeededTaken(of: ondansetron, on: day(-3, from: now)) == nil)
    }

    @Test func everySampleWeekIsTheSame() {
        let now = TestClock.at(14, 12)
        let (first, firstReports) = made(at: now)
        let (second, secondReports) = made(at: now)
        #expect(ShareSnapshot.make(store: first, reports: firstReports, now: now)
                == ShareSnapshot.make(store: second, reports: secondReports, now: now))
    }

    @Test func resettingTheDemoWithoutAWeekLeavesNothingTaken() {
        let now = TestClock.at(14, 12)
        let model = AppModel(store: MedicationStore(entries: SampleMedications.sampleList, calendar: calendar, now: now),
                             pharmacy: PharmacyStore(pharmacy: Pharmacy()), reports: ScanReports(calendar: calendar, now: now))
        model.resetDemo(sampleWeek: true, now: now)
        model.resetDemo(sampleWeek: false, now: now)
        #expect(model.store.medications.first { $0.id == "capecitabine-500" }?.doseTimes == [DoseTime(12, 30), DoseTime(20)])
        #expect(model.store.doses(on: now).allSatisfy { model.store.state(of: $0) == .pending })
        #expect(model.reports.reports.isEmpty)
        #expect(model.pharmacy.pharmacy.name == Pharmacy.sample(now: now).name)
    }
}
