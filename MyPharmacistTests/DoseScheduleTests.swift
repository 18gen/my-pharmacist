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
            DoseSchedule.state(of: dose, takenAt: [:], now: TestClock.at(hour, minute))
        }
        #expect(state(at: 7, 44) == .upcoming)
        #expect(state(at: 7, 45) == .due)
        #expect(state(at: 8, 15) == .due)
        #expect(state(at: 8, 16) == .late)

        let takenAt = TestClock.at(8, 5)
        #expect(DoseSchedule.state(of: dose, takenAt: [dose.id: takenAt], now: TestClock.at(12)) == .taken(at: takenAt))
    }

    @Test func orderedPutsPendingBeforeTaken() {
        let lisinopril = dose(TestMedications.lisinopril, at: 8)
        let ordered = DoseSchedule.ordered(dayDoses, takenAt: [lisinopril.id: TestClock.at(8)], now: TestClock.at(9))
        #expect(ordered.map(\.dose.id) == [
            "metformin-500@8:00",
            "metformin-500@18:00",
            "atorvastatin-20@21:00",
            "lisinopril-10@8:00",
        ])
        #expect(ordered.last?.state.isTaken == true)
    }

    @Test func scanChecksADoseUpToAnHourEarly() {
        let outcome = DoseSchedule.scanOutcome(for: TestMedications.metformin, dayDoses: dayDoses, takenAt: [:], now: TestClock.at(7, 30))
        #expect(outcome == .checked(dose(TestMedications.metformin, at: 8)))
    }

    @Test func scanTooEarlyPointsToTheNextDose() {
        let outcome = DoseSchedule.scanOutcome(for: TestMedications.metformin, dayDoses: dayDoses, takenAt: [:], now: TestClock.at(6, 30))
        #expect(outcome == .tooEarly(next: dose(TestMedications.metformin, at: 8)))
    }

    @Test func scanAfterTakingWarnsAndNamesTheNextDose() {
        let morning = dose(TestMedications.metformin, at: 8)
        let takenAt = TestClock.at(8, 5)
        let outcome = DoseSchedule.scanOutcome(for: TestMedications.metformin, dayDoses: dayDoses, takenAt: [morning.id: takenAt], now: TestClock.at(9))
        #expect(outcome == .alreadyTaken(morning, at: takenAt, next: dose(TestMedications.metformin, at: 18)))
    }

    @Test func scanChecksTheDoseClosestToNow() {
        // Both the missed 8:00 and the current 18:00 dose are untaken; 18:00 wins.
        let outcome = DoseSchedule.scanOutcome(for: TestMedications.metformin, dayDoses: dayDoses, takenAt: [:], now: TestClock.at(19))
        #expect(outcome == .checked(dose(TestMedications.metformin, at: 18)))
    }

    @Test func scanWhenEverythingIsTakenHasNoNextDose() {
        let morning = dose(TestMedications.metformin, at: 8)
        let evening = dose(TestMedications.metformin, at: 18)
        let takenAt = [morning.id: TestClock.at(8), evening.id: TestClock.at(18)]
        let outcome = DoseSchedule.scanOutcome(for: TestMedications.metformin, dayDoses: dayDoses, takenAt: takenAt, now: TestClock.at(22))
        #expect(outcome == .alreadyTaken(evening, at: TestClock.at(18), next: nil))
    }

    @Test func scanOfAMedicationWithNoDosesToday() {
        let doses = DoseSchedule.doses(for: [TestMedications.lisinopril], on: TestClock.day, calendar: calendar)
        let outcome = DoseSchedule.scanOutcome(for: TestMedications.metformin, dayDoses: doses, takenAt: [:], now: TestClock.at(8))
        #expect(outcome == .notScheduledToday(TestMedications.metformin))
    }
}
