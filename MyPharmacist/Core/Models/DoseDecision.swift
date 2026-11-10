//
//  DoseDecision.swift
//  MyPharmacist
//

import Foundation

/// What one pill of a medication means for that medication's doses right now.
nonisolated enum DoseDecision: Hashable, Sendable {
    /// This pill is the dose to take now.
    case take(Dose)
    /// The latest dose was already scanned, so this pill may have been taken already;
    /// `next` is the next dose, if any.
    case alreadyScanned(Dose, at: Date, next: Dose?)
    /// The latest dose wasn't scanned and is more than `DoseSchedule.lateWindow` past:
    /// too late to take it now without asking. `next` is the next dose, if any.
    case missed(Dose, next: Dose?)
    /// No dose has passed yet and the next is more than `earlyWindow` away.
    case tooEarly(next: Dose)
    /// The medication has no doses scheduled around now.
    case notScheduledToday(Medication)
}
