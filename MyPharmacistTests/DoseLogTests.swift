//
//  DoseLogTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

struct DoseLogTests {
    private let morning = TestClock.at(8)
    private let dose = Dose(medication: TestMedications.metformin, time: DoseTime(8), day: TestClock.day, calendar: TestClock.calendar)

    @Test func keysStayAsTheyWereSaved() {
        #expect(DoseLog.Key.dose(dose).scanKey == "2026-10-14|metformin-500@8:00")
        #expect(DoseLog.Key.dose(dose).takenKey == "taken|2026-10-14|metformin-500@8:00")
        #expect(DoseLog.Key.asNeeded("ondansetron-8", on: morning, calendar: TestClock.calendar).scanKey
                == "2026-10-14|ondansetron-8@needed")
    }

    @Test func aScanMarksTakenAndNotTakenForgetsBoth() {
        var log = DoseLog()
        log.markScanned(.dose(dose), at: morning)
        #expect(log.scannedAt(.dose(dose)) == morning && log.takenAt(.dose(dose)) == morning)
        #expect(log.scans == [dose.id: morning] && log.takenMarks == [dose.id: morning])

        log.markNotTaken(.dose(dose))
        #expect(log.entries.isEmpty)
    }

    @Test func tickingByHandLeavesNoScan() {
        var log = DoseLog()
        log.markTaken(.dose(dose), at: morning)
        #expect(log.scannedAt(.dose(dose)) == nil && log.takenAt(.dose(dose)) == morning)
    }

    @Test func aSavedScanWithoutATakenMarkGetsOne() {
        let log = DoseLog(saved: [dose.id: morning], now: morning, keepDays: 14, calendar: TestClock.calendar)
        #expect(log.takenAt(.dose(dose)) == morning)
    }

    @Test func movingTakesBothMarksAndLeavesNothingBehind() {
        let later = Dose(medication: TestMedications.metformin, time: DoseTime(8, 30), day: TestClock.day, calendar: TestClock.calendar)
        var log = DoseLog()
        log.markScanned(.dose(dose), at: morning)
        log.move(.dose(dose), to: .dose(later))
        #expect(log.takenAt(.dose(dose)) == nil && log.scannedAt(.dose(dose)) == nil)
        #expect(log.takenAt(.dose(later)) == morning && log.scannedAt(.dose(later)) == morning)
        // Moving from a dose with nothing recorded leaves the other as it was.
        log.move(.dose(dose), to: .dose(later))
        #expect(log.takenAt(.dose(later)) == morning)
    }

    @Test func removingJudgesAsIfNeverTaken() {
        var log = DoseLog()
        log.markScanned(.dose(dose), at: morning)
        #expect(log.removing([.dose(dose)]).entries.isEmpty)
        // The log itself is unchanged.
        #expect(log.takenAt(.dose(dose)) == morning)
    }
}
