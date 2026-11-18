//
//  CheckLimits.swift
//  MyPharmacist
//

import Foundation

/// How much one check of pills can hold. The pill check server (`server/pill-check`,
/// `limits` in check.ts) turns down any request with more, so the app keeps within it:
/// otherwise every scan would fail, in the same way, until the list was shortened.
nonisolated enum CheckLimits {
    /// Pills checked from one photo.
    static let pills = 12
    /// Medications the pills are compared with: the whole list.
    static let medications = 20
    /// Characters in a medication's name, strength and appearance. With the separators
    /// between them they stay well under the server's 300 for the line describing it.
    static let nameLength = 60
    static let strengthLength = 30
    static let appearanceLength = 150
}
