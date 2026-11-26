//
//  ScanFlow.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import Observation

/// One scanning session, from opening the camera to closing it. There is no shutter:
/// 1. wait until the camera picture has been good for a moment, then take a photo;
/// 2. find the pills in it; if there are none, or the photo can't be checked, it stays
///    on screen with what to do about it and a Retake button;
/// 3. show the photo with every pill found circled and ask whether that is all of them,
///    as nothing later can make up for a pill that wasn't found; meanwhile each pill is
///    already being cut out and recognized on its own;
/// 4. on "Yes", show the results on a page of their own; on "No", take another photo.
/// The doses whose pills are OK to take are marked taken, as scanned, as soon as the
/// results show, even when other pills in the photo have to go back. A medication taken
/// only when needed is marked taken for today in the same way. A photo taken again in the
/// same session is judged as if the earlier one hadn't marked anything (`ScanSessionRecord`).
@Observable
final class ScanFlow {
    enum Phase {
        /// Live camera with picture-quality hints (step 1).
        case aiming
        /// Photo being taken (nil) or searched for pills (step 2). Once taken, the camera
        /// is off and the photo shows in its place.
        case finding(CGImage?)
        /// The photo can't be checked (no pills in it, say): it stays on screen with the
        /// reason and a Retake button.
        case retake(CGImage, RetakeReason)
        /// Pills found: the photo shows with each one circled, for the person to say
        /// whether every pill is circled (step 3).
        case confirming(FoundPills)
        /// The person said yes; these pills are being checked.
        case checking(FoundPills)
        case results(PillScanResult)

        /// The phase without its data, for animations and haptics.
        var step: Step {
            switch self {
            case .aiming: .aiming
            case .finding: .finding
            case .retake: .retake
            case .confirming: .confirming
            case .checking: .checking
            case .results: .results
            }
        }
    }

    enum Step: Hashable {
        case aiming, finding, retake, confirming, checking, results

        /// The results page, or the same page standing ready while the pills are checked.
        var isResultsPage: Bool { self == .checking || self == .results }
    }

    private(set) var isOpen = false
    private(set) var phase: Phase = .aiming

    #if DEBUG
    /// For previews: open, in the given step, without the camera.
    func showForPreview(_ phase: Phase) {
        isOpen = true
        self.phase = phase
    }
    #endif
    let scanner: ScannerModel
    /// Width over height of the camera view, set by the screen that lays it out. The
    /// camera zooms for it and photos are kept to it, so the photo is what the person saw.
    @ObservationIgnored var visibleAspect = 9.0 / 16.0

    @ObservationIgnored private let store: MedicationStore
    @ObservationIgnored private var analyzer: PillPhotoAnalyzer
    /// The medications `analyzer` compares against, as they were when it was made.
    @ObservationIgnored private var analyzedMedications: [Medication]
    @ObservationIgnored private var checkTask: Task<Void, Never>?
    /// The found pills being recognized, from the moment the person is asked whether all
    /// were found until their results show.
    @ObservationIgnored private var pending: PendingCheck?
    /// What this session marked taken, so a photo taken again is judged without it.
    @ObservationIgnored private var session = ScanSessionRecord()
    /// This session, for its report: a photo taken again replaces it.
    @ObservationIgnored private var sessionID = UUID()
    /// What each scan said, kept for sharing with the pharmacy demo.
    @ObservationIgnored private let reports: ScanReports

    /// What recognizing the pills came to.
    typealias Identified = Result<PillIdentification, PillRecognitionFailure>

    /// Pills found in a photo and being recognized. It holds on to the full-size photo
    /// (inside `start`), so it is let go as soon as the results show.
    private struct PendingCheck {
        let found: FoundPills
        /// Starts recognizing the pills: at once, and again after a check that failed,
        /// when the photo was fine and needn't be taken again.
        let start: () -> Task<Identified, Never>
        var task: Task<Identified, Never>
    }

    init(store: MedicationStore, reports: ScanReports = ScanReports(), scanner: ScannerModel = ScannerModel()) {
        self.store = store
        self.reports = reports
        self.scanner = scanner
        self.analyzer = Self.makeAnalyzer(store.medications)
        self.analyzedMedications = store.medications
    }

