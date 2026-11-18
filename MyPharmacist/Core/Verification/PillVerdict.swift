//
//  PillVerdict.swift
//  MyPharmacist
//

import Foundation

/// Whether one pill in the photo should be taken now, and why not if it shouldn't.
nonisolated enum PillVerdict: Hashable, Sendable {
    /// The dose this pill counts for, due now.
    case take(Dose)
    /// The dose it would count for was taken already (ticked, or scanned), so this pill
    /// isn't for it.
    case alreadyTaken(Dose, at: Date, next: Dose?)
    /// The dose it would count for is more than two hours past: too late to take it now
    /// without asking a pharmacist.
    case missed(Dose, next: Dose?)
    case tooEarly(next: Dose)
    case notScheduledToday(Medication)
    /// Another pill of a medication already counted in this photo: one tablet per dose.
    case extra(Medication)
    /// Not recognized as one of the person's medications, or too unsure to say.
    case unidentified
    /// A medication taken only when needed, such as only when feeling sick.
    case asNeeded(Medication)

    /// The dose to take now; nil unless this pill is OK to take.
    var doseToTake: Dose? {
        if case .take(let dose) = self { return dose }
        return nil
    }

    init(_ decision: DoseDecision) {
        switch decision {
        case .take(let dose): self = .take(dose)
        case .alreadyTaken(let dose, let time, let next): self = .alreadyTaken(dose, at: time, next: next)
        case .missed(let dose, let next): self = .missed(dose, next: next)
        case .tooEarly(let next): self = .tooEarly(next: next)
        case .notScheduledToday(let medication): self = .notScheduledToday(medication)
        }
    }
}
