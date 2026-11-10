//
//  CapturedPhotoTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Testing
@testable import MyPharmacist

struct CapturedPhotoTests {
    private let red = (1.0, 0.0, 0.0), green = (0.0, 1.0, 0.0), blue = (0.0, 0.0, 1.0)

    /// A landscape picture as the camera delivers it: red in its top-left quarter, green
    /// in its top-right, blue across the bottom half.
    private func delivered(width: Int = 40, height: Int = 20) -> CGImage {
        let w = CGFloat(width), h = CGFloat(height)
        return paintedImage(width: width, height: height, [
            (CGRect(x: 0, y: 0, width: w / 2, height: h / 2), red),
            (CGRect(x: w / 2, y: 0, width: w / 2, height: h / 2), green),
            (CGRect(x: 0, y: h / 2, width: w, height: h / 2), blue),
        ])
    }

    private func isRed(_ p: (red: Int, green: Int, blue: Int)) -> Bool { p.red > 200 && p.green < 50 && p.blue < 50 }
    private func isGreen(_ p: (red: Int, green: Int, blue: Int)) -> Bool { p.green > 200 && p.red < 50 && p.blue < 50 }
    private func isBlue(_ p: (red: Int, green: Int, blue: Int)) -> Bool { p.blue > 200 && p.red < 50 && p.green < 50 }

    @Test func aPhotoFromTheCameraIsTurnedUpright() throws {
        let photo = try #require(CapturedPhoto(source: delivered(), orientation: .right))
        #expect(photo.size == CGSize(width: 20, height: 40))
        #expect(photo.working.width == 20)
        #expect(photo.working.height == 40)
        // Turned a quarter clockwise: the delivered top-left is now top-right, the
        // delivered top-right is bottom-right, and the delivered bottom is the left side.
        #expect(isRed(pixel(of: photo.working, x: 15, y: 5)))
        #expect(isGreen(pixel(of: photo.working, x: 15, y: 35)))
        #expect(isBlue(pixel(of: photo.working, x: 5, y: 5)))
        #expect(isBlue(pixel(of: photo.working, x: 5, y: 35)))
    }

    @Test func aPieceIsCutFromTheFullSizePixelsAndTurnedUpright() throws {
        let photo = try #require(CapturedPhoto(source: delivered(), orientation: .right))
        // The upright photo's top-right corner is the red quarter.
        let piece = try #require(photo.region(CGRect(x: 12, y: 2, width: 6, height: 10)))
        #expect(piece.width == 6)
        #expect(piece.height == 10)
        #expect(isRed(pixel(of: piece, x: 3, y: 5)))
        // Straddling the middle from left to right: blue, then green.
        let across = try #require(photo.region(CGRect(x: 5, y: 25, width: 10, height: 4)))
        #expect(isBlue(pixel(of: across, x: 1, y: 2)))
        #expect(isGreen(pixel(of: across, x: 8, y: 2)))
    }

    @Test func aPieceReachingOutsideThePhotoIsCutShort() throws {
        let photo = try #require(CapturedPhoto(source: delivered(), orientation: .right))
        let piece = try #require(photo.region(CGRect(x: 15, y: -5, width: 10, height: 10)))
        #expect(piece.width == 5)
        #expect(piece.height == 5)
        #expect(photo.region(CGRect(x: 30, y: 0, width: 5, height: 5)) == nil)
    }

    @Test func onlyThePartThePersonSawIsKept() throws {
        // A 4:3 photo seen through a narrower view loses its sides.
        let photo = try #require(CapturedPhoto(source: delivered(width: 400, height: 300), orientation: .right, visibleAspect: 0.5))
        #expect(photo.size == CGSize(width: 200, height: 400))
        // The middle column of the upright photo is where blue meets red and green.
        #expect(isBlue(pixel(of: photo.working, x: 90, y: 100)))
        #expect(isRed(pixel(of: photo.working, x: 110, y: 100)))
        #expect(isGreen(pixel(of: photo.working, x: 110, y: 300)))

        // A wider view than the photo keeps its whole width and loses top and bottom.
        let wide = try #require(CapturedPhoto(source: delivered(width: 400, height: 300), orientation: .right, visibleAspect: 1))
        #expect(wide.size == CGSize(width: 300, height: 300))
    }

    @Test func theCopyForTheScreenIsSmallerThanALargePhoto() throws {
        let photo = try #require(CapturedPhoto(source: delivered(width: 4096, height: 3072), orientation: .right))
        #expect(photo.size == CGSize(width: 3072, height: 4096))
        #expect(photo.working.height == CapturedPhoto.workingSide)
        #expect(photo.working.width == 1536)
        // A piece still comes from the full-size pixels.
        #expect(photo.region(CGRect(x: 0, y: 0, width: 3000, height: 100))?.width == 3000)
    }

    @Test func anUprightPictureIsKeptAsItIs() throws {
        let photo = try #require(CapturedPhoto(image: delivered()))
        #expect(photo.size == CGSize(width: 40, height: 20))
        #expect(isRed(pixel(of: photo.working, x: 5, y: 5)))
        #expect(isGreen(pixel(of: photo.working, x: 35, y: 5)))
        #expect(abs(photo.widthMillimeters - 87.5) < 0.01)
    }
}

struct PhotoSizeTests {
    private let sizes = [PhotoSize(width: 4032, height: 3024), PhotoSize(width: 5712, height: 4284), PhotoSize(width: 8064, height: 6048)]

    @Test func theLargestSizeWithinTheLimitIsChosen() {
        #expect(PhotoSize.best(of: sizes) == PhotoSize(width: 4032, height: 3024))
        #expect(PhotoSize.best(of: sizes, mostPixels: 50_000_000) == PhotoSize(width: 8064, height: 6048))
        #expect(PhotoSize.best(of: [PhotoSize(width: 1920, height: 1080), PhotoSize(width: 4032, height: 2268)]) == PhotoSize(width: 4032, height: 2268))
    }

    @Test func whenEverySizeIsOverTheLimitTheSmallestIsChosen() {
        #expect(PhotoSize.best(of: sizes, mostPixels: 1_000_000) == PhotoSize(width: 4032, height: 3024))
        #expect(PhotoSize.best(of: []) == nil)
    }
}
