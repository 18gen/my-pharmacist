//
//  LabelAnalyzerTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Testing
@testable import MyPharmacist

struct LabelAnalyzerTests {
    private func lines(_ texts: [String]) -> [RecognizedLine] {
        texts.enumerated().map { index, text in
            RecognizedLine(text: text, box: CGRect(x: 0.1, y: 0.9 - Double(index) * 0.1, width: 0.8, height: 0.05))
        }
    }

    @Test func marksTheNameAndFrequencyLines() {
        let reading = LabelAnalyzer.analyze(lines([
            "RX# 1234567",
            "ATORVASTATIN 20 MG TABLET",
            "TAKE 1 TABLET BY MOUTH TWICE",
            "A DAY WITH FOOD",
        ]))
        #expect(reading.lines.map(\.role) == [.other, .name, .frequency, .frequency])
        #expect(reading.medicationName == "ATORVASTATIN 20 MG")
        #expect(reading.frequency == "Twice daily")
    }

    @Test func theNameLineKeepsItsRoleWhenItAlsoHasTheFrequency() {
        let reading = LabelAnalyzer.analyze(lines(["LISINOPRIL 10 MG ONCE DAILY"]))
        #expect(reading.lines.map(\.role) == [.name])
        #expect(reading.frequency == "Once daily")
    }

    @Test func unrelatedTextIsLeftAlone() {
        let reading = LabelAnalyzer.analyze(lines(["CVS PHARMACY", "123 MAIN ST"]))
        #expect(reading.lines.allSatisfy { $0.role == .other })
        #expect(reading.medicationName == nil)
        #expect(reading.frequency == nil)
    }
}
