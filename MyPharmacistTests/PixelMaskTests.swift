//
//  PixelMaskTests.swift
//  MyPharmacistTests
//

import CoreGraphics
import Testing
@testable import MyPharmacist

/// A mask drawn with characters: `#` is set, anything else clear.
func mask(_ rows: String...) -> PixelMask {
    PixelMask(width: rows[0].count, height: rows.count, pixels: rows.flatMap { $0.map { $0 == "#" ? UInt8(1) : 0 } })
}

/// A mask with filled circles, for shapes like pills.
func discs(width: Int, height: Int, _ discs: [(x: Double, y: Double, radius: Double)]) -> PixelMask {
    var mask = PixelMask(width: width, height: height)
    for y in 0..<height {
        for x in 0..<width {
            for disc in discs where (Double(x) - disc.x) * (Double(x) - disc.x) + (Double(y) - disc.y) * (Double(y) - disc.y) <= disc.radius * disc.radius {
                mask[x, y] = true
            }
        }
    }
    return mask
}

struct PixelMaskTests {
    @Test func openingRemovesSpecksAndThinLines() {
        let noisy = mask(
            "#.........",
            "..####....",
            "..####....",
            "..####....",
            "..####.###",
            ".........."
        )
        #expect(noisy.opened(by: 1) == mask(
            "..........",
            "..####....",
            "..####....",
            "..####....",
            "..####....",
            ".........."
        ))
    }

    @Test func closingFillsANarrowGap() {
        let gapped = mask(
            "........",
            ".###.###",
            ".###.###",
            ".###.###",
            "........"
        )
        let closed = gapped.closed(by: 1)
        #expect(closed[4, 2])
        // Nothing grows outward.
        #expect(!closed[0, 2])
        #expect(!closed[4, 0])
    }

    @Test func anAreaAtTheEdgeShrinksFromTheEdgeTooAndComesBackWhole() {
        let atEdge = mask(
            "####.",
            "####.",
            "####.",
            "####.",
            "....."
        )
        #expect(atEdge.eroded(by: 1) == mask(
            ".....",
            ".##..",
            ".##..",
            ".....",
            "....."
        ))
        #expect(atEdge.opened(by: 1) == atEdge)
    }

    @Test func holesAreFilledButOpeningsToTheEdgeAreNot() {
        let ring = mask(
            ".#####.",
            ".#...#.",
            ".#.#.#.",
            ".#...#.",
            ".#####.",
            "......."
        )
        #expect(ring.fillingHoles() == mask(
            ".#####.",
            ".#####.",
            ".#####.",
            ".#####.",
            ".#####.",
            "......."
        ))
        let cup = mask(
            "#.#",
            "#.#",
            "###"
        )
        #expect(cup.fillingHoles() == cup)
    }

    @Test func separateAreasComeBackOneByOne() {
        let two = mask(
            "##.....",
            "##.....",
            "..#....",
            ".....##",
            ".....##"
        )
        let blobs = two.blobs()
        #expect(blobs.count == 2)
        // Touching at a corner counts as one area.
        #expect(blobs[0].bounds == CGRect(x: 0, y: 0, width: 3, height: 3))
        #expect(blobs[0].mask.count == 5)
        #expect(blobs[1].bounds == CGRect(x: 5, y: 3, width: 2, height: 2))
        #expect(two.blobs(minimumPixels: 5).count == 1)
        #expect(blobs[1].placed(width: 7, height: 5).count == 4)
        #expect(blobs[1].placed(width: 7, height: 5)[6, 4])
    }

    @Test func countingAndCombining() {
        let a = mask("##..", "##.."), b = mask(".##.", ".##.")
        #expect(a.count == 4)
        #expect(a.intersection(b) == mask(".#..", ".#.."))
        #expect(a.inverted.count == 4)
        #expect(!a.contains(x: -1, y: 0))
    }
}
