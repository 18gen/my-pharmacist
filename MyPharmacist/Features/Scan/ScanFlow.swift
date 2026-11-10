//
//  ScanFlow.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import Observation

/// One pill in the results: where it is in the photo, its cut-out, what it was
/// recognized as and whether to take it.
struct ScannedPill: Identifiable {
    /// 1, 2, 3… in reading order.
    let id: Int
    /// Normalized 0–1, origin at the top left of the photo.
    let box: CGRect
    let crop: CGImage
    let medication: Medication?
    let verdict: PillVerdict
    let match: PillMatch
}

/// The pills found in a photo, before they are recognized: what the person is asked to
/// look over.
struct FoundPills {
    let photo: CGImage
    /// Each pill's box, normalized 0–1 with the origin at the top left of the photo.
    let boxes: [CGRect]
}

/// Everything found in one photo. The photo stays in memory only while the results show.
/// Only what was scanned: doses due now that weren't in the photo aren't part of it.
struct PillScanResult {
    let photo: CGImage
    let pills: [ScannedPill]
    /// The vision model saw something pill-like in the photo that wasn't found as a
    /// pill, so these may not be all the pills there are.
    var mayHaveMissedPill = false

    var dosesToTake: [Dose] {
        pills.compactMap { if case .take(let dose) = $0.verdict { dose } else { nil } }
    }
    var notToTakeCount: Int { pills.count - dosesToTake.count }
}

