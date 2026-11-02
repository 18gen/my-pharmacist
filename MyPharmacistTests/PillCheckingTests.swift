//
//  PillCheckingTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MyPharmacist

struct PillSetVerifierTests {
    private let medications = TestMedications.all
    private let dayDoses = DoseSchedule.doses(for: TestMedications.all, on: TestClock.day, calendar: TestClock.calendar)

    private func dose(_ medication: Medication, at hour: Int) -> Dose {
        Dose(medication: medication, time: DoseTime(hour), day: TestClock.day, calendar: TestClock.calendar)
    }

    private func check(_ identities: [Medication?], takenAt: [String: Date] = [:], at hour: Int) -> PillSetCheck {
        PillSetVerifier.check(identities, medications: medications, dayDoses: dayDoses, takenAt: takenAt, now: TestClock.at(hour))
    }

    @Test func theMorningPillsAreAllToTake() {
        let result = check([TestMedications.metformin, TestMedications.lisinopril], at: 8)
        #expect(result.verdicts == [.take(dose(TestMedications.metformin, at: 8)), .take(dose(TestMedications.lisinopril, at: 8))])
        #expect(result.missing.isEmpty)
    }

    @Test func aPillForLaterTodayIsNotToTake() {
        let result = check([TestMedications.atorvastatin], at: 8)
        #expect(result.verdicts == [.tooEarly(next: dose(TestMedications.atorvastatin, at: 21))])
    }

    @Test func aSecondPillOfTheSameMedicationIsExtra() {
        let result = check([TestMedications.metformin, TestMedications.metformin], at: 8)
        #expect(result.verdicts[1] == .extra(TestMedications.metformin))
        #expect(result.dosesToTake.count == 1)
    }

    @Test func unrecognizedPillsAreNeverToTake() {
        let result = check([nil], at: 8)
        #expect(result.verdicts == [.unidentified])
        #expect(result.dosesToTake.isEmpty)
    }

    @Test func dosesDueNowThatArentInThePhotoAreMissing() {
        let result = check([TestMedications.metformin], at: 8)
        #expect(result.missing == [dose(TestMedications.lisinopril, at: 8)])
    }

    @Test func alreadyTakenDosesAreNotMissing() {
        let lisinopril = dose(TestMedications.lisinopril, at: 8)
        let result = check([TestMedications.lisinopril], takenAt: [lisinopril.id: TestClock.at(8)], at: 9)
        #expect(result.verdicts == [.alreadyTaken(lisinopril, at: TestClock.at(8), next: nil)])
        #expect(result.missing == [dose(TestMedications.metformin, at: 8)])
    }
}

struct PillMatchRuleTests {
    private let rule = PillMatchRule()

    @Test func aCloseAndClearMatch() {
        #expect(rule.match(["a": 0.3, "b": 0.7]) == PillMatch(medicationID: "a", distance: 0.3))
    }

    @Test func tooFarFromEverythingIsNoMatch() {
        #expect(rule.match(["a": 0.95, "b": 1.2]).medicationID == nil)
    }

    @Test func twoMedicationsTooAlikeIsNoMatch() {
        #expect(rule.match(["a": 0.40, "b": 0.42]).medicationID == nil)
    }

    @Test func nothingToCompareWith() {
        #expect(rule.match([:]) == PillMatch(medicationID: nil, distance: nil))
    }
}

struct InstanceBoxesTests {
    @Test func measuresEachLabelledObject() {
        // 4×2 mask: object 1 in the top-left 2×1, object 2 a single pixel bottom-right.
        let labels: [UInt8] = [1, 1, 0, 0,
                               0, 0, 0, 2]
        let boxes = InstanceBoxes.boxes(labels: labels, width: 4, height: 2)
        #expect(boxes[1]?.box == CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        #expect(boxes[1]?.area == 0.25)
        #expect(boxes[2]?.box == CGRect(x: 0.75, y: 0.5, width: 0.25, height: 0.5))
        #expect(boxes[0] == nil)
    }

    @Test func readingOrderIsRowsTopToBottomThenLeftToRight() {
        let boxes = [
            CGRect(x: 0.6, y: 0.10, width: 0.1, height: 0.1),  // top right
            CGRect(x: 0.1, y: 0.52, width: 0.1, height: 0.1),  // bottom left
            CGRect(x: 0.1, y: 0.12, width: 0.1, height: 0.1),  // top left, slightly lower
            CGRect(x: 0.6, y: 0.50, width: 0.1, height: 0.1),  // bottom right
        ]
        #expect(InstanceBoxes.readingOrder(boxes) == [2, 0, 1, 3])
    }
}
