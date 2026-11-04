//
//  ScanFlow.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import Observation

/// One pill in the results: its number, where it is in the photo, the cut-out, what it
/// was recognized as and whether to take it.
struct ScannedPill: Identifiable {
    /// 1, 2, 3… in reading order, matching the numbers drawn on the photo.
    let id: Int
    let box: CGRect
    let crop: CGImage
    let medication: Medication?
    let verdict: PillVerdict
    let match: PillMatch
}

/// Everything found in one photo.
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
/// 3. cut out each pill and recognize it on its own, then show which to take.
/// Nothing is marked taken until the person confirms.
@Observable
final class ScanFlow {
    enum Phase {
        /// Live camera with picture-quality hints (step 1).
        case aiming
        /// Photo being taken (nil) or searched for pills (step 2).
        case finding(CGImage?)
        /// Pills found at these boxes (normalized, top-left origin); each being checked (step 3).
        case verifying(CGImage, boxes: [CGRect])
        case results(PillScanResult)

        /// The phase without its data, for animations and haptics.
        var step: Step {
            switch self {
            case .aiming: .aiming
            case .finding: .finding
            case .verifying: .verifying
            case .results: .results
            }
        }
    }

    enum Step: Hashable {
        case aiming, finding, verifying, results
    }

    private(set) var isOpen = false
    private(set) var phase: Phase = .aiming
    /// The last photo had no pills in it; shown as a hint while aiming again.
    private(set) var foundNoPills = false
    let scanner: ScannerModel

    @ObservationIgnored private let store: MedicationStore
    @ObservationIgnored private let analyzer: PillPhotoAnalyzer
    @ObservationIgnored private var checkTask: Task<Void, Never>?

    init(store: MedicationStore, scanner: ScannerModel = ScannerModel()) {
        self.store = store
        self.scanner = scanner
        self.analyzer = PillPhotoAnalyzer(medications: store.medications)
    }

    /// Opening or closing always starts the next session fresh.
    func setOpen(_ open: Bool) {
        checkTask?.cancel()
        checkTask = nil
        phase = .aiming
        foundNoPills = false
        isOpen = open
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
            phase = .finding(photo)

            // Step 2: are there pills at all? The camera keeps running meanwhile, so
            // going back to aiming is instant.
            let found = await analyzer.findPills(in: photo)
            guard !Task.isCancelled else { return }
            guard !found.isEmpty else {
                noPillsFound()
                return
            }

            // Step 3: check each pill's cut-out.
            foundNoPills = false
            scanner.stop()
            phase = .verifying(photo, boxes: found.map(\.box))
            let pills = await analyzer.identify(found)
            guard !Task.isCancelled else { return }
            showResults(photo: photo, pills: pills)
        }
    }

    /// Back to the live camera with the "no pills" hint; the next good moment retries.
    private func noPillsFound() {
        foundNoPills = true
        aimAgain()
    }

    /// Back to aiming from a photo that didn't lead to results. The quality check starts
    /// over, so another photo is only taken once the picture has been good again.
    private func aimAgain() {
        guard isOpen else { return }
        phase = .aiming
        scanner.reset()
    }

    /// Turns the analyzed pills into verdicts against today's schedule.
    func showResults(photo: CGImage, pills: [AnalyzedPill], now: Date = Date()) {
        guard !pills.isEmpty else {
            noPillsFound()
            return
        }
        foundNoPills = false
        let identities = pills.map { pill in store.medications.first { $0.id == pill.match.medicationID } }
        let check = store.check(identities, now: now)
        let scanned = pills.indices.map { index in
            ScannedPill(id: index + 1, box: pills[index].box, crop: pills[index].crop,
                        medication: identities[index], verdict: check.verdicts[index], match: pills[index].match)
        }
        phase = .results(PillScanResult(photo: photo, pills: scanned, missing: check.missing))
    }

    /// Back to the live camera for another photo.
    func scanAgain() async {
        checkTask?.cancel()
        checkTask = nil
        phase = .aiming
        foundNoPills = false
        scanner.reset()
        await scanner.start()
    }

    /// Marks the doses of the pills shown as "Take now" as taken. Returns how many.
    @discardableResult
    func confirmTaken(now: Date = Date()) -> Int {
        guard case .results(let result) = phase else { return 0 }
        for dose in result.dosesToTake {
            store.markTaken(dose, at: now)
        }
        return result.dosesToTake.count
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
