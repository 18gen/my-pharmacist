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

@MainActor
struct ResultDetailTests {
    private let calendar = TestClock.calendar
    private var morning: Dose { Dose(medication: TestMedications.metformin, time: DoseTime(8), day: TestClock.day, calendar: calendar) }
    private var evening: Dose { Dose(medication: TestMedications.metformin, time: DoseTime(18), day: TestClock.day, calendar: calendar) }

    @Test func aDoseToTakeSaysItsWindowFromTheSchedulesRule() {
        let opens = morning.scheduled.addingTimeInterval(-DoseSchedule.earlyWindow).shortTime
        let closes = morning.scheduled.addingTimeInterval(DoseSchedule.lateWindow).shortTime
        #expect(PillVerdict.take(morning).timeDetails(calendar: calendar) == ["Can be taken from \(opens) to \(closes)."])
    }

    @Test func aMissedDoseSaysWhenItClosedAndWhenTheNextIs() {
        let closes = morning.scheduled.addingTimeInterval(DoseSchedule.lateWindow).shortTime
        #expect(PillVerdict.missed(morning, next: evening).timeDetails(calendar: calendar)
                == ["It could be taken until \(closes).", "Next dose at \(evening.scheduled.shortTime)."])
        let tomorrow = Dose(medication: TestMedications.metformin, time: DoseTime(8),
                            day: calendar.date(byAdding: .day, value: 1, to: TestClock.day)!, calendar: calendar)
        #expect(PillVerdict.alreadyTaken(evening, at: evening.scheduled, next: tomorrow).timeDetails(calendar: calendar)
                == ["Next dose at \(tomorrow.scheduled.shortTime) the next day."])
    }

    @Test func onlyPillsToAskAboutOfferToCall() {
        let call = URL(string: "tel:5197464500")
        var capecitabine = TestMedications.metformin
        capecitabine.directions = "With water, after a meal."
        func pill(_ medication: Medication?, _ verdict: PillVerdict) -> ScannedPill {
            ScannedPill(id: 1, box: .zero, crop: testImage(), medication: medication, verdict: verdict)
        }
        let unknown = pill(nil, .unidentified).detail(pharmacyCall: call)
        #expect(unknown.callURL == call && unknown.directions == nil)
        #expect(pill(capecitabine, .missed(morning, next: nil)).detail(pharmacyCall: call).callURL == call)
        let ok = pill(capecitabine, .take(morning)).detail(pharmacyCall: call)
        #expect(ok.callURL == nil && ok.directions == "With water, after a meal.")
        // With no number saved there is nothing to call, and an unknown pill has nothing to open.
        #expect(pill(nil, .unidentified).detail(pharmacyCall: nil).isEmpty)
    }
}
