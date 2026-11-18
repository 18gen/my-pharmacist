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
        store = MedicationStore(medications: TestMedications.all)
        flow = ScanFlow(store: store)
    }

    private func pill(_ medication: Medication?, x: Double = 0.1) -> AnalyzedPill {
        AnalyzedPill(box: CGRect(x: x, y: 0.4, width: 0.1, height: 0.1), crop: testImage(), medicationID: medication?.id)
    }

    private var result: PillScanResult? {
        if case .results(let result) = flow.phase { result } else { nil }
    }

    /// The doses on Home whose pills were scanned.
    private var scannedDoses: [Dose] {
        store.todaySlots(now: morning).flatMap(\.items).filter { $0.state.scannedAt != nil }.map(\.dose)
    }

    private func state(of dose: Dose) -> DoseState? {
        store.todaySlots(now: morning).flatMap(\.items).first { $0.id == dose.id }?.state
    }

    @Test func pillsAreNumberedAndJudged() throws {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin), pill(nil, x: 0.5)], photo: testImage(), now: morning)

        let result = try #require(result)
        #expect(result.pills.map(\.id) == [1, 2])
        #expect(result.pills[0].verdict.doseToTake != nil)
        #expect(result.pills[1].verdict == .unidentified)
        #expect(result.summary == "Put back 1 pill")
        #expect(result.needsRescan)
    }

    @Test func theMostSeriousLinesComeFirst() throws {
        flow.setOpen(true)
        // OK, not yet (atorvastatin is for the evening), unknown.
        flow.showResults([pill(TestMedications.metformin), pill(TestMedications.atorvastatin, x: 0.3), pill(nil, x: 0.6)], photo: testImage(), now: morning)
        let result = try #require(result)
        #expect(result.groups.map(\.level) == [.unknown, .dontTake, .ok])
        #expect(result.groups.map(\.lines.count) == [1, 1, 1])
    }

    @Test func onlyWhatWasScannedIsShown() throws {
        flow.setOpen(true)
        // Lisinopril is due too but wasn't in the photo: the page is about metformin only.
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning)
        let result = try #require(result)
        #expect(result.groups.flatMap(\.lines).map(\.id) == ["pill-1"])
        #expect(result.isAllClear)
        #expect(result.summary == "OK to take this pill")
    }

    @Test func pillsThatAreOKToTakeAreMarkedTakenAsScanned() throws {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin), pill(TestMedications.lisinopril, x: 0.5)], photo: testImage(), now: morning)
        #expect(scannedDoses.map(\.medication) == [TestMedications.lisinopril, TestMedications.metformin])
        #expect(scannedDoses.allSatisfy { state(of: $0) == .taken(at: morning, scannedAt: morning) })
        let result = try #require(result)
        #expect(result.summary == "OK to take all 2")
        #expect(result.isAllClear)
        #expect(!result.needsRescan)
    }

    @Test func onlyPillsThatAreOKToTakeAreMarked() {
        flow.setOpen(true)
        // Atorvastatin is too early, the second metformin an extra tablet, the last unknown.
        flow.showResults([pill(TestMedications.atorvastatin), pill(TestMedications.lisinopril, x: 0.3),
                          pill(TestMedications.lisinopril, x: 0.5), pill(nil, x: 0.7)], photo: testImage(), now: morning)
        #expect(scannedDoses.map(\.medication) == [TestMedications.lisinopril])
    }

    @Test func aPhotoTakenAgainIsJudgedWithoutTheSessionsMarks() throws {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin), pill(nil, x: 0.5)], photo: testImage(), now: morning)
        // The unknown pill was put back and the rest scanned again: still OK to take,
        // not "already taken".
        let minuteLater = morning.addingTimeInterval(60)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: minuteLater)
        let dose = try #require(result?.pills[0].verdict.doseToTake)
        #expect(scannedDoses.map(\.medication) == [TestMedications.metformin])
        #expect(state(of: dose) == .taken(at: minuteLater, scannedAt: minuteLater))
    }

    @Test func aRetakeKeepsTheTickOfAPillThatIsGone() {
        flow.setOpen(true)
        // Lisinopril was OK and swallowed; the unknown pill is checked again on its own,
        // with metformin.
        flow.showResults([pill(TestMedications.lisinopril), pill(nil, x: 0.5)], photo: testImage(), now: morning)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning.addingTimeInterval(60))
        #expect(scannedDoses.map(\.medication) == [TestMedications.lisinopril, TestMedications.metformin])
    }

    @Test func aPillScannedInAnEarlierSessionIsAlreadyTaken() throws {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning)
        flow.setOpen(false)

        flow.setOpen(true)
        let later = morning.addingTimeInterval(30 * 60)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: later)
        let result = try #require(result)
        #expect(result.pills[0].verdict.level == .dontTake)
        #expect(result.pills[0].verdict.reason == "Already taken at \(morning.shortTime).")
    }

    @Test func afterNotTakenTheNextScanSaysToTakeIt() throws {
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning)
        let dose = try #require(scannedDoses.first)
        flow.setOpen(false)

        store.markNotTaken([dose])
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.metformin)], photo: testImage(), now: morning.addingTimeInterval(120))
        #expect(result?.pills[0].verdict == .take(dose))
        #expect(state(of: dose)?.takenAt == morning.addingTimeInterval(120))
    }

    @Test func aScannedPillStaysTakenAfterTheCameraCloses() throws {
        flow.setOpen(true)
        // The unknown pill has to go back; metformin is still ticked.
        flow.showResults([pill(TestMedications.metformin), pill(nil, x: 0.5)], photo: testImage(), now: morning)
        let dose = try #require(scannedDoses.first)
        flow.setOpen(false)
        flow.setOpen(true)
        #expect(state(of: dose) == .taken(at: morning, scannedAt: morning))
        #expect(store.scanPhoto(of: dose) != nil)
    }

    @Test func aPillTakenOnlyWhenNeededIsMarkedTakenToday() {
        let store = MedicationStore(medications: TestMedications.all + [TestMedications.ondansetron])
        let flow = ScanFlow(store: store)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: morning)!
        flow.setOpen(true)
        // Two of its pills count once.
        flow.showResults([pill(TestMedications.ondansetron), pill(TestMedications.ondansetron, x: 0.5)], photo: testImage(), now: morning)
        #expect(store.asNeededTaken(of: TestMedications.ondansetron, on: morning) == morning)
        #expect(store.asNeededScan(of: TestMedications.ondansetron, on: morning) == morning)
        #expect(store.asNeededScanPhoto(of: TestMedications.ondansetron, on: morning) != nil)
        // Only today's, and no dose is ticked for it.
        #expect(store.asNeededTaken(of: TestMedications.ondansetron, on: tomorrow) == nil)
        #expect(store.todaySlots(now: morning).flatMap(\.items).allSatisfy { $0.state.isPending })
    }

    @Test func aRetakeKeepsAPillTakenOnlyWhenNeeded() {
        let store = MedicationStore(medications: TestMedications.all + [TestMedications.ondansetron])
        let flow = ScanFlow(store: store)
        flow.setOpen(true)
        flow.showResults([pill(TestMedications.ondansetron), pill(nil, x: 0.5)], photo: testImage(), now: morning)
        // Taken, then the unknown pill checked again on its own.
        flow.showResults([pill(nil)], photo: testImage(), now: morning.addingTimeInterval(60))
        #expect(store.asNeededTaken(of: TestMedications.ondansetron, on: morning) == morning)
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
        #expect(flow.phase.step == .retake)
        if case .retake(_, let reason) = flow.phase {
            #expect(reason == .noPills)
        }
        #expect(scannedDoses.isEmpty)
    }

    @Test func aPhotoThatCouldntBeCheckedIsNotCalledEmpty() {
        #expect(ScanInstruction.retake(.noPills) == ScanInstruction.noPills)
        #expect(ScanInstruction.retake(.cantCheck).text != ScanInstruction.noPills.text)
    }

    @Test func everyReasonToRetakeSaysAndShowsItsOwnThingToDo() {
        let reasons: [RetakeReason] = [.noPills, .cantCheck, .touching, .cutOff, .tooFar, .hardToSee]
        let lines = reasons.map(ScanInstruction.retake)
        #expect(Set(lines.map(\.text)).count == reasons.count)
        #expect(Set(lines.compactMap(\.pictogram)).count == reasons.count)
        #expect(ScanInstruction.retake(.touching).text == "Spread pills apart")
        #expect(ScanInstruction.retake(.tooMany).text == "At most \(CheckLimits.pills) pills")
        let problems: [CheckProblem] = [.offline, .busy, .serverError, .unavailable, .tooMuch]
        let failures = problems.map { ScanInstruction.retake(.checkFailed($0)) }
        #expect(failures.allSatisfy { $0.spoken != nil })
        // Short enough to read at a glance in very large letters.
        let every = lines + failures + [ScanInstruction.retake(.tooMany)]
            + [ScanInstruction.aim, ScanInstruction.checking, ScanInstruction.turnOnLight, ScanInstruction.confirm(count: 3)]
            + QualityIssue.allCases.compactMap(\.fix).map { ScanInstruction.Line(text: $0, pictogram: nil) }
        for line in every {
            #expect(line.text.split(separator: " ").count <= 4, "\(line.text) is long")
        }
    }

    private func identified(_ pills: [AnalyzedPill]) -> Task<ScanFlow.Identified, Never> {
        Task { .success(PillIdentification(pills: pills)) }
    }

    @Test func nothingIsShownOrRecordedUntilThePersonSaysEveryPillIsCircled() async throws {
        flow.setOpen(true)
        let pills = [pill(TestMedications.metformin), pill(TestMedications.lisinopril, x: 0.5)]
        flow.askToConfirm(photo: testImage(), boxes: pills.map(\.box), identify: { identified(pills) })
        #expect(flow.phase.step == .confirming)
        if case .confirming(let found) = flow.phase {
            #expect(found.boxes.count == 2)
        }
        #expect(store.todaySlots(now: Date()).flatMap(\.items).allSatisfy { $0.state.isPending })

        await flow.confirmPills()
        let result = try #require(result)
        #expect(result.pills.count == 2)
    }

    @Test func checkingKeepsTheConfirmedPhotoAndPillsUntilTheResultsArrive() async throws {
        flow.setOpen(true)
        let pills = [pill(TestMedications.metformin), pill(TestMedications.lisinopril, x: 0.5)]
        // The recognition waits until the test lets it finish.
        let (gate, release) = AsyncStream.makeStream(of: Void.self)
        let identification = Task {
            for await _ in gate { break }
            return ScanFlow.Identified.success(PillIdentification(pills: pills))
        }
        flow.askToConfirm(photo: testImage(), boxes: pills.map(\.box), identify: { identification })
        let confirming = Task { await flow.confirmPills() }
        for _ in 0..<100 where flow.phase.step != .checking {
            await Task.yield()
        }
        guard case .checking(let found) = flow.phase else {
            Issue.record("Expected the checking step, got \(flow.phase.step)")
            return
        }
        #expect(found.boxes == pills.map(\.box))

        release.yield()
        release.finish()
        await confirming.value
        #expect(try #require(result).pills.count == 2)
    }

    @Test func tryingAgainChecksTheSamePhotoWithoutTakingAnother() async throws {
        flow.setOpen(true)
        let pills = [pill(TestMedications.metformin)]
        // The first check fails (no connection, say); the second works.
        var attempts = 0
        flow.askToConfirm(photo: testImage(), boxes: pills.map(\.box), identify: {
            attempts += 1
            let failed = attempts == 1
            return Task { failed ? .failure(.offline) : .success(PillIdentification(pills: pills)) }
        })
        await flow.confirmPills()
        #expect(flow.phase.step == .retake)

        await flow.checkAgain()
        #expect(attempts == 2)
        #expect(try #require(result).pills.count == 1)
        // Only a failed check can be tried again.
        await flow.checkAgain()
        #expect(attempts == 2)
    }

    @Test func aCheckThatFailedAsksForAnotherPhotoNeverAResult() async {
        flow.setOpen(true)
        let pills = [pill(TestMedications.metformin)]
        flow.askToConfirm(photo: testImage(), boxes: pills.map(\.box),
                          identify: { Task { .failure(.offline) } })
        await flow.confirmPills()
        guard case .retake(_, let reason) = flow.phase else {
            Issue.record("Expected a retake, got \(flow.phase.step)")
            return
        }
        #expect(reason == .checkFailed(.offline))
        #expect(store.todaySlots(now: Date()).flatMap(\.items).allSatisfy { $0.state.isPending })
        #expect(ScanInstruction.retake(.checkFailed(.offline)).spoken?.contains("internet") == true)
    }

    @Test func aCheckThatCantWorkIsNotTriedAgain() async {
        flow.setOpen(true)
        let pills = [pill(TestMedications.metformin)]
        var attempts = 0
        flow.askToConfirm(photo: testImage(), boxes: pills.map(\.box), identify: {
            attempts += 1
            return Task { .failure(.server(status: 401)) }
        })
        await flow.confirmPills()
        guard case .retake(_, .checkFailed(let problem)) = flow.phase else {
            Issue.record("Expected a failed check, got \(flow.phase.step)")
            return
        }
        #expect(problem == .unavailable && !problem.canTryAgain)
        await flow.checkAgain()
        #expect(attempts == 1)
    }

    @Test func eachFailureSaysWhetherTryingAgainCanHelp() {
        #expect(CheckProblem(.offline) == .offline)
        #expect(CheckProblem(.server(status: 429)) == .busy)
        #expect(CheckProblem(.server(status: 503)) == .serverError)
        #expect(CheckProblem(.unusable) == .serverError)
        #expect(CheckProblem(.notConfigured) == .unavailable)
        #expect(CheckProblem(.server(status: 403)) == .unavailable)
        #expect(CheckProblem(.server(status: 413)) == .tooMuch)
        #expect([CheckProblem.offline, .busy, .serverError].allSatisfy { $0.canTryAgain })
        #expect([CheckProblem.unavailable, .tooMuch].allSatisfy { !$0.canTryAgain })
    }

    @Test func closingWhileAskedDropsThePhoto() async {
        flow.setOpen(true)
        let pills = [pill(TestMedications.metformin)]
        flow.askToConfirm(photo: testImage(), boxes: pills.map(\.box), identify: { identified(pills) })
        flow.setOpen(false)
        // Saying yes now does nothing: there is nothing left to confirm.
        await flow.confirmPills()
        #expect(flow.phase.step == .confirming)
        flow.setOpen(true)
        #expect(flow.phase.step == .aiming)
        #expect(store.todaySlots(now: Date()).flatMap(\.items).allSatisfy { $0.state.isPending })
    }

    @Test func aPillThatMayHaveGoneUncheckedIsNeverAllClear() throws {
        flow.setOpen(true)
        let pills = [pill(TestMedications.metformin), pill(TestMedications.lisinopril, x: 0.5)]
        flow.showResults(pills, photo: testImage(), now: morning, mayHaveMissedPill: true)
        let result = try #require(result)
        // Both pills are fine, but the photo may hold another.
        #expect(result.dosesToTake.count == 2)
        #expect(!result.isAllClear)
        #expect(result.needsRescan)
        #expect(result.summary == "Scan again: a pill may be unchecked")
        #expect(result.summaryLevel == .caution)
        #expect(result.groups.map(\.level) == [.caution, .ok])
    }

    @Test func theModelsWordOnAMissedPillReachesTheResults() async throws {
        flow.setOpen(true)
        let pills = [pill(TestMedications.metformin)]
        flow.askToConfirm(photo: testImage(), boxes: pills.map(\.box),
                          identify: { Task { .success(PillIdentification(pills: pills, mayHaveMissedPill: true)) } })
        await flow.confirmPills()
        #expect(try #require(result).mayHaveMissedPill)
    }

    @Test func tooDarkAsksForTheLightWhenThePhoneHasOne() {
        #expect(ScanInstruction.whileAiming(status: .needs(.tooDark), canTurnOnLight: true) == ScanInstruction.turnOnLight)
        #expect(ScanInstruction.whileAiming(status: .needs(.tooDark)).text == "Find more light")
        // Other problems don't change.
        #expect(ScanInstruction.whileAiming(status: .needs(.moving), canTurnOnLight: true).text == "Hold still")
    }

    @Test func theInstructionAndTheCameraViewFitTheScreen() {
        let screen = CGSize(width: 393, height: 759)
        let lens = ScanLayout.openLensSize(in: screen)
        #expect(ScanLayout.headerHeight(in: screen) == ScanLayout.headerWordsHeight)
        #expect(lens.height + ScanLayout.headerWordsHeight + ScanLayout.lensEdgeGap == screen.height)
        // The camera picture is the view above its bar.
        #expect(abs(ScanLayout.lensAspect(in: screen) - Double(lens.width / (lens.height - ScanLayout.controlBarHeight))) < 0.0001)
    }

    @Test func theResultsPageGrowsUpToWhereTheInstructionWas() {
        let screen = CGSize(width: 393, height: 759)
        let open = ScanLayout.openLensSize(in: screen)
        let page = ScanLayout.resultsPageSize(in: screen)
        #expect(page.width == open.width)
        // From just under the status bar to the sides' gap from the bottom: past the
        // camera view at both ends.
        #expect(page.height == screen.height - ScanLayout.resultsTopGap - ScanLayout.lensEdgeGap)
        #expect(page.height > open.height + ScanLayout.lensLift)
        // It reaches into the home indicator's strip, so that it starts just under the
        // status bar and ends the sides' gap from the screen's physical bottom.
        #expect(ScanLayout.resultsPageSize(in: screen, bottomInset: 34).height == page.height + 34)
    }

    @Test func liftingTheCameraPictureKeepsItsSize() {
        // The instruction's room shrinks by as much as the picture rises; the room goes
        // to the bar under it.
        let screen = CGSize(width: 393, height: 759)
        let barWithoutLift = ScanLayout.controlBarHeight - ScanLayout.lensLift
        #expect(ScanLayout.pictureHeight(in: screen)
                == screen.height - (ScanLayout.headerWordsHeight + ScanLayout.lensLift) - ScanLayout.lensEdgeGap - barWithoutLift)
        // The close button stays where the home screen's camera button is: at the bottom
        // of the bar, which ends where the camera view does.
        #expect(ScanLayout.buttonBottomInset == ScanLayout.lensEdgeGap + ScanLayout.buttonGapInLens)
    }

    @Test func leavingTheAppTurnsTheLightOff() {
        flow.setOpen(true)
        flow.scanner.showForPreview(status: .checking, hasLight: true, isLightOn: true)
        flow.appWentToBackground()
        #expect(!flow.scanner.isLightOn)
    }

    @Test func cameraProblemsSayWhatToDo() {
        #expect(CameraProblem.accessDenied.message == "Allow camera in Settings")
        #expect(CameraProblem.unavailable.message == "No camera found")
    }

    @Test func theQuestionSaysHowManyPillsWereFound() {
        #expect(ScanInstruction.confirm(count: 3).text == "Is every pill circled?")
        #expect(ScanInstruction.confirm(count: 3).spoken == "3 pills found. Is every pill circled?")
        #expect(ScanInstruction.confirm(count: 1).spoken == "1 pill found. Is every pill circled?")
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
        #expect(ScanInstruction.checking.pictogram == .checking)
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
