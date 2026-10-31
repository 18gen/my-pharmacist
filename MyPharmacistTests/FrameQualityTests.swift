//
//  FrameQualityTests.swift
//  MyPharmacistTests
//

import CoreVideo
import Foundation
import Testing
@testable import MyPharmacist

/// Synthetic pictures for the quality checks.
private enum Pictures {
    static let width = 96, height = 64

    static func make(_ value: (Int, Int) -> Int) -> LumaImage {
        var pixels: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                pixels.append(UInt8(min(255, max(0, value(x, y)))))
            }
        }
        return LumaImage(width: width, height: height, pixels: pixels)
    }

    static func flat(_ value: Int) -> LumaImage { make { _, _ in value } }

    /// Mid-grey with wide bands (for movement) and fine detail (for sharpness).
    static func detailed(shiftedBy shift: Int = 0) -> LumaImage {
        make { x, y in 60 + ((x + shift) / 16 % 2) * 100 + ((x + y) % 2) * 30 }
    }

    /// The same picture, smoothed twice with a 3×3 box filter: out of focus.
    static func blurred(_ image: LumaImage) -> LumaImage {
        var current = image
        for _ in 0..<2 {
            let source = current
            current = make { x, y in
                var sum = 0, count = 0
                for dy in -1...1 {
                    for dx in -1...1 where (0..<width).contains(x + dx) && (0..<height).contains(y + dy) {
                        sum += Int(source[x + dx, y + dy])
                        count += 1
                    }
                }
                return sum / count
            }
        }
        return current
    }
}

struct FrameQualityAnalyzerTests {
    @Test func aWellLitSharpStillPictureHasNoIssues() {
        var analyzer = FrameQualityAnalyzer()
        #expect(analyzer.analyze(Pictures.detailed()).issues.isEmpty)
        #expect(analyzer.analyze(Pictures.detailed()).issues.isEmpty)
    }

    @Test func darkAndBrightPictures() {
        var analyzer = FrameQualityAnalyzer()
        #expect(analyzer.analyze(Pictures.flat(20)).topIssue == .tooDark)
        var other = FrameQualityAnalyzer()
        #expect(other.analyze(Pictures.flat(240)).topIssue == .tooBright)
    }

    @Test func theCamerasOwnMeteringCanReportLowLight() {
        var analyzer = FrameQualityAnalyzer()
        let straining = CameraState(exposureOffset: -2, isoFraction: 0.9)
        #expect(analyzer.analyze(Pictures.detailed(), camera: straining).topIssue == .tooDark)
    }

    @Test func aSmallBlownOutPatchIsGlare() {
        let base = Pictures.detailed()
        // About 6% of the picture clipped to white, as from a reflection on a coated pill.
        let withHighlight = Pictures.make { x, y in
            (40..<56).contains(x) && (24..<46).contains(y) ? 255 : Int(base[x, y])
        }
        var analyzer = FrameQualityAnalyzer()
        let quality = analyzer.analyze(withHighlight)
        #expect(quality.issues.contains(.glare))
        #expect(!quality.issues.contains(.tooBright))
    }

    @Test func aShiftedPictureIsMovement() {
        var analyzer = FrameQualityAnalyzer()
        #expect(analyzer.analyze(Pictures.detailed()).measurements.motion == nil)
        #expect(analyzer.analyze(Pictures.detailed(shiftedBy: 8)).issues.contains(.moving))
    }

    @Test func blurIsJudgedAgainstTheRecentSharpestFrame() {
        var analyzer = FrameQualityAnalyzer()
        let sharp = Pictures.detailed()
        #expect(!analyzer.analyze(sharp).issues.contains(.blurry))
        let blurred = analyzer.analyze(Pictures.blurred(sharp))
        #expect(blurred.issues.contains(.blurry))
        #expect(blurred.measurements.sharpness < blurred.measurements.recentBestSharpness * 0.7)
    }

    @Test func aFeaturelessPictureIsBlurryEvenOnItsOwn() {
        var analyzer = FrameQualityAnalyzer()
        #expect(analyzer.analyze(Pictures.flat(128)).issues == [.blurry])
    }

