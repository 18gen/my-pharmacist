//
//  Medication.swift
//  MyPharmacist
//

import Foundation

/// A medication the person takes, with the times of day they take it, or taken only when
/// needed.
nonisolated struct Medication: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let strength: String
    let doseTimes: [DoseTime]
    /// What the tablet looks like, for people: "Pink oval · XELODA / 500".
    var appearance: String = ""
    /// Asset names of reference photos of the tablet, both sides. The first is the one
    /// shown in lists; all of them are compared against scanned pills.
    var photos: [String] = []
    /// What it's for, in the person's words: "Cancer treatment". People often know their
    /// medications by this rather than by name.
    var purpose: String = ""
    /// For a medication taken only when needed, when that is, as said to the person:
    /// "Only when you feel sick". Such a medication has no dose times. Nil when it is
    /// taken on a schedule.
    var asNeeded: String? = nil

    var displayName: String { "\(name) \(strength)" }
}
