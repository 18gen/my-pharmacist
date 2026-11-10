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

    private func check(_ identities: [Medication?], scannedAt: [String: Date] = [:], at hour: Int) -> PillSetCheck {
        PillSetVerifier.check(identities, medications: medications, doses: dayDoses, scannedAt: scannedAt, now: TestClock.at(hour))
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

    @Test func anAsNeededPillIsLeftToThePerson() {
        let result = PillSetVerifier.check([TestMedications.ondansetron], medications: medications + [TestMedications.ondansetron],
                                           doses: dayDoses, scannedAt: [:], now: TestClock.at(8))
        #expect(result.verdicts == [.asNeeded(TestMedications.ondansetron)])
        #expect(result.dosesToTake.isEmpty)
    }

    @Test func anAsNeededMedicationIsNeverMissing() {
        let result = PillSetVerifier.check([TestMedications.metformin, TestMedications.lisinopril],
                                           medications: medications + [TestMedications.ondansetron],
                                           doses: dayDoses, scannedAt: [:], now: TestClock.at(8))
        #expect(result.missing.isEmpty)
    }

    @Test func alreadyScannedDosesAreNotMissing() {
        let lisinopril = dose(TestMedications.lisinopril, at: 8)
        let result = check([TestMedications.lisinopril], scannedAt: [lisinopril.id: TestClock.at(8)], at: 9)
        #expect(result.verdicts == [.alreadyScanned(lisinopril, at: TestClock.at(8), next: nil)])
        #expect(result.missing == [dose(TestMedications.metformin, at: 8)])
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

struct PhotoFramingTests {
    private let photo = CGSize(width: 1000, height: 2000)

    @Test func theRegionHoldsEveryBoxAndTakesTheStripsShape() {
        let boxes = [CGRect(x: 0.2, y: 0.4, width: 0.1, height: 0.05), CGRect(x: 0.6, y: 0.45, width: 0.1, height: 0.05)]
        let region = PhotoFraming.region(around: boxes, imageSize: photo, aspect: 2)
        for box in boxes {
            let pixels = CGRect(x: box.minX * 1000, y: box.minY * 2000, width: box.width * 1000, height: box.height * 2000)
            #expect(region.contains(pixels))
        }
        #expect(abs(region.width / region.height - 2) < 0.01)
        #expect(CGRect(origin: .zero, size: photo).contains(region))
    }

    @Test func boxesAreNeverCutOffWhenThePhotoIsTooNarrowForTheShape() {
        // Pills from top to bottom of a tall photo can't fit a wide strip: keep them all.
        let boxes = [CGRect(x: 0.4, y: 0.05, width: 0.1, height: 0.05), CGRect(x: 0.4, y: 0.9, width: 0.1, height: 0.05)]
        let region = PhotoFraming.region(around: boxes, imageSize: photo, aspect: 2)
        #expect(region.minY <= 0.05 * 2000)
        #expect(region.maxY >= 0.95 * 2000)
        #expect(region.width <= 1000)
    }

    @Test func noBoxesShowsTheWholePhoto() {
        #expect(PhotoFraming.region(around: [], imageSize: photo, aspect: 2) == CGRect(origin: .zero, size: photo))
    }
}

