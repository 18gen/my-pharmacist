//
//  ScanOutcome.swift
//  MyPharmacist
//

import Foundation

/// What happened when a label was scanned.
nonisolated enum ScanOutcome: Hashable, Sendable {
    /// The dose was marked taken just now.
    case checked(Dose)
    /// Every dose due so far was already taken; `next` is the next one today, if any.
    case alreadyTaken(Dose, at: Date, next: Dose?)
    /// Nothing taken yet and the first dose is more than `earlyWindow` away.
    case tooEarly(next: Dose)
    /// The medication has no doses scheduled today.
    case notScheduledToday(Medication)
    /// The scanned medication is not one of the registered ones.
    case notOnList(scannedName: String)
    /// More than one registered medication fits the scanned text.
    case unsure(scannedName: String)
}
