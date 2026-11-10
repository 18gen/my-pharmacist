//
//  PillCropperTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Testing
@testable import MyPharmacist

struct PillCropperTests {
    private let width = 540, height = 960
    private let skin = (red: 204, green: 158, blue: 133)

    /// A photo of plain skin with pills painted where the masks are set, and each pill
    /// as the finder would return it. The searched picture is the photo itself.
    private func scene(_ pills: [(mask: PixelMask, colour: (UInt8, UInt8, UInt8))]) throws -> (photo: CapturedPhoto, found: [FoundPill]) {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for index in 0..<(width * height) {
            bytes[index * 4] = UInt8(skin.red); bytes[index * 4 + 1] = UInt8(skin.green); bytes[index * 4 + 2] = UInt8(skin.blue)
        }
        for pill in pills {
            for index in 0..<(width * height) where pill.mask.pixels[index] != 0 {
                bytes[index * 4] = pill.colour.0; bytes[index * 4 + 1] = pill.colour.1; bytes[index * 4 + 2] = pill.colour.2
            }
        }
        let image = try #require(ColourImage(width: width, height: height, bytes: bytes).cgImage())
        let photo = try #require(CapturedPhoto(image: image))
        let found = try pills.map { pill -> FoundPill in
            let blob = try #require(pill.mask.blobs().first)
            return FoundPill(box: CGRect(x: blob.bounds.minX / Double(width), y: blob.bounds.minY / Double(height),
                                         width: blob.bounds.width / Double(width), height: blob.bounds.height / Double(height)),
                             crop: testImage(), outline: blob, shape: BlobShape(blob),
                             searchedSize: CGSize(width: width, height: height), sources: .lifted)
        }
        return (photo, found)
    }

    private func isRed(_ p: (red: Int, green: Int, blue: Int)) -> Bool { p.red > 180 && p.green < 60 && p.blue < 60 }
    private func isBlue(_ p: (red: Int, green: Int, blue: Int)) -> Bool { p.blue > 180 && p.red < 60 && p.green < 60 }
    private func isDimmedSkin(_ p: (red: Int, green: Int, blue: Int)) -> Bool {
        abs(p.red - skin.red / 2) < 12 && abs(p.green - skin.green / 2) < 12 && abs(p.blue - skin.blue / 2) < 12
    }

    @Test func aSmallPillIsEnlargedInTheMiddleWithItsSurroundingsDimmed() throws {
        let scene = try scene([(discs(width: width, height: height, [(200, 400, 30)]), (220, 20, 20))])
        let picture = try #require(PillCropper.picture(of: scene.found[0], in: scene.photo))
        // 60 pixels long: the square is 87, enlarged to the smallest size.
        #expect(picture.width == PillCropper.smallestSide)
        #expect(picture.height == PillCropper.smallestSide)
        let middle = picture.width / 2
        #expect(isRed(pixel(of: picture, x: middle, y: middle)))
        // The pill fills 1/1.45 of the side: red a little inside its edge, dimmed skin
        // well outside it.
        let radius = Double(picture.width) / PillCropper.sideOverLength / 2
        #expect(isRed(pixel(of: picture, x: middle + Int(radius * 0.85), y: middle)))
        #expect(isRed(pixel(of: picture, x: middle, y: middle - Int(radius * 0.85))))
        #expect(isDimmedSkin(pixel(of: picture, x: middle + Int(radius * 1.3), y: middle)))
        #expect(isDimmedSkin(pixel(of: picture, x: 4, y: 4)))
    }

    @Test func theNextPillIsDimmedToo() throws {
        let scene = try scene([(discs(width: width, height: height, [(200, 400, 30)]), (220, 20, 20)),
                               (discs(width: width, height: height, [(266, 400, 30)]), (20, 20, 220))])
        let picture = try #require(PillCropper.picture(of: scene.found[0], in: scene.photo))
        let middle = picture.width / 2
        #expect(isRed(pixel(of: picture, x: middle, y: middle)))
        // Where the blue pill shows at the right, it is half as bright.
        let neighbour = pixel(of: picture, x: picture.width - 10, y: middle)
        #expect(neighbour.blue > 80 && neighbour.blue < 140 && neighbour.red < 30)
    }

