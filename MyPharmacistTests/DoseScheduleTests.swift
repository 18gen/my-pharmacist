//
//  DoseScheduleTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

struct DoseScheduleTests {
    private let calendar = TestClock.calendar
    private let dayDoses = DoseSchedule.doses(for: TestMedications.all, on: TestClock.day, calendar: TestClock.calendar)

    private func dose(_ medication: Medication, at hour: Int) -> Dose {
        dayDoses.first { $0.medication.id == medication.id && $0.time.hour == hour }!
    }

    @Test func dosesAreInTimeThenNameOrder() {
        #expect(dayDoses.map(\.id) == [
            "lisinopril-10@8:00",
            "metformin-500@8:00",
            "metformin-500@18:00",
            "atorvastatin-20@21:00",
        ])
        #expect(dayDoses[0].scheduled == TestClock.at(8))
    }

    @Test func stateFollowsTheDueWindow() {
        let dose = dose(TestMedications.metformin, at: 8)
        func state(at hour: Int, _ minute: Int) -> DoseState {
            DoseSchedule.state(of: dose, scannedAt: [:], now: TestClock.at(hour, minute))
        }
        #expect(state(at: 7, 44) == .upcoming)
        #expect(state(at: 7, 45) == .due)
        #expect(state(at: 8, 15) == .due)
        #expect(state(at: 8, 16) == .late)

        let scannedAt = TestClock.at(8, 5)
        #expect(DoseSchedule.state(of: dose, scannedAt: [dose.id: scannedAt], now: TestClock.at(12)) == .scanned(at: scannedAt))
    }

    @Test func orderedPutsPendingBeforeTaken() {
        let lisinopril = dose(TestMedications.lisinopril, at: 8)
        let ordered = DoseSchedule.ordered(dayDoses, scannedAt: [lisinopril.id: TestClock.at(8)], now: TestClock.at(9))
        #expect(ordered.map(\.dose.id) == [
            "metformin-500@8:00",
            "metformin-500@18:00",
            "atorvastatin-20@21:00",
            "lisinopril-10@8:00",
        ])
        #expect(ordered.last?.state.isScanned == true)
    }

    @Test func pillChecksADoseUpToAnHourEarly() {
        let decision = DoseSchedule.decision(for: TestMedications.metformin, dayDoses: dayDoses, scannedAt: [:], now: TestClock.at(7, 30))
        #expect(decision == .take(dose(TestMedications.metformin, at: 8)))
    }

    @Test func pillTooEarlyPointsToTheNextDose() {
        let decision = DoseSchedule.decision(for: TestMedications.metformin, dayDoses: dayDoses, scannedAt: [:], now: TestClock.at(6, 30))
        #expect(decision == .tooEarly(next: dose(TestMedications.metformin, at: 8)))
    }

    @Test func pillAfterTakingWarnsAndNamesTheNextDose() {
        let morning = dose(TestMedications.metformin, at: 8)
        let scannedAt = TestClock.at(8, 5)
        let decision = DoseSchedule.decision(for: TestMedications.metformin, dayDoses: dayDoses, scannedAt: [morning.id: scannedAt], now: TestClock.at(9))
        #expect(decision == .alreadyScanned(morning, at: scannedAt, next: dose(TestMedications.metformin, at: 18)))
    }

    @Test func pillChecksTheDoseClosestToNow() {
        // Both the missed 8:00 and the current 18:00 dose are untaken; 18:00 wins.
        let decision = DoseSchedule.decision(for: TestMedications.metformin, dayDoses: dayDoses, scannedAt: [:], now: TestClock.at(19))
        #expect(decision == .take(dose(TestMedications.metformin, at: 18)))
    }

    @Test func pillWhenEverythingIsTakenHasNoNextDose() {
        let morning = dose(TestMedications.metformin, at: 8)
        let evening = dose(TestMedications.metformin, at: 18)
        let scannedAt = [morning.id: TestClock.at(8), evening.id: TestClock.at(18)]
        let decision = DoseSchedule.decision(for: TestMedications.metformin, dayDoses: dayDoses, scannedAt: scannedAt, now: TestClock.at(22))
        #expect(decision == .alreadyScanned(evening, at: TestClock.at(18), next: nil))
    }

    @Test func pillOfAMedicationWithNoDosesToday() {
        let doses = DoseSchedule.doses(for: [TestMedications.lisinopril], on: TestClock.day, calendar: calendar)
        let decision = DoseSchedule.decision(for: TestMedications.metformin, dayDoses: doses, scannedAt: [:], now: TestClock.at(8))
        #expect(decision == .notScheduledToday(TestMedications.metformin))
    }
}

struct DoseSlotTests {
    private let dayDoses = DoseSchedule.doses(for: TestMedications.all, on: TestClock.day, calendar: TestClock.calendar)

    private func dose(_ medication: Medication, at hour: Int) -> Dose {
        Dose(medication: medication, time: DoseTime(hour), day: TestClock.day, calendar: TestClock.calendar)
    }

    private func slots(scannedAt: [String: Date] = [:], at hour: Int, _ minute: Int = 0) -> [DoseSlot] {
        DoseSchedule.slots(dayDoses, scannedAt: scannedAt, now: TestClock.at(hour, minute))
    }

    @Test func dosesAreGroupedByTimeOfDayInNameOrder() {
        let result = slots(at: 7)
        #expect(result.map(\.time) == [DoseTime(8), DoseTime(18), DoseTime(21)])
        #expect(result[0].items.map(\.dose.medication) == [TestMedications.lisinopril, TestMedications.metformin])
    }

    @Test func eachTimeOfDaySaysWhereItStandsWithoutCountingHours() {
        let result = slots(at: 8, 30)
        #expect(result.map(\.status) == [.now, .next, .later])
        // From an hour before until an hour after.
        #expect(slots(at: 7, 0)[0].status == .now)
        #expect(slots(at: 6, 59)[0].status == .next)
        #expect(slots(at: 9, 0)[0].status == .now)
        #expect(slots(at: 9, 1)[0].status == .notScannedYet)
    }

    @Test func aTimeOfDayIsDoneOnlyWhenEveryDoseInItIsScanned() {
        let lisinopril = dose(TestMedications.lisinopril, at: 8)
        let metformin = dose(TestMedications.metformin, at: 8)
        let half = slots(scannedAt: [lisinopril.id: TestClock.at(8, 5)], at: 8, 10)
        #expect(half[0].status == .now)
        #expect(half[0].items.map(\.state.isScanned) == [true, false])

        let done = slots(scannedAt: [lisinopril.id: TestClock.at(8, 5), metformin.id: TestClock.at(8, 20)], at: 12)
        // Done at the last scan.
        #expect(done[0].status == .done(at: TestClock.at(8, 20)))
        #expect(done[1].status == .next)
    }
}

