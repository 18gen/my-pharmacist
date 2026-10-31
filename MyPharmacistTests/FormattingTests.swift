//
//  FormattingTests.swift
//  MyPharmacistTests
//

import Foundation
import SwiftUI
import Testing
@testable import MyPharmacist

struct DoseStatusFormatterTests {
    private let scheduled = TestClock.at(8)

    @Test(arguments: [
        (10.0, "1 min"),          // never "0 min"
        (59 * 60.0, "59 min"),
        (90 * 60.0, "2 hr"),      // rounded to the nearest hour
        (5 * 3600.0, "5 hr"),
    ])
    func duration(_ seconds: TimeInterval, _ expected: String) {
        #expect(DoseStatusFormatter.duration(seconds) == expected)
    }

    @Test func shortStatus() {
        #expect(DoseStatusFormatter.shortStatus(state: .upcoming, scheduled: scheduled, now: TestClock.at(6)) == "2 hr")
        #expect(DoseStatusFormatter.shortStatus(state: .due, scheduled: scheduled, now: scheduled) == "Now")
        #expect(DoseStatusFormatter.shortStatus(state: .late, scheduled: scheduled, now: TestClock.at(8, 40)) == "40 min late")
        let taken = TestClock.at(8, 2)
        #expect(DoseStatusFormatter.shortStatus(state: .taken(at: taken), scheduled: scheduled, now: scheduled) == taken.shortTime)
    }

    @Test func spokenStatusUsesFullWords() {
        #expect(DoseStatusFormatter.spokenStatus(state: .upcoming, scheduled: scheduled, now: TestClock.at(6))
                == "Not taken. Due in 2 hours")
        #expect(DoseStatusFormatter.spokenStatus(state: .late, scheduled: scheduled, now: TestClock.at(8, 40))
                == "Not taken. 40 minutes late")
        #expect(DoseStatusFormatter.spokenStatus(state: .due, scheduled: scheduled, now: scheduled) == "Not taken. Due now")
    }
}

struct ClockTextTests {
    @Test func twentyFourHourClockIsZeroPadded() {
        let utc = TimeZone(identifier: "UTC")!
        #expect(TestClock.at(6, 33).clockText(use24Hour: true, timeZone: utc, calendar: TestClock.calendar) == "06:33")
        #expect(TestClock.at(18, 5).clockText(use24Hour: true, timeZone: utc, calendar: TestClock.calendar) == "18:05")
    }

    @Test func twelveHourClockFollowsThePhoneFormat() {
        let date = TestClock.at(6, 33)
        #expect(date.clockText(use24Hour: false) == date.shortTime)
    }
}

@MainActor
struct ScanOutcomePresentationTests {
    private let dose = Dose(medication: SampleMedications.metformin, time: DoseTime(8), day: TestClock.day, calendar: TestClock.calendar)

    @Test func checkedNamesTheMedication() {
        let outcome = ScanOutcome.checked(dose)
        #expect(outcome.presentation.title == "Checked: Metformin 500 mg")
        #expect(outcome.announcement == "Checked: Metformin 500 mg. \(dose.scheduled.shortTime) dose marked as taken.")
        #expect(outcome.feedback == .success)
    }

    @Test func alreadyTakenWithoutANextDose() {
        let outcome = ScanOutcome.alreadyTaken(dose, at: dose.scheduled, next: nil)
        #expect(outcome.presentation.message.hasSuffix("No more doses today."))
        #expect(outcome.feedback == .warning)
    }

    @Test func notOnListIsAnError() {
        let outcome = ScanOutcome.notOnList(scannedName: "IBUPROFEN 200 MG")
        #expect(outcome.presentation.message == "IBUPROFEN 200 MG isn't one of your medications.")
        #expect(outcome.feedback == .error)
    }
}