    @Test func aLongPillIsTurnedToLieFlat() throws {
        let scene = try scene([(ellipse(width: width, height: height, x: 270, y: 480, a: 80, b: 28, degrees: 60), (20, 20, 220))])
        let picture = try #require(PillCropper.picture(of: scene.found[0], in: scene.photo))
        let middle = picture.width / 2
        let reach = Int(Double(picture.width) / PillCropper.sideOverLength / 2 * 0.8)
        #expect(isBlue(pixel(of: picture, x: middle, y: middle)))
        #expect(isBlue(pixel(of: picture, x: middle + reach, y: middle)))
        #expect(isBlue(pixel(of: picture, x: middle - reach, y: middle)))
        #expect(isDimmedSkin(pixel(of: picture, x: middle, y: middle + reach)))
        #expect(isDimmedSkin(pixel(of: picture, x: middle, y: middle - reach)))
    }

    @Test func aRoundPillIsNotTurned() throws {
        // Half red, half blue from left to right: still so in its picture.
        var left = discs(width: width, height: height, [(200, 400, 30)]), right = left
        for y in 0..<height {
            for x in 0..<width {
                if x >= 200 { left[x, y] = false } else { right[x, y] = false }
            }
        }
        var scene = try scene([(left, (220, 20, 20)), (right, (20, 20, 220))])
        let whole = try #require(discs(width: width, height: height, [(200, 400, 30)]).blobs().first)
        scene.found[0] = FoundPill(box: scene.found[0].box, crop: testImage(), outline: whole, shape: BlobShape(whole),
                                   searchedSize: CGSize(width: width, height: height), sources: .lifted)
        let picture = try #require(PillCropper.picture(of: scene.found[0], in: scene.photo))
        let middle = picture.width / 2
        #expect(isRed(pixel(of: picture, x: middle - 60, y: middle)))
        #expect(isBlue(pixel(of: picture, x: middle + 60, y: middle)))
    }

    @Test func aPillNearThePhotosEdgeStaysInTheMiddle() throws {
        let scene = try scene([(discs(width: width, height: height, [(40, 400, 30)]), (220, 20, 20))])
        let picture = try #require(PillCropper.picture(of: scene.found[0], in: scene.photo))
        let middle = picture.width / 2
        #expect(isRed(pixel(of: picture, x: middle, y: middle)))
        // Beyond the photo's left edge: plain grey.
        let beyond = pixel(of: picture, x: 3, y: middle)
        #expect(abs(beyond.red - 128) < 6 && abs(beyond.green - 128) < 6 && abs(beyond.blue - 128) < 6)
    }

    @Test func aPillFromALargePhotoIsCutAtFullSize() throws {
        // The photo is four times the searched picture each way.
        let large = paintedImage(width: 2160, height: 3840, background: (0.8, 0.62, 0.52),
                                 [(CGRect(x: 700, y: 1500, width: 400, height: 400), (0.9, 0.1, 0.1))])
        let photo = try #require(CapturedPhoto(image: large))
        var outline = PixelMask(width: width, height: height)
        for y in 375..<475 {
            for x in 175..<275 { outline[x, y] = true }
        }
        let blob = try #require(outline.blobs().first)
        let pill = FoundPill(box: .zero, crop: testImage(), outline: blob, shape: BlobShape(blob),
                             searchedSize: CGSize(width: width, height: height), sources: .lifted)
        let picture = try #require(PillCropper.picture(of: pill, in: photo))
        #expect(picture.width == PillCropper.largestSide)
        #expect(isRed(pixel(of: picture, x: 256, y: 256)))
    }

    @Test func theOverviewShowsEveryPillWithRoomAround() throws {
        let scene = try scene([(discs(width: width, height: height, [(150, 400, 30)]), (220, 20, 20)),
                               (discs(width: width, height: height, [(380, 520, 30)]), (20, 20, 220))])
        let overview = try #require(PillCropper.overview(of: scene.found, in: scene.photo))
        #expect(max(overview.width, overview.height) <= PillCropper.overviewSide)
        // The pills span 290 by 180 pixels; with room around, the picture is larger.
        #expect(overview.width > 400)
        #expect(overview.height > 300)
        #expect(PillCropper.overview(of: [], in: scene.photo) == nil)
    }
}
