//
//  PixelMask.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation

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

    /// The mask as a grey picture, white where set: for clipping a drawing to it.
    func grayImage() -> CGImage? {
        let data = Data(pixels.map { $0 != 0 ? 255 : 0 })
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
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

    /// One pass along rows, then one along columns: a square neighbourhood. Written
    /// against raw memory and running totals because it runs over every pixel of a
    /// photo-sized mask several times a scan, in debug builds too.
    private func spread(_ radius: Int, growing: Bool) -> PixelMask {
        let width = width, height = height
        var rows = [UInt8](repeating: 0, count: width * height)
        var result = rows
        // totals[k] is how many of the first k pixels of the line are set.
        var totals = [Int32](repeating: 0, count: max(width, height) + 1)
        pixels.withUnsafeBufferPointer { source in
            rows.withUnsafeMutableBufferPointer { rows in
                result.withUnsafeMutableBufferPointer { result in
                    totals.withUnsafeMutableBufferPointer { totals in
                        for y in 0..<height {
                            let row = y * width
                            for x in 0..<width { totals[x + 1] = totals[x] + Int32(source[row + x]) }
                            for x in 0..<width {
                                let low = x - radius, high = x + radius
                                if growing {
                                    rows[row + x] = totals[min(width, high + 1)] - totals[max(0, low)] > 0 ? 1 : 0
                                } else if low >= 0, high < width {
                                    rows[row + x] = totals[high + 1] - totals[low] == Int32(2 * radius + 1) ? 1 : 0
                                }
                            }
                        }
                        for x in 0..<width {
                            for y in 0..<height { totals[y + 1] = totals[y] + Int32(rows[y * width + x]) }
                            for y in 0..<height {
                                let low = y - radius, high = y + radius
                                if growing {
                                    result[y * width + x] = totals[min(height, high + 1)] - totals[max(0, low)] > 0 ? 1 : 0
                                } else if low >= 0, high < height {
                                    result[y * width + x] = totals[high + 1] - totals[low] == Int32(2 * radius + 1) ? 1 : 0
                                }
                            }
                        }
                    }
                }
            }
        }
        return PixelMask(width: width, height: height, pixels: result)
    }

    /// Sets every clear area that is closed in on all sides, such as the dark letters
    /// printed on a pill. Clear areas that reach the mask's edge stay clear.
    func fillingHoles() -> PixelMask {
        // Flood the clear pixels in from the edge; whatever clear the flood can't reach
        // is a hole. 0 clear, 1 set, 2 clear and reached.
        let width = width, height = height
        var marks = pixels
        var stack: [Int32] = []
        marks.withUnsafeMutableBufferPointer { marks in
            func reach(_ index: Int) {
                if marks[index] == 0 {
                    marks[index] = 2
                    stack.append(Int32(index))
                }
            }
            for x in 0..<width {
                reach(x)
                reach((height - 1) * width + x)
            }
            for y in 0..<height {
                reach(y * width)
                reach(y * width + width - 1)
            }
            while let last = stack.popLast() {
                let index = Int(last)
                let x = index % width
                if x > 0 { reach(index - 1) }
                if x < width - 1 { reach(index + 1) }
                if index >= width { reach(index - width) }
                if index < (height - 1) * width { reach(index + width) }
            }
            for index in 0..<(width * height) {
                marks[index] = marks[index] == 2 ? 0 : 1
            }
        }
        return PixelMask(width: width, height: height, pixels: marks)
    }

    // MARK: Separate areas

    /// Each separate set area (pixels touching along a side or at a corner belong
    /// together), from the top down. Areas smaller than `minimumPixels` are left out.
    func blobs(minimumPixels: Int = 1) -> [Blob] {
        let width = width, height = height
        var seen = [Bool](repeating: false, count: pixels.count)
        var blobs: [Blob] = []
        var stack: [Int32] = []
        var members: [Int32] = []
        pixels.withUnsafeBufferPointer { pixels in
            seen.withUnsafeMutableBufferPointer { seen in
                for start in 0..<(width * height) where pixels[start] != 0 && !seen[start] {
                    members.removeAll(keepingCapacity: true)
                    var minX = width, minY = height, maxX = 0, maxY = 0
                    seen[start] = true
                    stack.append(Int32(start))
                    while let last = stack.popLast() {
                        members.append(last)
                        let index = Int(last)
                        let x = index % width, y = index / width
                        if x < minX { minX = x }
                        if x > maxX { maxX = x }
                        if y < minY { minY = y }
                        if y > maxY { maxY = y }
                        for ny in max(0, y - 1)...min(height - 1, y + 1) {
                            for nx in max(0, x - 1)...min(width - 1, x + 1) {
                                let next = ny * width + nx
                                if pixels[next] != 0, !seen[next] {
                                    seen[next] = true
                                    stack.append(Int32(next))
                                }
                            }
                        }
                    }
                    guard members.count >= minimumPixels else { continue }
                    let patchWidth = maxX - minX + 1
                    var patch = [UInt8](repeating: 0, count: patchWidth * (maxY - minY + 1))
                    for member in members {
                        let index = Int(member)
                        patch[(index / width - minY) * patchWidth + index % width - minX] = 1
                    }
                    blobs.append(Blob(x: minX, y: minY, mask: PixelMask(width: patchWidth, height: maxY - minY + 1, pixels: patch)))
                }
            }
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

    /// The area's box as shares of the picture: 0–1, origin at the top left.
    func normalizedBounds(pictureWidth: Int, pictureHeight: Int) -> CGRect {
        CGRect(x: bounds.minX / Double(pictureWidth), y: bounds.minY / Double(pictureHeight),
               width: bounds.width / Double(pictureWidth), height: bounds.height / Double(pictureHeight))
    }

    /// The same area with `margin` clear pixels added on every side, so that tidying it
    /// has room to work. Its place in the picture moves out to match.
    func padded(by margin: Int) -> Blob {
        var wider = PixelMask(width: mask.width + 2 * margin, height: mask.height + 2 * margin)
        for py in 0..<mask.height {
            for px in 0..<mask.width where mask[px, py] {
                wider[px + margin, py + margin] = true
            }
        }
        return Blob(x: x - margin, y: y - margin, mask: wider)
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
