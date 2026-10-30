//
//  RecognizedLine.swift
//  MedLens
//

import CoreGraphics

/// One line of text Vision read, and where it is in the frame.
nonisolated struct RecognizedLine: Sendable, Equatable {
    enum Role: Sendable { case other, name, frequency }

    let text: String
    /// Vision's normalized box in the upright frame: 0–1, origin at the bottom-left.
    let box: CGRect
    var role: Role = .other
}
