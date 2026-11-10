//
//  PillLocatorTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Testing
@testable import MyPharmacist

struct PillLocatorTests {
    private let width = 360, height = 640
    /// A 360-pixel-wide picture of an 87.5 mm wide view (about 4 pixels a millimetre),
    /// searched from a photo six times as large.
    private var rules: PillRules { PillRules(pictureWidth: width, widthMillimeters: 87.5, capturedWidth: 2160) }

    private func blobs(_ discs: [(x: Double, y: Double, radius: Double)]) -> [Blob] {
        MyPharmacistTests.discs(width: width, height: height, discs).blobs()
    }

    private func locate(lifted: [Blob] = [], colour: [Blob]? = nil, faint: [Blob] = [], reliable: Bool = true) -> PillLocation {
        let result = colour.map { SurfaceOutliers.Result(blobs: $0, faint: faint, isReliable: reliable) }
            ?? (faint.isEmpty ? nil : SurfaceOutliers.Result(blobs: [], faint: faint, isReliable: reliable))
        return PillLocator.locate(lifted: lifted, colour: result, rules: rules, pictureWidth: width, pictureHeight: height)
    }

    private func pills(_ location: PillLocation) -> [LocatedPill] {
        if case .found(let pills) = location { pills } else { [] }
    }

    @Test func separatePillsComeBackInReadingOrder() {
        let found = pills(locate(lifted: blobs([(250, 400, 14), (250, 200, 14), (100, 205, 16)])))
        #expect(found.map { Int($0.shape.centre.x) } == [100, 250, 250])
        #expect(found.map { Int($0.shape.centre.y) } == [205, 200, 400])
        #expect(found.allSatisfy { $0.sources == .lifted })
    }

    @Test func pillsTheHandSwallowedAreFoundByColour() {
        // Vision returned nothing pill-sized; the colour check sees three.
        let found = pills(locate(colour: blobs([(100, 200, 14), (250, 300, 16), (180, 480, 12)])))
        #expect(found.count == 3)
        #expect(found.allSatisfy { $0.sources == .colour })
    }

    @Test func aPillFoundBothWaysIsOnePill() {
        let found = pills(locate(lifted: blobs([(100, 200, 14)]), colour: blobs([(101, 201, 13), (250, 300, 16)])))
        #expect(found.count == 2)
        #expect(found[0].sources == [.lifted, .colour])
        #expect(found[1].sources == .colour)
    }

    @Test func whereVisionJoinedTwoPillsColourKeepsThemApart() {
        // Vision's one object covers both pills and the skin between them.
        let joined = blobs([(100, 200, 14), (140, 200, 14), (120, 200, 14)])
        let found = pills(locate(lifted: joined, colour: blobs([(100, 200, 14), (140, 200, 14)])))
        #expect(found.count == 2)
        #expect(found.map { Int($0.shape.centre.x) } == [100, 140])
    }

    @Test func touchingPillsAreCutApart() {
        let found = pills(locate(lifted: blobs([(100, 200, 16), (130, 200, 16)])))
        #expect(found.count == 2)
        #expect(found[0].shape.centre.x < 110)
        #expect(found[1].shape.centre.x > 120)
    }

    @Test func pillsJoinedByMostOfTheirWidthHaveToBeSpreadApart() {
        #expect(locate(lifted: blobs([(100, 200, 16), (122, 200, 16), (250, 400, 14)])) == .unclear(.touching))
    }

    @Test func aPillLyingHalfOverAnotherLooksLikeOneOvalPill() {
        // A known limit: by outline alone this is one pill. The vision model is asked
        // whether each cut-out shows one whole pill, which is where this is caught.
        #expect(pills(locate(lifted: blobs([(100, 200, 16), (116, 200, 16)]))).count == 1)
    }

    @Test func aPillAtTheEdgeIsCutOff() {
        #expect(locate(lifted: blobs([(10, 300, 14), (200, 300, 14)])) == .unclear(.cutOff))
    }

