//
//  StableReading.swift
//  MedLens
//

import Foundation

/// Confirms a value once it has been seen `required` times in a row.
/// Frames where nothing was read are ignored rather than counted.
struct StableReading {
    var required = 3
    private var candidate: String?
    private var count = 0

    mutating func confirm(_ value: String?) -> String? {
        guard let value else { return nil }
        if value == candidate {
            count += 1
        } else {
            candidate = value
            count = 1
        }
        return count >= required ? value : nil
    }
}
