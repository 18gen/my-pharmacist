//
//  DoseDecision.swift
//  MyPharmacist
//

import Foundation

/// What one pill of a medication means for that medication's doses right now.
nonisolated enum DoseDecision: Hashable, Sendable {
    /// This pill is the dose to take now.
    case take(Dose)
    /// The latest dose was taken (ticked, or scanned, which ticks it), so this pill isn't
    /// for it; `next` is the next dose, if any.
    case alreadyTaken(Dose, at: Date, next: Dose?)
    /// The latest dose wasn't taken and is more than `DoseSchedule.lateWindow` past:
    /// too late to take it now without asking. `next` is the next dose, if any.
    case missed(Dose, next: Dose?)
    /// No dose has passed yet and the next is more than `earlyWindow` away.
    case tooEarly(next: Dose)
    /// The medication has no doses scheduled around now.
    case notScheduledToday(Medication)
}