    @Test func specksLinesAndLargeThingsAreNotPills() {
        var crease = PixelMask(width: width, height: height)
        for x in 40..<300 {
            for y in 300..<304 { crease[x, y] = true }
        }
        let things = blobs([(100, 100, 2), (200, 450, 70)]) + crease.blobs()
        #expect(things.count == 3)
        #expect(locate(lifted: things) == .noPills)
        #expect(locate() == .noPills)
    }

    @Test func somethingPillShapedThatBarelyStandsOutMakesThePhotoUnclear() {
        #expect(locate(lifted: blobs([(100, 200, 14)]), colour: [], faint: blobs([(250, 300, 14)])) == .unclear(.hardToSee))
        // The faint edge of a pill that was found is nothing new.
        #expect(pills(locate(lifted: blobs([(100, 200, 14)]), colour: [], faint: blobs([(101, 200, 15)]))).count == 1)
        // A faint line is a crease.
        var crease = PixelMask(width: width, height: height)
        for x in 40..<300 { crease[x, 300] = true; crease[x, 301] = true }
        #expect(pills(locate(lifted: blobs([(100, 200, 14)]), colour: [], faint: crease.blobs())).count == 1)
    }

    @Test func pillsTooSmallToReadNeedThePhoneCloser() {
        #expect(locate(lifted: blobs([(100, 200, 5), (200, 300, 5)])) == .unclear(.tooFar))
    }

    @Test func whatColourAloneFindsHasToLookLikeAPill() {
        // Skin has creases, blotches and gaps between fingers that differ in colour too.
        var crease = PixelMask(width: width, height: height)
        for x in 40..<120 {
            for y in 300..<306 { crease[x, y] = true }
        }
        // A ragged blotch: three small areas joined in an L.
        let blotch = blobs([(200, 400, 8), (212, 400, 8), (212, 412, 8), (212, 424, 8), (224, 424, 8)])
        let speck = blobs([(300, 100, 4)])
        let atEdge = blobs([(6, 500, 14)])
        #expect(locate(colour: crease.blobs() + blotch + speck + atEdge) == .noPills)
        // The same things beside a real pill don't spoil it.
        #expect(pills(locate(colour: crease.blobs() + blotch + speck + atEdge + blobs([(250, 250, 14)]))).count == 1)
    }

    @Test func touchingPillsFoundByColourAloneAreCutApartOrFlagged() {
        #expect(pills(locate(colour: blobs([(100, 200, 16), (130, 200, 16)]))).count == 2)
        #expect(locate(colour: blobs([(100, 200, 16), (122, 200, 16)])) == .unclear(.touching))
    }

    @Test func aPillWithItsShadowFoundByColourIsStillOnePill() {
        // The shadow is a small piece beside the pill that isn't a pill by itself.
        let found = pills(locate(colour: blobs([(100, 200, 16), (122, 206, 5)])))
        #expect(found.count == 1)
    }

    @Test func colourOnAPatternedSurfaceIsIgnored() {
        let found = pills(locate(lifted: blobs([(100, 200, 14)]), colour: blobs([(250, 300, 14), (180, 480, 14)]), reliable: false))
        #expect(found.count == 1)
    }

}

struct PillRulesTests {
    private let rules = PillRules(pictureWidth: 360, widthMillimeters: 87.5, capturedWidth: 2160)

    private func verdict(_ mask: PixelMask) throws -> PillRules.Verdict {
        rules.judge(try #require(mask.blobs().first), pictureWidth: 360, pictureHeight: 640)
    }

    @Test func roundAndOvalPillsArePills() throws {
        #expect(try verdict(discs(width: 360, height: 640, [(100, 200, 14)])) == .pill)
        #expect(try verdict(ellipse(width: 360, height: 640, x: 180, y: 300, a: 35, b: 14, degrees: 40)) == .pill)
    }

    @Test func sizesFollowThePhotosScale() {
        // 87.5 mm across 360 pixels, and a full-size photo six times as large.
        #expect(abs(rules.pixelsPerMillimeter - 4.11) < 0.01)
        #expect(rules.capturedPixelsPerPixel == 6)
    }

    @Test func aCoinIsTooLargeToBeAPill() throws {
        #expect(try verdict(discs(width: 360, height: 640, [(180, 300, 55)])) == .notAPill)
    }
}
