//
//  DoseDecision.swift
//  MyPharmacist
//

import Foundation

/// What one pill of a medication means for that medication's doses right now.
nonisolated enum DoseDecision: Hashable, Sendable {
    /// This pill is the dose to take now.
    case take(Dose)
    /// Every dose due so far was already scanned, so this pill may have been taken
    /// already; `next` is the next dose today, if any.
    case alreadyScanned(Dose, at: Date, next: Dose?)
    /// Nothing scanned yet and the first dose is more than `earlyWindow` away.
    case tooEarly(next: Dose)
    /// The medication has no doses scheduled today.
    case notScheduledToday(Medication)
}
