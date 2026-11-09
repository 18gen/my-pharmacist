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

/// Everything found in one photo. The photo stays in memory only while the results show.
struct PillScanResult {
    let photo: CGImage
    let pills: [ScannedPill]
    /// Doses due now that weren't in the photo.
    let missing: [Dose]

    var dosesToTake: [Dose] {
        pills.compactMap { if case .take(let dose) = $0.verdict { dose } else { nil } }
    }
    var notToTakeCount: Int { pills.count - dosesToTake.count }
}

/// One scanning session, from opening the camera to closing it. There is no shutter:
/// 1. wait until the camera picture has been good for a moment, then take a photo;
/// 2. find the pills in it, and if there are none, go back to the camera and try again;
/// 3. turn the camera off, cut out each pill and recognize it on its own, then show the
///    results on a page of their own.
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
        /// The photo had no pills in it: it stays on screen with a Retake button.
        case noPills(CGImage)
        /// This many pills found; the camera is off and each is being checked (step 3).
        case checking(count: Int)
        case results(PillScanResult)

        /// The phase without its data, for animations and haptics.
        var step: Step {
            switch self {
            case .aiming: .aiming
            case .finding: .finding
            case .noPills: .noPills
            case .checking: .checking
            case .results: .results
            }
        }
    }

    enum Step: Hashable {
        case aiming, finding, noPills, checking, results

        /// The camera is done and the scan view has become the results page.
        var isPage: Bool { self == .checking || self == .results }
    }

    private(set) var isOpen = false
    private(set) var phase: Phase = .aiming
    let scanner: ScannerModel

    @ObservationIgnored private let store: MedicationStore
    @ObservationIgnored private var analyzer: PillPhotoAnalyzer
    /// The medications `analyzer` compares against, by ID.
    @ObservationIgnored private var analyzedMedicationIDs: [String]
    @ObservationIgnored private var checkTask: Task<Void, Never>?
    /// Doses this session recorded as scanned, so a retake can replace them.
    @ObservationIgnored private var recordedThisSession: [Dose] = []

    init(store: MedicationStore, scanner: ScannerModel = ScannerModel()) {
        self.store = store
        self.scanner = scanner
        self.analyzer = PillPhotoAnalyzer(medications: store.medications)
        self.analyzedMedicationIDs = store.medications.map(\.id)
    }

    /// Closing ends the session; opening starts the next one fresh. The phase is reset on
    /// opening, not closing, so the closing view keeps showing what it showed (the results,
    /// say) while it shrinks away, instead of switching to the camera on the way out.
    func setOpen(_ open: Bool) {
        checkTask?.cancel()
        checkTask = nil
        if open {
            phase = .aiming
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
        analyzer = PillPhotoAnalyzer(medications: store.medications)
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
            guard let photo = await scanner.capturePhoto(), !Task.isCancelled else {
                // The camera couldn't take it; aim again and let the next good moment retry.
                aimAgain()
                return
            }
            // The camera is done: the photo it took shows in its place.
            scanner.stop()
            phase = .finding(photo)

            // Step 2: are there pills at all? If not, the photo stays with a Retake button.
            let found = await analyzer.findPills(in: photo)
            guard !Task.isCancelled else { return }
            guard !found.isEmpty else {
                phase = .noPills(photo)
                return
            }

            // Step 3: check each pill.
            phase = .checking(count: found.count)
            let pills = await analyzer.identify(found, in: photo)
            guard !Task.isCancelled else { return }
            showResults(pills, photo: photo)
        }
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
    func showResults(_ pills: [AnalyzedPill], photo: CGImage, now: Date = Date(), records: Bool = true) {
        guard !pills.isEmpty else {
            phase = .noPills(photo)
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
        let result = PillScanResult(photo: photo, pills: scanned, missing: check.missing)
        if records {
            store.recordScan(of: result.dosesToTake, at: now)
            recordedThisSession = result.dosesToTake
        }
        phase = .results(result)
    }

    /// From a photo with no pills, back to the live camera for another.
    func retake() async {
        await scanAgain()
    }

    /// Back to the live camera for another photo.
    func scanAgain() async {
        checkTask?.cancel()
        checkTask = nil
        phase = .aiming
        scanner.reset()
        await scanner.start()
    }

    /// Starts or stops the camera to match `isOpen`. Each opening starts from "checking".
    func syncCamera() async {
        if isOpen {
            scanner.reset()
            await scanner.start()
        } else {
            scanner.stop()
        }
    }
}
