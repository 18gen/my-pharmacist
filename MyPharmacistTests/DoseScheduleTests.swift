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
            "2026-10-14|lisinopril-10@8:00",
            "2026-10-14|metformin-500@8:00",
            "2026-10-14|metformin-500@18:00",
            "2026-10-14|atorvastatin-20@21:00",
        ])
        #expect(dayDoses[0].scheduled == TestClock.at(8))
    }

    @Test func aDoseIsPendingUntilTakenAndAScanCountsAsTaken() {
        let dose = dose(TestMedications.metformin, at: 8)
        #expect(DoseSchedule.state(of: dose, scannedAt: [:]) == .pending)
        // A scan saved without a taken mark (before a scan counted as taken) still counts.
        let scannedAt = TestClock.at(8, 5)
        #expect(DoseSchedule.state(of: dose, scannedAt: [dose.id: scannedAt]) == .taken(at: scannedAt, scannedAt: scannedAt))
    }

    @Test func theWindowRunsFromAnHourBeforeToTwoHoursAfter() {
        let eight = TestClock.at(8)
        #expect(!DoseSchedule.isInWindow(eight, now: TestClock.at(6, 59)))
        #expect(DoseSchedule.isInWindow(eight, now: TestClock.at(7)))
        #expect(DoseSchedule.isInWindow(eight, now: TestClock.at(10)))
        #expect(!DoseSchedule.isInWindow(eight, now: TestClock.at(10, 1)))
    }

    @Test func pillChecksADoseUpToAnHourEarly() {
        let decision = DoseSchedule.decision(for: TestMedications.metformin, doses: dayDoses, scannedAt: [:], now: TestClock.at(7, 30))
        #expect(decision == .take(dose(TestMedications.metformin, at: 8)))
    }

    @Test func pillTooEarlyPointsToTheNextDose() {
        let decision = DoseSchedule.decision(for: TestMedications.metformin, doses: dayDoses, scannedAt: [:], now: TestClock.at(6, 30))
        #expect(decision == .tooEarly(next: dose(TestMedications.metformin, at: 8)))
    }

    @Test func pillAfterTakingWarnsAndNamesTheNextDose() {
        let morning = dose(TestMedications.metformin, at: 8)
        let scannedAt = TestClock.at(8, 5)
        let decision = DoseSchedule.decision(for: TestMedications.metformin, doses: dayDoses, scannedAt: [morning.id: scannedAt], now: TestClock.at(9))
        #expect(decision == .alreadyTaken(morning, at: scannedAt, next: dose(TestMedications.metformin, at: 18)))
    }

    @Test func pillChecksTheDoseClosestToNow() {
        // Both the missed 8:00 and the current 18:00 dose are untaken; 18:00 wins.
        let decision = DoseSchedule.decision(for: TestMedications.metformin, doses: dayDoses, scannedAt: [:], now: TestClock.at(19))
        #expect(decision == .take(dose(TestMedications.metformin, at: 18)))
    }

    @Test func pillWhenEverythingIsTakenHasNoNextDose() {
        let morning = dose(TestMedications.metformin, at: 8)
        let evening = dose(TestMedications.metformin, at: 18)
        let scannedAt = [morning.id: TestClock.at(8), evening.id: TestClock.at(18)]
        let decision = DoseSchedule.decision(for: TestMedications.metformin, doses: dayDoses, scannedAt: scannedAt, now: TestClock.at(22))
        #expect(decision == .alreadyTaken(evening, at: TestClock.at(18), next: nil))
    }

    @Test func aDoseCountsUpToTwoHoursLateThenItIsMissed() {
        let morning = dose(TestMedications.metformin, at: 8)
        #expect(DoseSchedule.decision(for: TestMedications.metformin, doses: dayDoses, scannedAt: [:], now: TestClock.at(10)) == .take(morning))
        // A minute later it's too late: never OK to take, and the next dose is named.
        #expect(DoseSchedule.decision(for: TestMedications.metformin, doses: dayDoses, scannedAt: [:], now: TestClock.at(10, 1))
                == .missed(morning, next: dose(TestMedications.metformin, at: 18)))
        // Hours later, still missed, not a late "take".
        #expect(DoseSchedule.decision(for: TestMedications.metformin, doses: dayDoses, scannedAt: [:], now: TestClock.at(15))
                == .missed(morning, next: dose(TestMedications.metformin, at: 18)))
    }

    /// Capecitabine-like: 12 AM and 8 PM, judged with the doses around now.
    private let midnightMedication = Medication(id: "midnight", name: "Midnight", strength: "1 mg",
                                                doseTimes: [DoseTime(0), DoseTime(20)])

    private func midnightDecision(at now: Date, scannedAt: [String: Date] = [:]) -> DoseDecision {
        let doses = DoseSchedule.doses(for: [midnightMedication], around: now, calendar: calendar)
        return DoseSchedule.decision(for: midnightMedication, doses: doses, scannedAt: scannedAt, now: now)
    }

    private func midnightDose(hour: Int, dayOffset: Int) -> Dose {
        Dose(medication: midnightMedication, time: DoseTime(hour), day: calendar.date(byAdding: .day, value: dayOffset, to: TestClock.day)!,
             calendar: calendar)
    }

    @Test func aMidnightDoseCountsFromElevenTheEveningBefore() {
        let evening = midnightDose(hour: 20, dayOffset: 0)
        let tonight = midnightDose(hour: 0, dayOffset: 1)
        // 11:30 PM, the 8 PM dose scanned: the pill is tomorrow's 12 AM dose.
        #expect(midnightDecision(at: TestClock.at(23, 30), scannedAt: [evening.id: TestClock.at(20)]) == .take(tonight))
        // 12:30 AM: the same dose, now on its own day.
        let afterMidnight = calendar.date(byAdding: .minute, value: 30, to: tonight.scheduled)!
        #expect(midnightDecision(at: afterMidnight, scannedAt: [evening.id: TestClock.at(20)]) == .take(tonight))
    }

    @Test func aMissedMidnightDoseIsNotTakenInTheAfternoon() {
        // 3 PM with the 12 AM dose not scanned: missed, and the 8 PM dose is next.
        #expect(midnightDecision(at: TestClock.at(15)) == .missed(midnightDose(hour: 0, dayOffset: 0), next: midnightDose(hour: 20, dayOffset: 0)))
    }

    @Test func dosesOnDifferentDaysHaveDifferentIDs() {
        #expect(midnightDose(hour: 0, dayOffset: 0).id != midnightDose(hour: 0, dayOffset: 1).id)
        #expect(midnightDose(hour: 0, dayOffset: 1).id == "2026-10-15|midnight@0:00")
    }

    @Test func pillOfAMedicationWithNoDosesToday() {
        let doses = DoseSchedule.doses(for: [TestMedications.lisinopril], on: TestClock.day, calendar: calendar)
        let decision = DoseSchedule.decision(for: TestMedications.metformin, doses: doses, scannedAt: [:], now: TestClock.at(8))
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
        // From an hour before until two hours after: the window a pill counts in.
        #expect(slots(at: 7, 0)[0].status == .now)
        #expect(slots(at: 6, 59)[0].status == .next)
        #expect(slots(at: 10, 0)[0].status == .now)
        #expect(slots(at: 10, 1)[0].status == .notTakenYet)
    }

    @Test func aTimeOfDayIsDoneOnlyWhenEveryDoseInItIsTaken() {
        let lisinopril = dose(TestMedications.lisinopril, at: 8)
        let metformin = dose(TestMedications.metformin, at: 8)
        let half = slots(scannedAt: [lisinopril.id: TestClock.at(8, 5)], at: 8, 10)
        #expect(half[0].status == .now)
        #expect(half[0].items.map(\.state.isPending) == [false, true])

        let done = slots(scannedAt: [lisinopril.id: TestClock.at(8, 5), metformin.id: TestClock.at(8, 20)], at: 12)
        // Done at the last scan, a scan being taken.
        #expect(done[0].status == .done(at: TestClock.at(8, 20)))
        #expect(done[1].status == .next)
    }

    // MARK: Marked taken

    @Test func aDoseMarkedTakenKeepsWhenItWasScanned() {
        let dose = dose(TestMedications.metformin, at: 8)
        let taken = TestClock.at(8, 10)
        #expect(DoseSchedule.state(of: dose, scannedAt: [:], takenAt: [dose.id: taken])
                == .taken(at: taken, scannedAt: nil))
        let scanned = TestClock.at(8, 5)
        let both = DoseSchedule.state(of: dose, scannedAt: [dose.id: scanned], takenAt: [dose.id: taken])
        #expect(both == .taken(at: taken, scannedAt: scanned))
        #expect(both.scannedAt == scanned && !both.isPending)
    }

    @Test func aPillOfADoseMarkedTakenIsNotTakenAgain() {
        let morning = dose(TestMedications.metformin, at: 8)
        let taken = TestClock.at(8, 10)
        // Never scanned, only ticked: still not OK to take a second time.
        let decision = DoseSchedule.decision(for: TestMedications.metformin, doses: dayDoses, scannedAt: [:],
                                             takenAt: [morning.id: taken], now: TestClock.at(9))
        #expect(decision == .alreadyTaken(morning, at: taken, next: dose(TestMedications.metformin, at: 18)))
    }

    @Test func aDoseTakenBeforeItsTimeIsTheOneAPillIsJudgedAgainst() {
        // 7:20: the 8:00 dose was scanned and taken early. A second pill is for that
        // dose, not for yesterday's.
        let morning = dose(TestMedications.metformin, at: 8)
        let doses = DoseSchedule.doses(for: [TestMedications.metformin], around: TestClock.at(7, 20),
                                         calendar: TestClock.calendar)
        let taken = TestClock.at(7, 15)
        #expect(DoseSchedule.decision(for: TestMedications.metformin, doses: doses, scannedAt: [:],
                                      takenAt: [morning.id: taken], now: TestClock.at(7, 20))
                == .alreadyTaken(morning, at: taken, next: dose(TestMedications.metformin, at: 18)))
        #expect(DoseSchedule.decision(for: TestMedications.metformin, doses: doses, scannedAt: [morning.id: taken],
                                      now: TestClock.at(7, 20))
                == .alreadyTaken(morning, at: taken, next: dose(TestMedications.metformin, at: 18)))
    }

    @Test func aTimeOfDayTickedOrScannedIsDoneAtItsLastDose() {
        let lisinopril = dose(TestMedications.lisinopril, at: 8)
        let metformin = dose(TestMedications.metformin, at: 8)
        // One ticked, the other scanned.
        let mixed = DoseSchedule.slots(dayDoses, scannedAt: [metformin.id: TestClock.at(8, 20)],
                                       takenAt: [lisinopril.id: TestClock.at(8, 5)], now: TestClock.at(12))
        #expect(mixed[0].status == .done(at: TestClock.at(8, 20)))
        // Both ticked, neither scanned.
        let taken = DoseSchedule.slots(dayDoses, scannedAt: [:],
                                       takenAt: [lisinopril.id: TestClock.at(8, 5), metformin.id: TestClock.at(8, 30)],
                                       now: TestClock.at(12))
        #expect(taken[0].status == .done(at: TestClock.at(8, 30)))
    }

    @Test func aSlotIsKnownByItsDayAndTime() {
        #expect(slots(at: 7)[0].id == "2026-10-14@8:00")
    }
}
