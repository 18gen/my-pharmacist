//
//  DoseDecision.swift
//  MyPharmacist
//

import Foundation

/// What one pill of a medication means for that medication's doses right now.
nonisolated enum DoseDecision: Hashable, Sendable {
    /// This pill is the dose to take now.
    case take(Dose)
    /// Every dose due so far was already taken; `next` is the next one today, if any.
    case alreadyTaken(Dose, at: Date, next: Dose?)
    /// Nothing taken yet and the first dose is more than `earlyWindow` away.
    case tooEarly(next: Dose)
    /// The medication has no doses scheduled today.
    case notScheduledToday(Medication)
}
