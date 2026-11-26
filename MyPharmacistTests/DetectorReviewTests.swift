//
//  DetectorReviewTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Testing
@testable import MyPharmacist

struct DetectorReviewTests {
    private func seen(_ box: CGRect, _ confidence: Float = 0.9) -> PillDetection {
        PillDetection(box: box, confidence: confidence)
    }

    private let left = CGRect(x: 100, y: 200, width: 40, height: 40)
    private let right = CGRect(x: 300, y: 200, width: 40, height: 40)

    @Test func whenTheDetectorAgreesNothingChanges() {
        let found = [left, right]
        let detections = [seen(left.insetBy(dx: 2, dy: 2)), seen(right.offsetBy(dx: 3, dy: -2))]
        #expect(DetectorReview.review(found: found, detections: detections) == .keep)
        // Nothing seen, or seen too faintly to count: nothing to say.
        #expect(DetectorReview.review(found: found, detections: []) == .keep)
        #expect(DetectorReview.review(found: found, detections: [seen(CGRect(x: 200, y: 400, width: 40, height: 40), 0.1)]) == .keep)
    }

    @Test func pillsLyingOverEachOtherAreToBeSpreadApart() {
        let over = left.offsetBy(dx: 15, dy: 10)
        #expect(DetectorReview.review(found: [left], detections: [seen(left), seen(over)]) == .touching)
    }

    @Test func twoPillsTakenForOneAreToBeSpreadApart() {
        // One area found where the detector sees two pills side by side.
        let pair = CGRect(x: 100, y: 200, width: 80, height: 40)
        let detections = [seen(CGRect(x: 100, y: 200, width: 40, height: 40)), seen(CGRect(x: 140, y: 200, width: 40, height: 40))]
        #expect(DetectorReview.review(found: [pair], detections: detections) == .touching)
    }

    @Test func aPillMissedBesideAnotherIsToBeSpreadApart() {
        // Beside the found pill, 2 pixels away: perhaps touching it.
        let beside = left.offsetBy(dx: 42, dy: 0)
        #expect(DetectorReview.review(found: [left], detections: [seen(left), seen(beside)]) == .touching)
        // Even when the detector isn't sure.
        #expect(DetectorReview.review(found: [left], detections: [seen(left), seen(beside, 0.4)]) == .touching)
    }

    @Test func aPillSeenTwiceIsOnePill() {
        // A smaller, less sure box inside the pill's own box.
        let inside = CGRect(x: 110, y: 205, width: 24, height: 30)
        #expect(DetectorReview.review(found: [left], detections: [seen(left), seen(inside, 0.45)]) == .keep)
    }

    @Test func anUnsureBoxAcrossPillsFoundApartSaysNothing() {
        // Two pills found apart, close together, and a faint box straddling both.
        let upper = CGRect(x: 100, y: 200, width: 40, height: 60), lower = CGRect(x: 100, y: 264, width: 40, height: 40)
        let across = CGRect(x: 100, y: 240, width: 40, height: 40)
        #expect(DetectorReview.review(found: [upper, lower], detections: [seen(upper), seen(lower), seen(across, 0.45)]) == .keep)
        // Sure of it, though, it may be a third pill between them.
        #expect(DetectorReview.review(found: [upper, lower], detections: [seen(upper), seen(lower), seen(across, 0.8)]) == .touching)
    }

    @Test func aPillOnlyTheDetectorSawAloneIsAddedWhenItIsSure() {
        let alone = CGRect(x: 200, y: 500, width: 40, height: 40)
        #expect(DetectorReview.review(found: [left], detections: [seen(left), seen(alone)]) == .add([alone]))
        // Not sure, and nothing beside it: left out, as a blotch on the skin might be.
        #expect(DetectorReview.review(found: [left], detections: [seen(left), seen(alone, 0.4)]) == .keep)
        // With nothing found at all.
        #expect(DetectorReview.review(found: [], detections: [seen(alone)]) == .add([alone]))
    }
}
