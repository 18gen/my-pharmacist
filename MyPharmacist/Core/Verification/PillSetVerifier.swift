//
//  PillSetVerifier.swift
//  MyPharmacist
//

import Foundation

/// Decides, for all the pills in one photo at once, which to take now. Pure rules, so
/// they can be tested with mock data.
nonisolated enum PillSetVerifier {
    /// One verdict per pill, in the same order as the pills given.
    /// - Parameters:
    ///   - identities: What each pill was recognized as, or nil if it wasn't.
    ///   - doses: The doses around now (`DoseSchedule.doses(for:around:)`).
    ///   - scannedAt: When each dose's pill was scanned, keyed by `Dose.id`.
    ///   - takenAt: When each dose was marked taken, keyed the same way.
    static func check(_ identities: [Medication?], doses: [Dose], scannedAt: [String: Date],
                      takenAt: [String: Date] = [:], now: Date) -> [PillVerdict] {
        var counted: Set<String> = []
        return identities.map { medication -> PillVerdict in
            guard let medication else { return .unidentified }
            // A dose is one tablet, so a second pill of the same medication is never taken.
            guard counted.insert(medication.id).inserted else { return .extra(medication) }
            // Only the person can tell whether it's needed now.
            if medication.asNeeded != nil { return .asNeeded(medication) }
            return PillVerdict(DoseSchedule.decision(for: medication, doses: doses, scannedAt: scannedAt,
                                                     takenAt: takenAt, now: now))
        }
    }
}
