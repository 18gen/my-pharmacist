//
//  PillVerdict.swift
//  MyPharmacist
//

import Foundation

/// Whether one pill in the photo should be taken now, and why not if it shouldn't.
nonisolated enum PillVerdict: Hashable, Sendable {
    /// The dose this pill counts for, due now.
    case take(Dose)
    /// This dose was scanned before, so the pill may have been taken already.
    case alreadyScanned(Dose, at: Date, next: Dose?)
    /// The dose it would count for is more than two hours past: too late to take it now
    /// without asking a pharmacist.
    case missed(Dose, next: Dose?)
    case tooEarly(next: Dose)
    case notScheduledToday(Medication)
    /// Another pill of a medication already counted in this photo: one pill per dose.
    case extra(Medication)
    /// Not recognized as one of the person's medications, or too unsure to say.
    case unidentified
    /// A medication taken only when needed, such as only when feeling sick.
    case asNeeded(Medication)

    var isTake: Bool {
        if case .take = self { return true }
        return false
    }

    init(_ decision: DoseDecision) {
        switch decision {
        case .take(let dose): self = .take(dose)
        case .alreadyScanned(let dose, let time, let next): self = .alreadyScanned(dose, at: time, next: next)
        case .missed(let dose, let next): self = .missed(dose, next: next)
        case .tooEarly(let next): self = .tooEarly(next: next)
        case .notScheduledToday(let medication): self = .notScheduledToday(medication)
        }
    }
}

/// The verdict for every pill in one photo, plus the doses due now that weren't in it.
nonisolated struct PillSetCheck: Hashable, Sendable {
    /// One per pill, in the same order as the pills given.
    let verdicts: [PillVerdict]
    /// Doses to take now that no pill in the photo was recognized as.
    let missing: [Dose]

    var dosesToTake: [Dose] {
        verdicts.compactMap { if case .take(let dose) = $0 { dose } else { nil } }
    }
}
