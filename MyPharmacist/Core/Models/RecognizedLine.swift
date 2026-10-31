//
//  RecognizedLine.swift
//  MyPharmacist
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

/// Everything read from one camera frame.
nonisolated struct RecognizedFrame: Sendable, Equatable {
    /// Top of the label first.
    let lines: [RecognizedLine]
    /// Upright size of the frame the boxes are measured against.
    let size: CGSize
}
