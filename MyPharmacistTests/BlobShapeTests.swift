//
//  BlobShapeTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MyPharmacist

/// A mask with one filled ellipse: half-lengths `a` and `b`, its long side turned by
/// `degrees` from pointing right toward down.
func ellipse(width: Int, height: Int, x: Double, y: Double, a: Double, b: Double, degrees: Double = 0) -> PixelMask {
    var mask = PixelMask(width: width, height: height)
    let angle = degrees * .pi / 180
    for py in 0..<height {
        for px in 0..<width {
            let dx = Double(px) - x, dy = Double(py) - y
            let along = dx * cos(angle) + dy * sin(angle), across = -dx * sin(angle) + dy * cos(angle)
            if (along / a) * (along / a) + (across / b) * (across / b) <= 1 {
                mask[px, py] = true
            }
        }
    }
    return mask
}

struct BlobShapeTests {
    private func shape(_ mask: PixelMask) throws -> BlobShape {
        BlobShape(try #require(mask.blobs().first))
    }

    @Test func aRoundPillFillsItsOutline() throws {
        let shape = try shape(discs(width: 100, height: 100, [(50, 40, 20)]))
        #expect(abs(shape.area - .pi * 400) < 30)
        #expect(abs(shape.centre.x - 50.5) < 0.5)
        #expect(abs(shape.centre.y - 40.5) < 0.5)
        #expect(abs(shape.length - 40) < 1.5)
        #expect(abs(shape.width - 40) < 1.5)
        #expect(shape.solidity > 0.96)
        #expect(shape.deepestDent < 0.15 * shape.equivalentRadius)
    }

    @Test func aSmallRoundPillStillFillsItsOutline() throws {
        // About the smallest a pill gets in the picture that is searched.
        let shape = try shape(discs(width: 40, height: 40, [(20, 20, 9)]))
        #expect(shape.solidity > 0.94)
        #expect(shape.deepestDent < 0.15 * shape.equivalentRadius)
    }

    @Test func anOvalPillKnowsWhichWayItLies() throws {
        let shape = try shape(ellipse(width: 140, height: 140, x: 70, y: 70, a: 40, b: 15, degrees: 30))
        #expect(abs(shape.length - 80) < 2)
        #expect(abs(shape.width - 30) < 2)
        #expect(abs(shape.angle - 30 * .pi / 180) < 0.03)
        #expect(shape.solidity > 0.96)

        let upright = try self.shape(ellipse(width: 140, height: 140, x: 70, y: 70, a: 40, b: 15, degrees: 90))
        #expect(abs(abs(upright.angle) - .pi / 2) < 0.03)
    }

    @Test func twoTouchingPillsLeaveGapsInTheirOutline() throws {
        // Overlapping a little, as touching pills do in a mask.
        let shape = try shape(discs(width: 140, height: 80, [(40, 40, 20), (78, 40, 20)]))
        #expect(shape.solidity < 0.93)
        #expect(shape.deepestDent > 0.15 * shape.equivalentRadius)
        #expect(abs(shape.angle) < 0.03)
    }

    @Test func aSmallPillTouchingALargeOneShowsToo() throws {
        let shape = try shape(discs(width: 140, height: 80, [(40, 40, 22), (74, 40, 14)]))
        #expect(shape.solidity < 0.93 || shape.deepestDent > 0.15 * shape.equivalentRadius)
    }

    @Test func theOutlineOfASquareIsItsCorners() {
        let hull = BlobShape.convexHull([CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2), CGPoint(x: 0, y: 2), CGPoint(x: 1, y: 0)])
        #expect(hull.count == 4)
        #expect(BlobShape.area(of: hull) == 4)
        #expect(BlobShape.distance(from: CGPoint(x: 1, y: 1), toSegment: CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 0)) == 1)
    }
}
