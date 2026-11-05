//
//  PillSetVerifier.swift
//  MyPharmacist
//

import Foundation

/// Decides, for all the pills in one photo at once, which to take now. Pure rules, so
/// they can be tested with mock data.
nonisolated enum PillSetVerifier {
    /// - Parameter identities: what each pill was recognized as, or nil if it wasn't.
    static func check(_ identities: [Medication?], medications: [Medication], dayDoses: [Dose],
                      scannedAt: [String: Date], now: Date) -> PillSetCheck {
        var counted: Set<String> = []
        let verdicts = identities.map { medication -> PillVerdict in
            guard let medication else { return .unidentified }
            // A dose is one pill, so a second pill of the same medication is never taken.
            guard counted.insert(medication.id).inserted else { return .extra(medication) }
            // Only the person can tell whether it's needed now.
            if medication.asNeeded != nil { return .asNeeded(medication) }
            return PillVerdict(DoseSchedule.decision(for: medication, dayDoses: dayDoses, scannedAt: scannedAt, now: now))
        }

        let missing = medications
            .filter { !counted.contains($0.id) }
            .compactMap { medication -> Dose? in
                if case .take(let dose) = DoseSchedule.decision(for: medication, dayDoses: dayDoses, scannedAt: scannedAt, now: now) {
                    return dose
                }
                return nil
            }
            .sorted { ($0.scheduled, $0.medication.name) < ($1.scheduled, $1.medication.name) }

        return PillSetCheck(verdicts: verdicts, missing: missing)
    }
}
