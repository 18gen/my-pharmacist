//
//  LabelAnalyzer.swift
//  MyPharmacist
//

import Foundation

/// What one frame's text says: the medication name and frequency, and which lines they
/// come from so the camera view can box them.
nonisolated struct LabelReading: Sendable, Equatable {
    var lines: [RecognizedLine]
    var medicationName: String?
    var frequency: String?
}

/// Reads a single frame's lines with `PrescriptionParser`. Pure, so it can be tested
/// without a camera; confirming a value across frames is `StableReading`'s job.
nonisolated enum LabelAnalyzer {
    static func analyze(_ lines: [RecognizedLine]) -> LabelReading {
        let texts = lines.map(\.text)

        var lines = lines
        if let index = PrescriptionParser.medicationLineIndex(in: texts) {
            lines[index].role = .name
        }
        // The name line keeps its role if the frequency is printed on it too.
        for index in PrescriptionParser.frequencyLineIndices(in: texts) where lines[index].role == .other {
            lines[index].role = .frequency
        }

        return LabelReading(
            lines: lines,
            medicationName: PrescriptionParser.medicationName(in: texts),
            frequency: PrescriptionParser.frequency(in: texts)
        )
    }
}