/// One scanning session, from opening the camera to closing it. There is no shutter:
/// 1. wait until the camera picture has been good for a moment, then take a photo;
/// 2. find the pills in it; if there are none, or the photo can't be checked, it stays
///    on screen with what to do about it and a Retake button;
/// 3. show the photo with every pill found circled and ask whether that is all of them,
///    as nothing later can make up for a pill that wasn't found; meanwhile each pill is
///    already being cut out and recognized on its own;
/// 4. on "Yes", show the results on a page of their own; on "No", take another photo.
/// The doses whose pills are OK to take are recorded as scanned as soon as the results
/// show; there is no "taken" to confirm. A retake in the same session replaces that record.
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
    /// The medications `analyzer` compares against, by ID.
    @ObservationIgnored private var analyzedMedicationIDs: [String]
    @ObservationIgnored private var checkTask: Task<Void, Never>?
    /// The pills being recognized while the person is asked whether all were found.
    @ObservationIgnored private var identification: Task<PillIdentification, Never>?
    /// Doses this session recorded as scanned, so a retake can replace them.
    @ObservationIgnored private var recordedThisSession: [Dose] = []

    init(store: MedicationStore, scanner: ScannerModel = ScannerModel()) {
        self.store = store
        self.scanner = scanner
        self.analyzer = Self.makeAnalyzer(store.medications)
        self.analyzedMedicationIDs = store.medications.map(\.id)
    }

    private static func makeAnalyzer(_ medications: [Medication]) -> PillPhotoAnalyzer {
        #if DEBUG
        // For trying the scan without sending anything anywhere.
        if ProcessInfo.processInfo.arguments.contains("-noCloud") {
            return PillPhotoAnalyzer(medications: medications, cloud: nil)
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
        recordedThisSession = []
        isOpen = open
    }

    /// Pills are compared only with the medications on the list, which may have changed on
    /// the My Medications page since the last scan: a removed one is then "Unknown".
    private func refreshAnalyzer() {
        let ids = store.medications.map(\.id)
        guard ids != analyzedMedicationIDs else { return }
        analyzer = Self.makeAnalyzer(store.medications)
        analyzedMedicationIDs = ids
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
            await check(captured)
        }
    }

    /// Steps 2 and 3 for a photo: finds its pills, and either asks for another photo or
    /// asks whether these are all the pills.
    func check(_ captured: CapturedPhoto) async {
        let photo = captured.working
        phase = .finding(photo)

        // Step 2: are there pills at all? If not, the photo stays with a Retake button.
        let search = await analyzer.findPills(in: captured)
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
        askToConfirm(photo: photo, boxes: found.map(\.box),
                     identification: Task { await analyzer.identify(found, in: captured) })
    }

    /// Shows the photo with the pills found circled. Nothing is recorded, and no result
    /// shown, until the person says every pill is circled.
    func askToConfirm(photo: CGImage, boxes: [CGRect], identification: Task<PillIdentification, Never>) {
        self.identification = identification
        phase = .confirming(FoundPills(photo: photo, boxes: boxes))
    }

    /// The person says every pill in the photo is circled: on to the results, as soon
    /// as the pills are recognized.
    func confirmPills() async {
        guard case .confirming(let found) = phase, let identification else { return }
        phase = .checking(found)
        let task = Task { [weak self] in
            let identified = await identification.value
            guard let self, !Task.isCancelled else { return }
            self.identification = nil
            showResults(identified.pills, photo: found.photo, mayHaveMissedPill: identified.mayHaveMissedPill)
        }
        checkTask = task
        await task.value
    }

    /// The person says a pill isn't circled: the photo is no good, so take another.
    func rejectPills() async {
        await scanAgain()
    }

    private func cancelChecks() {
        checkTask?.cancel()
        checkTask = nil
        identification?.cancel()
        identification = nil
    }

    /// Back to aiming when the camera couldn't take the photo. The quality check starts
    /// over, so another photo is only taken once the picture has been good again.
    private func aimAgain() {
        guard isOpen else { return }
        phase = .aiming
        scanner.reset()
    }

    /// Turns the analyzed pills into verdicts against today's schedule and records the
    /// doses that are OK to take as scanned.
    /// - Parameter records: false to show results without changing the record (the demo).
    /// - Parameter mayHaveMissedPill: Something pill-like in the photo wasn't found.
    func showResults(_ pills: [AnalyzedPill], photo: CGImage, now: Date = Date(), records: Bool = true,
                     mayHaveMissedPill: Bool = false) {
        guard !pills.isEmpty else {
            phase = .retake(photo, .noPills)
            return
        }
        // A retake replaces this session's earlier photo; otherwise the pills scanned a
        // moment ago would look already scanned.
        if records {
            store.removeScans(of: recordedThisSession)
            recordedThisSession = []
        }
        let identities = pills.map { pill in store.medications.first { $0.id == pill.match.medicationID } }
        let check = store.check(identities, now: now)
        let scanned = pills.indices.map { index in
            ScannedPill(id: index + 1, box: pills[index].box, crop: pills[index].crop, medication: identities[index],
                        verdict: check.verdicts[index], match: pills[index].match)
        }
        let result = PillScanResult(photo: photo, pills: scanned, mayHaveMissedPill: mayHaveMissedPill)
        if records {
            store.recordScan(of: result.dosesToTake, at: now)
            recordedThisSession = result.dosesToTake
        }
        phase = .results(result)
    }

    /// From a photo that couldn't be checked, back to the live camera for another.
    func retake() async {
        await scanAgain()
    }

    /// Back to the live camera for another photo.
    func scanAgain() async {
        cancelChecks()
        phase = .aiming
        scanner.reset()
        await scanner.start(visibleAspect: visibleAspect)
    }

    /// The app came back to the screen. While aiming, the camera starts again from
    /// "checking": the picture may have changed, and camera access may have just been
    /// turned on in Settings.
    func appBecameActive() async {
        guard isOpen, case .aiming = phase else { return }
        scanner.reset()
        await scanner.start(visibleAspect: visibleAspect)
    }

    /// The app left the screen: the system stops the camera and its light.
    func appWentToBackground() {
        scanner.appWentToBackground()
    }

    /// Starts or stops the camera to match `isOpen`. Each opening starts from "checking".
    func syncCamera() async {
        if isOpen {
            scanner.reset()
            await scanner.start(visibleAspect: visibleAspect)
        } else {
            scanner.stop()
        }
    }
}
