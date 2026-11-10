//
//  SurfaceOutliersTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Testing
@testable import MyPharmacist

typealias RGB = (Double, Double, Double)

enum TestColours {
    static let lightSkin: RGB = (0.80, 0.62, 0.52)
    static let darkSkin: RGB = (0.36, 0.24, 0.18)
    static let whitePill: RGB = (0.95, 0.95, 0.93)
    static let yellowPill: RGB = (0.95, 0.85, 0.30)
    static let pinkPill: RGB = (0.93, 0.70, 0.72)
}

/// A round thing on a made-up surface: a pill of its own colour, or (with no colour) the
/// surface itself made darker or lighter, like a shadow.
struct TestDisc {
    var x: Double, y: Double, radius: Double
    var colour: RGB?
    var light = 1.0
}

/// A made-up photo of a surface such as a palm: one colour, lit unevenly from top to
/// bottom, with a little noise, and round things on it. `stripes` are rows where the
/// surface is darker, like creases.
func surfacePicture(width: Int = 360, height: Int = 640, colour: RGB = TestColours.lightSkin,
                    light: (top: Double, bottom: Double) = (0.75, 1.05),
                    discs: [TestDisc] = [], stripes: [(y: Int, height: Int, light: Double)] = []) -> ColourImage {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        let lit = light.top + (light.bottom - light.top) * Double(y) / Double(height)
        for x in 0..<width {
            var c: RGB = (colour.0 * lit, colour.1 * lit, colour.2 * lit)
            for stripe in stripes where y >= stripe.y && y < stripe.y + stripe.height {
                c = (c.0 * stripe.light, c.1 * stripe.light, c.2 * stripe.light)
            }
            for disc in discs where (Double(x) - disc.x) * (Double(x) - disc.x) + (Double(y) - disc.y) * (Double(y) - disc.y) <= disc.radius * disc.radius {
                if let own = disc.colour {
                    c = (own.0 * lit, own.1 * lit, own.2 * lit)
                } else {
                    c = (c.0 * disc.light, c.1 * disc.light, c.2 * disc.light)
                }
            }
            let noise = Double((x &* 73 &+ y &* 151) % 7) - 3
            let index = (y * width + x) * 4
            bytes[index] = UInt8(max(0, min(255, c.0 * 255 + noise)))
            bytes[index + 1] = UInt8(max(0, min(255, c.1 * 255 + noise)))
            bytes[index + 2] = UInt8(max(0, min(255, c.2 * 255 + noise)))
        }
    }
    return ColourImage(width: width, height: height, bytes: bytes)
}

struct SurfaceOutliersTests {
    private let threePills = [
        TestDisc(x: 100, y: 200, radius: 25, colour: TestColours.whitePill),
        TestDisc(x: 250, y: 300, radius: 30, colour: TestColours.yellowPill),
        TestDisc(x: 180, y: 480, radius: 22, colour: TestColours.pinkPill),
    ]

    /// The middle of each area's box, to the whole pixel.
    private func middles(_ blobs: [Blob]) -> [CGPoint] {
        blobs.map { CGPoint(x: $0.bounds.midX.rounded(.down), y: $0.bounds.midY.rounded(.down)) }
    }

    @Test func pillsStandOutFromAnUnevenlyLitHand() {
        let result = SurfaceOutliers.find(in: surfacePicture(discs: threePills))
        #expect(result.isReliable)
        #expect(middles(result.blobs) == [CGPoint(x: 100, y: 200), CGPoint(x: 250, y: 300), CGPoint(x: 180, y: 480)])
        // Each area is the pill, no more.
        #expect(abs(Double(result.blobs[0].mask.count) - .pi * 625) < 60)
        #expect(result.faint.isEmpty)
    }

    @Test func theSameHoldsOnDarkSkin() {
        let result = SurfaceOutliers.find(in: surfacePicture(colour: TestColours.darkSkin, discs: threePills))
        #expect(result.isReliable)
        #expect(middles(result.blobs).count == 3)
    }

    @Test func shadowsAndCreasesAreTheSurfaceInLessLight() {
        let result = SurfaceOutliers.find(in: surfacePicture(
            discs: [TestDisc(x: 100, y: 200, radius: 25, light: 0.6)], stripes: [(y: 400, height: 3, light: 0.6)]))
        #expect(result.blobs.isEmpty)
        #expect(result.faint.isEmpty)
    }

    @Test func aPillCloseToTheSurfacesColourIsOnlyFaint() {
        let nearlySkin: RGB = (0.80, 0.68, 0.58)
        let result = SurfaceOutliers.find(in: surfacePicture(discs: [TestDisc(x: 180, y: 300, radius: 25, colour: nearlySkin)]))
        #expect(result.blobs.isEmpty)
        #expect(middles(result.faint) == [CGPoint(x: 180, y: 300)])
    }

    @Test func onlyTheSurfaceIsLookedAt() {
        // A hand over the left half, a blue table on the right.
        var bytes = surfacePicture(discs: [TestDisc(x: 90, y: 300, radius: 25, colour: TestColours.whitePill)]).bytes
        var hand = PixelMask(width: 360, height: 640)
        for y in 0..<640 {
            for x in 0..<360 {
                if x < 180 {
                    hand[x, y] = true
                } else {
                    bytes[(y * 360 + x) * 4] = 40
                    bytes[(y * 360 + x) * 4 + 2] = 220
                }
            }
        }
        let result = SurfaceOutliers.find(in: ColourImage(width: 360, height: 640, bytes: bytes), within: hand)
        #expect(result.isReliable)
        #expect(middles(result.blobs) == [CGPoint(x: 90, y: 300)])
    }

    @Test func aPatternedSurfaceSaysNothing() {
        var bytes = surfacePicture().bytes
        for y in 0..<640 {
            for x in 0..<360 where (x / 20 + y / 20) % 2 == 0 {
                bytes[(y * 360 + x) * 4 + 2] = 230
            }
        }
        #expect(!SurfaceOutliers.find(in: ColourImage(width: 360, height: 640, bytes: bytes)).isReliable)
    }

    @Test func colourIsMeasuredAsPeopleSeeIt() {
        let lab = LabImage(ColourImage(width: 3, height: 1, bytes: [255, 255, 255, 255, 0, 0, 0, 255, 255, 0, 0, 255]))
        #expect(abs(lab.lightness[0] - 100) < 0.5)
        #expect(abs(lab.greenRed[0]) < 0.5)
        #expect(abs(lab.lightness[1]) < 0.5)
        // Pure red: L 53, a 80, b 67.
        #expect(abs(lab.lightness[2] - 53.2) < 1)
        #expect(abs(lab.greenRed[2] - 80.1) < 1.5)
        #expect(abs(lab.blueYellow[2] - 67.2) < 1.5)
    }
}
