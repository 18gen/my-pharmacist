//
//  PillPhotoAnalyzer.swift
//  MyPharmacist
//

import os
import UIKit

/// One pill from the photo and what it was recognized as.
nonisolated struct AnalyzedPill: Sendable {
    let box: CGRect
    let crop: CGImage
    /// The medication it is, or nil when it isn't one of the person's, or the checker
    /// wasn't sure.
    let medicationID: String?
}

/// Every pill found in a photo, recognized.
nonisolated struct PillIdentification: Sendable {
    let pills: [AnalyzedPill]
    /// The checker saw something pill-like in the photo that wasn't found as a pill.
    /// Only ever a reason for more care.
    var mayHaveMissedPill = false
}

/// Finds the pills in a photo (on the device) and has each one recognized by the pill
/// check server, against the person's medications and their photos. This is the place
/// to swap in a recognizer that runs on the device later.
///
/// An actor so the work runs off the main thread and the medications' pictures are
/// prepared once and reused.
actor PillPhotoAnalyzer {
    private let medications: [Medication]
    private let client: PillCheckClient?
    private var candidates: [PillCheckClient.Candidate]?
    #if DEBUG
    /// Debug demos (-noCloud): every pill comes back unknown, without the server.
    private let answersUnknown: Bool
    #endif

    init(medications: [Medication],
         client: PillCheckClient? = PillCheckClient.Configuration.fromBundle().map { PillCheckClient(configuration: $0) },
         answersUnknown: Bool = false) {
        self.medications = medications
        self.client = client
        #if DEBUG
        self.answersUnknown = answersUnknown
        #endif
    }

    /// Step 2 of a scan: the pills in the photo, each cut out, or why there are none
    /// to check.
    func findPills(in photo: CapturedPhoto) -> PillSearch {
        PillFinder.find(in: photo)
    }

    /// Step 3 of a scan: recognizes each pill, in the order given, or says why it
    /// couldn't. With no medications on the list there's nothing to compare with, and
    /// every pill is unknown without asking.
    func identify(_ pills: [FoundPill], in photo: CapturedPhoto) async -> Result<PillIdentification, PillCheckClient.Failure> {
        let unknown = PillIdentification(pills: pills.map { AnalyzedPill(box: $0.box, crop: $0.crop, medicationID: nil) })
        #if DEBUG
        if answersUnknown { return .success(unknown) }
        #endif
        guard !medications.isEmpty, !pills.isEmpty else { return .success(unknown) }
        guard let client else { return .failure(.notConfigured) }

        // Each pill cut from the full-size photo, in the middle of its own picture, and
        // all of them together, numbered, so the checker can say whether something
        // pill-like was left out.
        let pictures = pills.compactMap { pill in
            PillCropper.picture(of: pill, in: photo).flatMap { PillCheckClient.jpeg($0, maxSide: PillCropper.largestSide) }
        }
        guard pictures.count == pills.count else { return .failure(.unusable) }
        let overview = PillCropper.overview(of: pills, in: photo).flatMap { PillCheckClient.jpeg($0, maxSide: PillCropper.overviewSide) }

        do {
            let reading = try await client.check(pictures, overview: overview, among: candidateList())
            return .success(PillIdentification(
                pills: zip(pills, reading.medicationIDs).map { pill, id in
                    AnalyzedPill(box: pill.box, crop: pill.crop, medicationID: id)
                },
                mayHaveMissedPill: reading.mayHaveMissedPill
            ))
        } catch {
            ScanLog.logger.error("Pill check failed: \(String(describing: error), privacy: .public)")
            return .failure(error)
        }
    }

    /// The medications as the checker sees them: a line each and their photos.
    private func candidateList() -> [PillCheckClient.Candidate] {
        if let candidates { return candidates }
        let made = medications.map { medication in
            let description = [medication.displayName, medication.appearance].filter { !$0.isEmpty }.joined(separator: " · ")
            let photos = medication.photos
                .compactMap { MedicationPhotoStore.standard.image($0)?.cgImage }
                .compactMap { PillCheckClient.jpeg($0, maxSide: 256) }
            return PillCheckClient.Candidate(id: medication.id, description: description, photos: photos)
        }
        candidates = made
        return made
    }
}
