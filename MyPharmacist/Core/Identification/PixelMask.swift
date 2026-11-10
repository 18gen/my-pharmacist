//
//  PixelMask.swift
//  MyPharmacist
//

import CoreGraphics

/// A picture of yes and no: which pixels belong to something (a pill, a hand, whatever
/// differs from the background). Everything that measures or tidies a shape works on
/// this, so it can be tested without a camera or Vision.
nonisolated struct PixelMask: Sendable, Equatable {
    let width: Int
    let height: Int
    /// Row by row from the top left: 1 where set, 0 where clear.
    private(set) var pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "Expected \(width * height) pixels, got \(pixels.count)")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// All clear.
    init(width: Int, height: Int) {
        self.init(width: width, height: height, pixels: [UInt8](repeating: 0, count: width * height))
    }

    subscript(x: Int, y: Int) -> Bool {
        get { pixels[y * width + x] != 0 }
        set { pixels[y * width + x] = newValue ? 1 : 0 }
    }

    /// Whether a pixel is set; anything outside the mask is clear.
    func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height && pixels[y * width + x] != 0
    }

    /// How many pixels are set.
    var count: Int {
        pixels.reduce(0) { $0 + Int($1) }
    }

    var inverted: PixelMask {
        PixelMask(width: width, height: height, pixels: pixels.map { 1 - $0 })
    }

    /// Set where both are set. The masks must be the same size.
    func intersection(_ other: PixelMask) -> PixelMask {
        precondition(width == other.width && height == other.height)
        return PixelMask(width: width, height: height, pixels: zip(pixels, other.pixels).map { $0 & $1 })
    }

    // MARK: Tidying

    /// Grows every set area by `radius` pixels in each direction.
    func dilated(by radius: Int) -> PixelMask {
        radius > 0 ? spread(radius, growing: true) : self
    }

    /// Shrinks every set area by `radius` pixels in each direction, from the mask's own
    /// edge too: what is beyond it counts as clear, as it does when growing.
    func eroded(by radius: Int) -> PixelMask {
        radius > 0 ? spread(radius, growing: false) : self
    }

    /// Removes specks and thin lines narrower than about twice `radius`, leaving larger
    /// areas the size they were.
    func opened(by radius: Int) -> PixelMask {
        eroded(by: radius).dilated(by: radius)
    }

    /// Closes gaps and dents narrower than about twice `radius`.
    func closed(by radius: Int) -> PixelMask {
        dilated(by: radius).eroded(by: radius)
    }

    /// One pass along rows, then one along columns: a square neighbourhood.
    private func spread(_ radius: Int, growing: Bool) -> PixelMask {
        let hit: UInt8 = growing ? 1 : 0
        var rows = pixels
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                var value = 1 - hit
                if !growing, x < radius || x + radius >= width {
                    value = hit
                } else {
                    for k in max(0, x - radius)...min(width - 1, x + radius) where pixels[row + k] == hit {
                        value = hit
                        break
                    }
                }
                rows[row + x] = value
            }
        }
        var result = rows
        for x in 0..<width {
            for y in 0..<height {
                var value = 1 - hit
                if !growing, y < radius || y + radius >= height {
                    value = hit
                } else {
                    for k in max(0, y - radius)...min(height - 1, y + radius) where rows[k * width + x] == hit {
                        value = hit
                        break
                    }
                }
                result[y * width + x] = value
            }
        }
        return PixelMask(width: width, height: height, pixels: result)
    }

    /// Sets every clear area that is closed in on all sides, such as the dark letters
    /// printed on a pill. Clear areas that reach the mask's edge stay clear.
    func fillingHoles() -> PixelMask {
        // Flood the clear pixels in from the edge; whatever clear the flood can't reach
        // is a hole.
        var outside = [Bool](repeating: false, count: pixels.count)
        var stack: [Int] = []
        func visit(_ x: Int, _ y: Int) {
            let index = y * width + x
            guard pixels[index] == 0, !outside[index] else { return }
            outside[index] = true
            stack.append(index)
        }
        for x in 0..<width {
            visit(x, 0)
            visit(x, height - 1)
        }
        for y in 0..<height {
            visit(0, y)
            visit(width - 1, y)
        }
        while let index = stack.popLast() {
            let x = index % width, y = index / width
            if x > 0 { visit(x - 1, y) }
            if x < width - 1 { visit(x + 1, y) }
            if y > 0 { visit(x, y - 1) }
            if y < height - 1 { visit(x, y + 1) }
        }
        var filled = pixels
        for index in filled.indices where filled[index] == 0 && !outside[index] {
            filled[index] = 1
        }
        return PixelMask(width: width, height: height, pixels: filled)
    }

    // MARK: Separate areas

    /// Each separate set area (pixels touching along a side or at a corner belong
    /// together), from the top down. Areas smaller than `minimumPixels` are left out.
    func blobs(minimumPixels: Int = 1) -> [Blob] {
        var seen = [Bool](repeating: false, count: pixels.count)
        var blobs: [Blob] = []
        var stack: [Int] = []
        for start in pixels.indices where pixels[start] != 0 && !seen[start] {
            var members: [Int] = []
            var minX = width, minY = height, maxX = 0, maxY = 0
            seen[start] = true
            stack.append(start)
            while let index = stack.popLast() {
                members.append(index)
                let x = index % width, y = index / width
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) {
                        let next = ny * width + nx
                        if pixels[next] != 0, !seen[next] {
                            seen[next] = true
                            stack.append(next)
                        }
                    }
                }
            }
            guard members.count >= minimumPixels else { continue }
            var patch = PixelMask(width: maxX - minX + 1, height: maxY - minY + 1)
            for index in members {
                patch[index % width - minX, index / width - minY] = true
            }
            blobs.append(Blob(x: minX, y: minY, mask: patch))
        }
        return blobs
    }
}

/// One separate area of a mask: its own small mask and where that sits in the picture.
nonisolated struct Blob: Sendable, Equatable {
    /// The top-left corner of `mask` in the picture, in pixels.
    let x: Int
    let y: Int
    /// Just large enough to hold the area.
    let mask: PixelMask

    /// The area's box in the picture, in pixels.
    var bounds: CGRect {
        CGRect(x: x, y: y, width: mask.width, height: mask.height)
    }

    /// The area drawn back into a clear mask of the picture's size.
    func placed(width: Int, height: Int) -> PixelMask {
        var whole = PixelMask(width: width, height: height)
        for py in 0..<mask.height {
            for px in 0..<mask.width where mask[px, py] {
                let wx = x + px, wy = y + py
                if wx >= 0, wy >= 0, wx < width, wy < height {
                    whole[wx, wy] = true
                }
            }
        }
        return whole
    }
}
