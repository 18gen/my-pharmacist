//
//  ScanResult.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation

/// The pills found in a photo, before they are recognized: what the person is asked to
/// look over.
struct FoundPills {
    let photo: CGImage
    /// Each pill's box, normalized 0–1 with the origin at the top left of the photo.
    let boxes: [CGRect]
}

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
}

/// Everything found in one photo. Kept in memory only, never saved: the photo while the
/// results show, and the cut-outs of pills marked taken until the app is closed (Home shows
/// them). Only what was scanned: doses due now that weren't in the photo aren't part of it.
struct PillScanResult {
    let photo: CGImage
    let pills: [ScannedPill]
    /// The vision model saw something pill-like in the photo that wasn't found as a
    /// pill, so these may not be all the pills there are.
    var mayHaveMissedPill = false

    /// The recognized pills judged against the person's schedule.
    /// - Parameter ignored: What this scanning session marked taken a moment ago, judged
    ///   as if it hadn't been (`ScanSessionRecord`).
    static func judging(_ pills: [AnalyzedPill], photo: CGImage, store: MedicationStore, now: Date,
                        ignoring ignored: ScanSessionRecord = ScanSessionRecord(),
                        mayHaveMissedPill: Bool = false) -> PillScanResult {
        let identities = pills.map { pill in store.medications.first { $0.id == pill.medicationID } }
        let verdicts = store.verdicts(for: identities, now: now, ignoring: ignored)
        let scanned = pills.indices.map { index in
            ScannedPill(id: index + 1, box: pills[index].box, crop: pills[index].crop, medication: identities[index],
                        verdict: verdicts[index])
        }
        return PillScanResult(photo: photo, pills: scanned, mayHaveMissedPill: mayHaveMissedPill)
    }

    /// The doses whose pills are OK to take now.
    var dosesToTake: [Dose] {
        pills.compactMap(\.verdict.doseToTake)
    }

    /// The medications taken only when needed that are in the photo, each once.
    var asNeededMedications: [Medication] {
        var seen: Set<String> = []
        return pills.compactMap { pill -> Medication? in
            guard case .asNeeded(let medication) = pill.verdict, seen.insert(medication.id).inserted else { return nil }
            return medication
        }
    }

    /// The cut-out of the first pill of a medication taken only when needed.
    func firstCrop(of medication: Medication) -> CGImage? {
        pills.first { pill in
            if case .asNeeded(let found) = pill.verdict { found.id == medication.id } else { false }
        }?.crop
    }
}