    @Test func focusingIsReported() {
        var analyzer = FrameQualityAnalyzer()
        #expect(analyzer.analyze(Pictures.detailed(), camera: CameraState(isAdjustingFocus: true)).issues == [.focusing])
    }

    @Test func lightingIsFixedBeforeHoldingStill() {
        var analyzer = FrameQualityAnalyzer()
        _ = analyzer.analyze(Pictures.detailed())
        let shifted = Pictures.detailed(shiftedBy: 8)
        let dimAndMoving = Pictures.make { x, y in Int(shifted[x, y]) / 6 }
        let quality = analyzer.analyze(dimAndMoving)
        #expect(quality.issues.isSuperset(of: [.tooDark, .moving]))
        #expect(quality.topIssue == .tooDark)
    }
}

struct QualityGateTests {
    private let good = FrameQuality(issues: [], measurements: FrameMeasurements(
        brightness: 0.5, clippedFraction: 0, sharpness: 100, recentBestSharpness: 100, motion: 0))
    private func bad(_ issues: Set<QualityIssue>) -> FrameQuality {
        FrameQuality(issues: issues, measurements: good.measurements)
    }

    @Test func readyOnlyAfterEnoughGoodFramesInARow() {
        var gate = QualityGate()
        for _ in 1..<gate.readyAfter {
            #expect(gate.update(good) == .checking)
        }
        #expect(gate.update(good) == .ready)
    }

    @Test func anIssueShowsOnlyAfterSeveralBadFrames() {
        var gate = QualityGate()
        #expect(gate.update(bad([.moving])) == .checking)
        #expect(gate.update(bad([.moving])) == .checking)
        #expect(gate.update(bad([.moving, .glare])) == .needs(.glare))
    }

    @Test func oneBadFrameDoesNotEndReady() {
        var gate = QualityGate()
        for _ in 0..<gate.readyAfter { gate.update(good) }
        #expect(gate.update(bad([.moving])) == .ready)
        #expect(gate.update(good) == .ready)
    }

    @Test func aFixedIssueStaysUntilThePictureIsGoodForAWhile() {
        var gate = QualityGate()
        for _ in 0..<gate.issueAfter { gate.update(bad([.tooDark])) }
        for _ in 1..<gate.readyAfter {
            #expect(gate.update(good) == .needs(.tooDark))
        }
        #expect(gate.update(good) == .ready)
    }
}

struct LumaSamplerTests {
    private func buffer(format: OSType, luma: UInt8) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, 64, 48, format, nil, &buffer)
        let created = try #require(buffer)
        #expect(status == kCVReturnSuccess)
        CVPixelBufferLockBaseAddress(created, [])
        let base = try #require(CVPixelBufferGetBaseAddressOfPlane(created, 0))
        memset(base, Int32(luma), CVPixelBufferGetBytesPerRowOfPlane(created, 0) * CVPixelBufferGetHeightOfPlane(created, 0))
        CVPixelBufferUnlockBaseAddress(created, [])
        return created
    }

    @Test func samplesTheMiddleOfTheBrightnessPlane() throws {
        let image = try #require(LumaSampler.sample(buffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, luma: 200)))
        #expect(image.width == 38)
        #expect(image.height == 28)
        #expect(image.pixels.allSatisfy { $0 == 200 })
    }

    @Test func videoRangeIsStretchedToFullRange() throws {
        let white = try #require(LumaSampler.sample(buffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, luma: 235)))
        #expect(white.pixels.allSatisfy { $0 == 255 })
        let black = try #require(LumaSampler.sample(buffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, luma: 16)))
        #expect(black.pixels.allSatisfy { $0 == 0 })
    }

    @Test func otherFormatsAreSkipped() throws {
        var bgra: CVPixelBuffer?
        CVPixelBufferCreate(nil, 64, 48, kCVPixelFormatType_32BGRA, nil, &bgra)
        #expect(LumaSampler.sample(try #require(bgra)) == nil)
    }
}
