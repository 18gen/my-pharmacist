//
//  FormattingTests.swift
//  MyPharmacistTests
//

import Foundation
import SwiftUI
import Testing
@testable import MyPharmacist

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
struct PillVerdictPresentationTests {
    private let dose = Dose(medication: TestMedications.metformin, time: DoseTime(8), day: TestClock.day, calendar: TestClock.calendar)

    @Test func okToTakeNamesTheDoseTime() {
        #expect(PillVerdict.take(dose).level == .ok)
        #expect(PillVerdict.take(dose).reason == "\(dose.scheduled.shortTime) dose")
        #expect(ResultLevel.ok.color == Palette.ok)
    }

    @Test func pillsNotToTakeNowAreRed() {
        let verdicts: [PillVerdict] = [
            .alreadyScanned(dose, at: dose.scheduled, next: nil),
            .tooEarly(next: dose),
            .notScheduledToday(TestMedications.metformin),
            .extra(TestMedications.metformin),
        ]
        for verdict in verdicts {
            #expect(verdict.level == .dontTake)
            #expect(verdict.level.color == Palette.danger)
        }
        #expect(PillVerdict.unidentified.level == .unknown)
        #expect(ResultLevel.unknown.color == Palette.danger)
    }

    @Test func aPillScannedBeforeMayHaveBeenTaken() {
        let reason = PillVerdict.alreadyScanned(dose, at: dose.scheduled, next: nil).reason
        #expect(reason == "Scanned at \(dose.scheduled.shortTime). You may have taken it.")
    }

    @Test func anAsNeededPillIsACautionWithItsCondition() {
        let verdict = PillVerdict.asNeeded(TestMedications.ondansetron)
        #expect(verdict.level == .caution)
        #expect(verdict.reason == "Only when you feel sick")
        #expect(ResultLevel.caution.color == Palette.caution)
    }
}