    private static func makeAnalyzer(_ medications: [Medication]) -> PillPhotoAnalyzer {
        #if DEBUG
        // For trying the scan without sending anything anywhere: every pill is unknown.
        if ProcessInfo.processInfo.arguments.contains("-noCloud") {
            return PillPhotoAnalyzer(medications: medications, recognizer: nil, answersUnknown: true)
        }
        #endif
        return PillPhotoAnalyzer(medications: medications)
    }

    /// Closing ends the session; opening starts the next one fresh. The phase is reset on
    /// opening, not closing, so the closing view keeps showing what it showed (the results,
    /// say) while it shrinks away, instead of switching to the camera on the way out.
    func setOpen(_ open: Bool) {
        cancelChecks()
        if open {
            phase = .aiming
            scanner.turnLightOff()
            refreshAnalyzer()
        }
        session = ScanSessionRecord()
        sessionID = UUID()
        isOpen = open
    }

    /// Pills are compared only with the medications on the list, which may have changed on
    /// the Pills page since the last scan: a removed one is then "Unknown", and a new photo
    /// or appearance is what the pills are compared with.
    private func refreshAnalyzer() {
        guard store.medications != analyzedMedications else { return }
        analyzer = Self.makeAnalyzer(store.medications)
        analyzedMedications = store.medications
    }

    /// Step 1 passed: the picture has been good for a moment, so take the photo.
    func captureStatusChanged(_ status: QualityGate.Status) {
        if status == .ready {
            capture()
        }
    }

    /// Takes the photo, finds the pills in it and checks each one. Ignored unless aiming.
    private func capture() {
        guard isOpen, case .aiming = phase else { return }
        phase = .finding(nil)
        checkTask = Task { [weak self] in
            guard let self else { return }
            guard let captured = await scanner.capturePhoto(), !Task.isCancelled else {
                // The camera couldn't take it; aim again and let the next good moment retry.
                aimAgain()
                return
            }
            // The camera is done: the photo it took shows in its place.
            scanner.stop()
            await findPills(in: captured)
        }
    }

    /// Steps 2 and 3 for a photo: finds its pills, and either asks for another photo or
    /// asks whether these are all the pills.
    func findPills(in captured: CapturedPhoto) async {
        let photo = captured.working
        phase = .finding(photo)

        // Step 2: are there pills at all? If not, the photo stays with a Retake button.
        let search = await analyzer.findPills(in: captured)
        #if DEBUG
        ScanPhotoKeeper.keep(captured, search: search)
        #endif
        guard !Task.isCancelled else { return }
        let found: [FoundPill]
        switch search {
        case .found(let pills):
            found = pills
        case .noPills:
            phase = .retake(photo, .noPills)
            return
        case .unclear(let reason):
            phase = .retake(photo, reason)
            return
        case .failed:
            phase = .retake(photo, .cantCheck)
            return
        }

        // Step 3: ask whether these are all the pills, and start checking each one
        // meanwhile so the answer isn't waited for twice.
        let analyzer = analyzer
        askToConfirm(photo: photo, boxes: found.map(\.box)) {
            Task { await analyzer.identify(found, in: captured) }
        }
    }

    /// Shows the photo with the pills found circled. Nothing is recorded, and no result
    /// shown, until the person says every pill is circled.
    /// - Parameter identify: Starts recognizing the pills. Called now, and again if the
    ///   check fails and the person tries again.
    func askToConfirm(photo: CGImage, boxes: [CGRect], identify: @escaping () -> Task<Identified, Never>) {
        let found = FoundPills(photo: photo, boxes: boxes)
        pending = PendingCheck(found: found, start: identify, task: identify())
        phase = .confirming(found)
    }

    /// The person says every pill in the photo is circled: on to the results, as soon
    /// as the pills are recognized. If they couldn't be, the person is told why; a check
    /// that didn't happen is never shown as a result.
    func confirmPills() async {
        guard case .confirming = phase, let pending else { return }
        await awaitCheck(pending)
    }

