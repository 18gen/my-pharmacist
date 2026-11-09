//
//  ScanFlowTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MyPharmacist

@MainActor
struct ScanFlowTests {
    private let store: MedicationStore
    private let flow: ScanFlow
    private let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!

    init() {
        store = MedicationStore(medications: TestMedications.all, storage: InMemoryDoseLogStorage())
        flow = ScanFlow(store: store)
    }

    private func pill(_ medication: Medication?, x: Double = 0.1) -> AnalyzedPill {
        AnalyzedPill(box: CGRect(x: x, y: 0.4, width: 0.1, height: 0.1), crop: testImage(),
                     match: PillMatch(medicationID: medication?.id, distance: 0.2))
    }

    private var result: PillScanResult? {
        if case .results(let result) = flow.phase { result } else { nil }
    }

    private var scannedDoses: [Dose] {
        store.todayList(now: morning).filter { $0.state.isScanned }.map(\.dose)
    }

    @Test func pillsAreNumberedAndJudged() throws {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin), pill(nil, x: 0.5)], photo: testImage(), now: morning)

        let result = try #require(result)
        #expect(result.pills.map(\.id) == [1, 2])
        #expect(result.pills[0].verdict.isTake)
        #expect(result.pills[1].verdict == .unidentified)
        #expect(result.missing.map(\.medication) == [TestMedications.lisinopril])
        #expect(result.summary == "Put back 1 pill")
        #expect(result.needsRescan)
    }

    @Test func theMostSeriousLinesComeFirst() throws {
        flow.setOpen(true)
        // OK, not yet (atorvastatin is for the evening), unknown; lisinopril is missing.
        flow.showResults([pill(TestMedications.metformin), pill(TestMedications.atorvastatin, x: 0.3), pill(nil, x: 0.6)], photo: testImage(), now: morning)
        let result = try #require(result)
        #expect(result.groups.map(\.level) == [.unknown, .dontTake, .caution, .ok])
        #expect(result.groups.map(\.lines.count) == [1, 1, 1, 1])
    }

    @Test func pillsThatAreOKToTakeAreRecordedAsScanned() throws {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin), pill(TestMedications.lisinopril, x: 0.5)], photo: testImage(), now: morning)
        #expect(scannedDoses.map(\.medication) == [TestMedications.lisinopril, TestMedications.metformin])
        let result = try #require(result)
        #expect(result.summary == "OK to take all 2")
        #expect(result.isAllClear)
        #expect(!result.needsRescan)
    }

    @Test func onlyPillsThatAreOKToTakeAreRecorded() {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.atorvastatin), pill(TestMedications.lisinopril, x: 0.5)], photo: testImage(), now: morning)
        #expect(scannedDoses.map(\.medication) == [TestMedications.lisinopril])
    }

    @Test func scanningAgainReplacesTheSessionsRecord() throws {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin), pill(nil, x: 0.5)], photo: testImage(), now: morning)
        // The unknown pill was put back and the rest scanned again: still OK to take,
        // not "scanned already".
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning.addingTimeInterval(60))
        let result = try #require(result)
        #expect(result.pills[0].verdict.isTake)
        #expect(scannedDoses.map(\.medication) == [TestMedications.metformin])
    }

    @Test func aPillScannedInAnEarlierSessionMayHaveBeenTaken() throws {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning)
        flow.setOpen(false)

        flow.setOpen(true)
        let later = morning.addingTimeInterval(30 * 60)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: later)
        let result = try #require(result)
        #expect(result.pills[0].verdict.level == .dontTake)
        if case .alreadyScanned(_, let time, _) = result.pills[0].verdict {
            #expect(time == morning)
        } else {
            Issue.record("Expected the pill to be already scanned, got \(result.pills[0].verdict)")
        }
    }

    @Test func theDemoRecordsNothing() {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning, records: false)
        #expect(flow.phase.step == .results)
        #expect(scannedDoses.isEmpty)
    }

    @Test func aPhotoWithNoPillsStaysOnScreen() {
        flow.setOpen(true)
        flow.showResults([], photo: testImage(), now: morning)
        // The photo stays, with no automatic retry; Retake (which starts the camera, so
        // isn't run here) or closing leaves it.
        #expect(flow.phase.step == .noPills)
        #expect(scannedDoses.isEmpty)
    }

    @Test func theInstructionIsTheOneThingToDoNow() {
        #expect(ScanInstruction.whileAiming(status: .checking) == ScanInstruction.aim)
        let holdStill = ScanInstruction.whileAiming(status: .needs(.moving))
        #expect(holdStill.text == "Hold still")
        #expect(holdStill.pictogram == .holdStill)
        // Focusing is the camera's job, so it doesn't ask the person to do anything.
        #expect(ScanInstruction.whileAiming(status: .needs(.focusing)) == ScanInstruction.aim)
    }

    @Test func everyThingToFixHasAPictureOfIt() {
        for issue in QualityIssue.allCases where issue.fix != nil {
            #expect(issue.pictogram != nil, "\(issue) has words but no picture")
        }
        #expect(ScanInstruction.aim.pictogram == .aim)
        #expect(ScanInstruction.checking(count: 3).pictogram == .checking)
    }

    @Test func openingAgainStartsTheNextSessionFresh() {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning)
        flow.setOpen(false)
        // Still showing the results while the view closes.
        #expect(flow.phase.step == .results)

        flow.setOpen(true)
        #expect(flow.phase.step == .aiming)
    }
}
