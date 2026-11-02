//
//  Medication.swift
//  MyPharmacist
//

import Foundation

/// A medication the person takes, with the times of day they take it.
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

    var displayName: String { "\(name) \(strength)" }
}
