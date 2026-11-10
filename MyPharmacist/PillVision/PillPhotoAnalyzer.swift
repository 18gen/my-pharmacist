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

/// Finds the pills in a photo (on the device) and has each one recognized, against the
/// person's medications and their photos. What recognizes them is a `PillRecognizer`:
/// the pill check server unless another is given.
///
/// An actor so the work runs off the main thread.
actor PillPhotoAnalyzer {
    private let medications: [Medication]
    private let recognizer: (any PillRecognizer)?
    #if DEBUG
    /// Debug demos (-noCloud): every pill comes back unknown, without the server.
    private let answersUnknown: Bool
    #endif

    init(medications: [Medication],
         recognizer: (any PillRecognizer)? = PillCheckClient.Configuration.fromBundle().map { PillCheckClient(configuration: $0) },
         answersUnknown: Bool = false) {
        self.medications = medications
        self.recognizer = recognizer
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
    func identify(_ pills: [FoundPill], in photo: CapturedPhoto) async -> Result<PillIdentification, PillRecognitionFailure> {
        let unknown = PillIdentification(pills: pills.map { AnalyzedPill(box: $0.box, crop: $0.crop, medicationID: nil) })
        #if DEBUG
        if answersUnknown { return .success(unknown) }
        #endif
        guard !medications.isEmpty, !pills.isEmpty else { return .success(unknown) }
        guard let recognizer else { return .failure(.notConfigured) }

        // Each pill cut from the full-size photo, in the middle of its own picture, and
        // all of them together, numbered, so the recognizer can say whether something
        // pill-like was left out.
        let pictures = pills.compactMap { PillCropper.picture(of: $0, in: photo) }
        guard pictures.count == pills.count else { return .failure(.unusable) }

        do {
            let reading = try await recognizer.recognize(pictures, overview: PillCropper.overview(of: pills, in: photo), among: medications)
            guard reading.answers.count == pills.count else { return .failure(.unusable) }
            // What the app itself doubted, and the recognizer says is no pill, isn't
            // one: skin or a shadow that was cut out. Either doubt alone isn't enough.
            let kept = zip(pills, reading.answers).filter { pill, answer in !(pill.isRough && answer == .notAPill) }
            if kept.count < pills.count {
                ScanLog.logger.info("left out \(pills.count - kept.count) rough areas the recognizer says are no pill")
            }
            return .success(PillIdentification(
                pills: kept.map { pill, answer in
                    AnalyzedPill(box: pill.box, crop: pill.crop, medicationID: answer.medicationID)
                },
                mayHaveMissedPill: reading.mayHaveMissedPill
            ))
        } catch {
            ScanLog.logger.error("Pill check failed: \(String(describing: error), privacy: .public)")
            return .failure(error)
        }
    }
}