    /// After a check that failed for a reason trying again can help with: checks the same
    /// photo's pills again, without taking another photo.
    func checkAgain() async {
        guard case .retake(_, .checkFailed(let problem)) = phase, problem.canTryAgain, var pending else { return }
        pending.task = pending.start()
        self.pending = pending
        await awaitCheck(pending)
    }

    /// Shows the page standing ready until the pills are recognized, then their results.
    private func awaitCheck(_ check: PendingCheck) async {
        phase = .checking(check.found)
        let task = Task { [weak self] in
            let identified = await check.task.value
            guard let self, !Task.isCancelled else { return }
            switch identified {
            case .success(let pills):
                pending = nil
                showResults(pills.pills, photo: check.found.photo, mayHaveMissedPill: pills.mayHaveMissedPill)
            case .failure(let failure):
                let problem = CheckProblem(failure)
                // Kept only while checking again can help.
                if !problem.canTryAgain { pending = nil }
                phase = .retake(check.found.photo, .checkFailed(problem))
            }
        }
        checkTask = task
        await task.value
    }

    private func cancelChecks() {
        checkTask?.cancel()
        checkTask = nil
        pending?.task.cancel()
        pending = nil
    }

    /// Back to aiming when the camera couldn't take the photo. The quality check starts
    /// over, so another photo is only taken once the picture has been good again.
    private func aimAgain() {
        guard isOpen else { return }
        phase = .aiming
        scanner.reset()
    }

    /// Turns the analyzed pills into verdicts against today's schedule and marks the doses
    /// that are OK to take as taken, as scanned.
    /// - Parameter records: false to show results without changing the record (the demo).
    /// - Parameter mayHaveMissedPill: Something pill-like in the photo wasn't found.
    func showResults(_ pills: [AnalyzedPill], photo: CGImage, now: Date = Date(), records: Bool = true,
                     mayHaveMissedPill: Bool = false) {
        guard !pills.isEmpty else {
            phase = .retake(photo, .noPills)
            return
        }
        let result = PillScanResult.judging(pills, photo: photo, store: store, now: now,
                                            ignoring: session, mayHaveMissedPill: mayHaveMissedPill)
        if records {
            record(result, at: now)
        }
        phase = .results(result)
    }

    /// Marks what a scan found OK to take as taken, as scanned: each dose's box on Home is
    /// ticked and shows the pill as it was scanned. A pill taken only when needed has no
    /// dose, so its medication is marked taken today, once however many of its pills there are.
    /// What the scan said about every pill is kept too, replacing this session's earlier photo.
    private func record(_ result: PillScanResult, at time: Date) {
        let filed = result.report(session: sessionID, at: time)
        reports.record(filed.report, photos: filed.photos, now: time)
        let photos = Dictionary(result.pills.compactMap { pill in pill.verdict.doseToTake.map { ($0, pill.crop) } },
                                uniquingKeysWith: { first, _ in first })
        store.recordScan(of: result.dosesToTake, at: time, photos: photos)
        session.add(result.dosesToTake)
        for medication in result.asNeededMedications {
            store.recordAsNeededScan(of: medication, at: time, photo: result.firstCrop(of: medication))
            session.add(asNeeded: medication.id, on: time)
        }
    }

    /// Back to the live camera for another photo: from the results, from a photo that
    /// can't be checked, or when the person says a pill isn't circled.
    func scanAgain() async {
        cancelChecks()
        phase = .aiming
        await restartCamera()
    }

    /// The app came back to the screen. While aiming, the camera starts again from
    /// "checking": the picture may have changed, and camera access may have just been
    /// turned on in Settings.
    func appBecameActive() async {
        guard isOpen, case .aiming = phase else { return }
        await restartCamera()
    }

    /// The app left the screen: the system stops the camera and its light.
    func appWentToBackground() {
        scanner.appWentToBackground()
    }

    /// Starts or stops the camera to match `isOpen`. Each opening starts from "checking".
    func syncCamera() async {
        if isOpen {
            await restartCamera()
        } else {
            scanner.stop()
        }
    }

    /// The camera on, judging the picture afresh from "checking".
    private func restartCamera() async {
        scanner.reset()
        await scanner.start(visibleAspect: visibleAspect)
    }
}
