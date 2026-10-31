//
//  PrescriptionParserTests.swift
//  MyPharmacistTests
//

import Testing
@testable import MyPharmacist

struct PrescriptionParserTests {
    private let label = [
        "RX# 1234567",
        "ATORVASTATIN 20 MG TABLET",
        "TAKE 1 TABLET BY MOUTH TWICE",
        "A DAY WITH FOOD",
    ]

    @Test func medicationNameIsTheFirstNameAndStrengthLine() {
        #expect(PrescriptionParser.medicationName(in: label) == "ATORVASTATIN 20 MG")
        #expect(PrescriptionParser.medicationLineIndex(in: label) == 1)
    }

    @Test func directionsAndStrayLettersAreNotNames() {
        #expect(PrescriptionParser.medicationName(in: ["TAKE 1 TABLET 10 MG"]) == nil)
        #expect(PrescriptionParser.medicationName(in: ["AB 10 MG"]) == nil)
    }

    @Test(arguments: [
        (["TAKE 1 TABLET BY MOUTH TWICE DAILY"], "Twice daily"),
        (["Take one tablet three times a day"], "Three times daily"),
        (["TAKE 1 TABLET EVERY 8 HOURS"], "Every 8 hours"),
        (["Take 1 tablet once weekly"], "Once weekly"),
        (["TAKE 1 TABLET DAILY AS NEEDED"], "Daily, as needed"),
        (["Take as needed for pain.", "Do not exceed 3 tablets daily"], "As needed"),
    ])
    func frequency(_ lines: [String], _ expected: String) {
        #expect(PrescriptionParser.frequency(in: lines) == expected)
    }

    @Test func noFrequencyWithoutDirections() {
        #expect(PrescriptionParser.frequency(in: ["ATORVASTATIN 20 MG"]) == nil)
    }

    @Test func frequencyWrappedOverTwoLines() {
        #expect(PrescriptionParser.frequency(in: label) == "Twice daily")
        #expect(PrescriptionParser.frequencyLineIndices(in: label) == [2, 3])
    }
}
