//
//  BlobSplitterTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Testing
@testable import MyPharmacist

struct BlobSplitterTests {
    private func split(_ mask: PixelMask, rise: Double = 4) throws -> BlobSplitter.Split {
        BlobSplitter.split(try #require(mask.blobs().first), minimumRise: rise)
    }

    @Test func twoTouchingRoundPillsAreCutWhereTheyMeet() throws {
        let split = try split(discs(width: 140, height: 80, [(40, 40, 20), (78, 40, 20)]))
        #expect(split.parts.count == 2)
        // Each piece is about one pill, on its own side.
        for part in split.parts {
            #expect(abs(Double(part.mask.count) - 1250) < 80)
            #expect(BlobShape(part).solidity > 0.95)
        }
        #expect(split.parts[0].bounds.maxX <= 62)
        #expect(split.parts[1].bounds.minX >= 56)
        // The cut is much shorter than a pill is wide.
        #expect(split.longestCut < 20)
    }

    @Test func aSmallPillIsCutFromALargeOne() throws {
        let split = try split(discs(width: 140, height: 80, [(40, 40, 22), (74, 40, 14)]))
        #expect(split.parts.count == 2)
        #expect(split.parts[0].mask.count > split.parts[1].mask.count)
    }

    @Test func threePillsInARowComeApartIntoThree() throws {
        let split = try split(discs(width: 200, height: 80, [(40, 40, 20), (78, 40, 20), (116, 40, 20)]))
        #expect(split.parts.count == 3)
    }

    @Test func onePillIsLeftWhole() throws {
        let round = try split(discs(width: 100, height: 100, [(50, 50, 20)]))
        #expect(round.parts.count == 1)
        #expect(round.longestCut == 0)
        let oval = try split(ellipse(width: 140, height: 140, x: 70, y: 70, a: 40, b: 15, degrees: 30))
        #expect(oval.parts.count == 1)
    }

    @Test func aBumpOnThePillsEdgeIsNotASecondPill() throws {
        let bumpy = try split(discs(width: 100, height: 100, [(50, 50, 20), (70, 50, 3)]))
        #expect(bumpy.parts.count == 1)
    }

    @Test func pillsLyingHalfOverEachOtherAreNotCut() throws {
        // No narrow place between them: this has to be spread apart by hand.
        let stacked = try split(discs(width: 120, height: 80, [(40, 40, 20), (60, 40, 20)]))
        #expect(stacked.parts.count == 1)
    }

    @Test func thePiecesKeepTheirPlaceInThePicture() throws {
        let pair = discs(width: 140, height: 80, [(40, 40, 20), (78, 40, 20)])
        let blob = try #require(pair.blobs().first)
        let moved = Blob(x: blob.x + 100, y: blob.y + 50, mask: blob.mask)
        let split = BlobSplitter.split(moved, minimumRise: 4)
        #expect(split.parts.map(\.x).min() == moved.x)
        #expect(split.parts.reduce(0) { $0 + $1.mask.count } == blob.mask.count)
    }

    @Test func distanceFromTheEdgeIsGreatestInTheMiddle() {
        let depth = BlobSplitter.distances(discs(width: 50, height: 50, [(25, 25, 20)]))
        #expect(abs(depth[25 * 50 + 25] - 20) < 1.5)
        #expect(depth[0] == 0)
        #expect(depth[25 * 50 + 6] <= 2)
    }
}
