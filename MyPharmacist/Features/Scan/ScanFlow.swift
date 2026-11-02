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

/// One scanning session, from opening the camera to closing it: wait for a good
/// picture, take one photo, find and recognize each pill in it, and show which to take.
/// Nothing is marked taken until the person confirms.
@Observable
final class ScanFlow {
    enum Phase {
        /// Live camera with picture-quality hints.
        case aiming
        /// Photo being taken and checked.
        case checking(CGImage?)
        case results(PillScanResult)
        /// The photo had no separate pill-sized objects in it.
        case noPills(CGImage)

        /// The phase without its data, for animations and haptics.
        var step: Step {
            switch self {
            case .aiming: .aiming
            case .checking: .checking
            case .results: .results
            case .noPills: .noPills
            }
        }
    }

    enum Step: Hashable {
        case aiming, checking, results, noPills
    }

    private(set) var isOpen = false
    private(set) var phase: Phase = .aiming
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
        isOpen = open
    }

    /// Takes the photo by itself as soon as the picture has been good for a moment.
    func captureStatusChanged(_ status: QualityGate.Status) {
        if status == .ready {
            capture()
        }
    }

    /// Takes the photo and checks the pills in it. Ignored unless the camera is aiming.
    func capture() {
        guard isOpen, case .aiming = phase else { return }
        phase = .checking(nil)
        checkTask = Task { [weak self] in
            guard let self else { return }
            guard let photo = await self.scanner.capturePhoto() else {
                // The camera couldn't take it; go back to aiming and let it try again.
                if case .checking = self.phase { self.phase = .aiming }
                return
            }
            self.phase = .checking(photo)
            self.scanner.stop()
            let pills = await self.analyzer.analyze(photo)
            guard !Task.isCancelled else { return }
            self.showResults(photo: photo, pills: pills)
        }
    }

    /// Turns the analyzed pills into verdicts against today's schedule.
    func showResults(photo: CGImage, pills: [AnalyzedPill], now: Date = Date()) {
        guard !pills.isEmpty else {
            phase = .noPills(photo)
            return
        }
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
