//
//  SurfaceOutliers.swift
//  MyPharmacist
//

import CoreGraphics

/// Finds what doesn't belong to the surface the pills lie on, by colour. It learns what
/// the surface looks like from the photo itself, place by place (this hand, in this
/// light, or this table), and marks whatever differs from it. No fixed idea of skin
/// colour is built in, so it treats every skin tone the same way.
///
/// This is the second way of finding pills, beside Vision's subject lifting: it still
/// sees a pill when Vision takes the hand and everything on it for one object. It can't
/// see a pill the colour of the surface (beige on skin, white on white paper).
nonisolated enum SurfaceOutliers {
    /// Starting points, not tuned values.
    struct Settings: Sendable {
        /// The surface's colour is learned in squares this many pixels wide. Wider than
        /// a few pills, so the pills in a square don't pass for its surface.
        var blockSize = 160
        /// How far from the surface's colour counts as different, in the surface's own
        /// spread (about 3.5 standard deviations).
        var different = 3.5
        /// An area must have this share of clearly different pixels to count; fainter
        /// ones are a blotch or a soft shadow, and are reported apart.
        var clearlyDifferent = 6.0
        var clearShare = 0.3
        /// The least spread assumed, so a very even surface doesn't make noise stand
        /// out: in colour, and in lightness.
        var leastColourSpread: Float = 1.5
        var leastLightnessSpread: Float = 3
        /// Specks and lines thinner than about twice this are dropped; gaps narrower
        /// than about twice `close` are filled.
        var open = 1
        var close = 2
        var minimumPixels = 30
        /// More of the surface than this standing out, or more separate areas, means
        /// the surface is patterned and colour says nothing.
        var mostShare = 0.3
        var mostAreas = 80
    }

    struct Result: Sendable {
        /// Areas that clearly differ from the surface.
        let blobs: [Blob]
        /// Areas that differ only faintly: perhaps a pill close to the surface's colour.
        let faint: [Blob]
        /// False when the surface is too patterned for colour to mean anything.
        let isReliable: Bool
        /// For tuning: how much the surface itself varies (lightness, green–red,
        /// blue–yellow), the share of it that stood out, and in how many areas.
        var spread: [Float] = []
        var shareStandingOut = 0.0
        var areas = 0
    }

    /// - Parameter region: Where the surface is (a hand, say); nil for the whole picture.
    static func find(in image: ColourImage, within region: PixelMask? = nil, settings: Settings = Settings()) -> Result {
        let lab = LabImage(image)
        let width = image.width, height = image.height
        let inside: [Bool] = region.map { $0.pixels.map { $0 != 0 } } ?? [Bool](repeating: true, count: width * height)
        let insideCount = inside.reduce(0) { $0 + ($1 ? 1 : 0) }
        guard insideCount > 0 else { return Result(blobs: [], faint: [], isReliable: false) }

        // What the surface looks like around each pixel (the middle value of each square,
        // blended between squares), and how far each pixel is from that.
        let surface = Surface(lab, inside: inside, blockSize: settings.blockSize)
        var lightnessOff = [Float](repeating: 0, count: width * height)
        var greenRedOff = lightnessOff, blueYellowOff = lightnessOff
        let columnBlend = surface.blend(along: width, count: surface.columns)
        let rowBlend = surface.blend(along: height, count: surface.rows)
        let columns = surface.columns
        // Raw memory throughout: these loops touch every pixel, in debug builds too.
        lab.lightness.withUnsafeBufferPointer { lightness in
        lab.greenRed.withUnsafeBufferPointer { greenRed in
        lab.blueYellow.withUnsafeBufferPointer { blueYellow in
        surface.lightness.withUnsafeBufferPointer { surfaceLightness in
        surface.greenRed.withUnsafeBufferPointer { surfaceGreenRed in
        surface.blueYellow.withUnsafeBufferPointer { surfaceBlueYellow in
        inside.withUnsafeBufferPointer { inside in
        lightnessOff.withUnsafeMutableBufferPointer { lightnessOff in
        greenRedOff.withUnsafeMutableBufferPointer { greenRedOff in
        blueYellowOff.withUnsafeMutableBufferPointer { blueYellowOff in
            for y in 0..<height {
                let row = rowBlend[y]
                let top = row.first * columns, bottom = row.second * columns
                for x in 0..<width where inside[y * width + x] {
                    let index = y * width + x
                    let column = columnBlend[x]
                    let w00 = (1 - column.share) * (1 - row.share), w01 = column.share * (1 - row.share)
                    let w10 = (1 - column.share) * row.share, w11 = column.share * row.share
                    let i00 = top + column.first, i01 = top + column.second
                    let i10 = bottom + column.first, i11 = bottom + column.second
                    let expectedLightness = surfaceLightness[i00] * w00 + surfaceLightness[i01] * w01 + surfaceLightness[i10] * w10 + surfaceLightness[i11] * w11
                    let expectedGreenRed = surfaceGreenRed[i00] * w00 + surfaceGreenRed[i01] * w01 + surfaceGreenRed[i10] * w10 + surfaceGreenRed[i11] * w11
                    let expectedBlueYellow = surfaceBlueYellow[i00] * w00 + surfaceBlueYellow[i01] * w01 + surfaceBlueYellow[i10] * w10 + surfaceBlueYellow[i11] * w11
                    lightnessOff[index] = lightness[index] - expectedLightness
                    // The same surface in less light keeps its colour but paler, in step
                    // with its lightness. Comparing with the surface's colour at this
                    // pixel's own lightness keeps shadows and creases from looking like
                    // another colour.
                    let light = min(1.5, max(0.3, (lightness[index] + 16) / (expectedLightness + 16)))
                    greenRedOff[index] = greenRed[index] - expectedGreenRed * light
                    blueYellowOff[index] = blueYellow[index] - expectedBlueYellow * light
                }
            }
        }}}}}}}}}}
        // How much the surface itself varies, ignoring the few pixels that aren't surface.
        let lightnessSpread = max(settings.leastLightnessSpread, spread(lightnessOff, inside: inside))
        let greenRedSpread = max(settings.leastColourSpread, spread(greenRedOff, inside: inside))
        let blueYellowSpread = max(settings.leastColourSpread, spread(blueYellowOff, inside: inside))

        var differs = [UInt8](repeating: 0, count: width * height)
        var clearly = [Bool](repeating: false, count: width * height)
        let differentLimit = Float(settings.different), clearLimit = Float(settings.clearlyDifferent)
        inside.withUnsafeBufferPointer { inside in
        lightnessOff.withUnsafeBufferPointer { lightnessOff in
        greenRedOff.withUnsafeBufferPointer { greenRedOff in
        blueYellowOff.withUnsafeBufferPointer { blueYellowOff in
        differs.withUnsafeMutableBufferPointer { differs in
        clearly.withUnsafeMutableBufferPointer { clearly in
            for index in 0..<(width * height) where inside[index] {
                let a = greenRedOff[index] / greenRedSpread, b = blueYellowOff[index] / blueYellowSpread
                let colour = (a * a + b * b).squareRoot()
                // Only lighter counts, not darker: darker with the surface's own colour
                // is a shadow or a crease.
                let lighter = lightnessOff[index] / lightnessSpread
                let score = max(colour, lighter)
                // Darker than the surface and only somewhat off in colour is a shadow,
                // such as the one a pill casts beside itself. A dark pill is clearly off.
                if lighter < -1, colour <= clearLimit { continue }
                if score > differentLimit {
                    differs[index] = 1
                    clearly[index] = score > clearLimit
                }
            }
        }}}}}}
        let different = PixelMask(width: width, height: height, pixels: differs)

        // Tidied one area at a time, each in a small picture of its own: tidying the
        // whole picture costs far more and would join neighbours.
        let margin = settings.open + settings.close + 1
        let all = different.blobs(minimumPixels: settings.minimumPixels).flatMap { rough -> [Blob] in
            let padded = rough.padded(by: margin)
            return padded.mask.opened(by: settings.open).closed(by: settings.close).fillingHoles()
                .blobs(minimumPixels: settings.minimumPixels)
                .map { Blob(x: padded.x + $0.x, y: padded.y + $0.y, mask: $0.mask) }
        }
        var blobs: [Blob] = [], faint: [Blob] = []
        var standingOut = 0
        for blob in all {
            var clear = 0, total = 0
            for y in 0..<blob.mask.height {
                for x in 0..<blob.mask.width where blob.mask[x, y] {
                    total += 1
                    if clearly[(blob.y + y) * width + blob.x + x] { clear += 1 }
                }
            }
            standingOut += total
            if Double(clear) >= settings.clearShare * Double(total) {
                blobs.append(blob)
            } else {
                faint.append(blob)
            }
        }
        let isReliable = Double(standingOut) <= settings.mostShare * Double(insideCount) && all.count <= settings.mostAreas
        return Result(blobs: blobs, faint: faint, isReliable: isReliable,
                      spread: [lightnessSpread, greenRedSpread, blueYellowSpread],
                      shareStandingOut: Double(standingOut) / Double(insideCount), areas: all.count)
    }

    /// A spread that a few far-off values don't change: 1.4826 × the middle absolute
    /// value, which equals the standard deviation for bell-shaped noise.
    private static func spread(_ values: [Float], inside: [Bool]) -> Float {
        // Counted in steps of a tenth, up to 100.
        var counts = [Int](repeating: 0, count: 1001)
        var total = 0
        values.withUnsafeBufferPointer { values in
            inside.withUnsafeBufferPointer { inside in
                counts.withUnsafeMutableBufferPointer { counts in
                    for index in 0..<values.count where inside[index] {
                        counts[min(1000, Int(abs(values[index]) * 10))] += 1
                        total += 1
                    }
                }
            }
        }
        var seen = 0
        for (step, count) in counts.enumerated() {
            seen += count
            if seen * 2 >= total { return 1.4826 * Float(step) / 10 }
        }
        return 0
    }

    /// The surface's colour, square by square, blended smoothly between squares.
    private struct Surface {
        let columns: Int, rows: Int, blockSize: Int
        var lightness: [Float], greenRed: [Float], blueYellow: [Float]

        init(_ lab: LabImage, inside: [Bool], blockSize: Int) {
            self.blockSize = max(8, blockSize)
            columns = max(1, (lab.width + self.blockSize - 1) / self.blockSize)
            rows = max(1, (lab.height + self.blockSize - 1) / self.blockSize)
            lightness = [Float](repeating: 0, count: columns * rows)
            greenRed = lightness
            blueYellow = lightness
            var known = [Bool](repeating: false, count: columns * rows)
            for row in 0..<rows {
                for column in 0..<columns {
                    var l: [Float] = [], a: [Float] = [], b: [Float] = []
                    let x0 = column * self.blockSize, y0 = row * self.blockSize
                    let x1 = min(lab.width, x0 + self.blockSize), y1 = min(lab.height, y0 + self.blockSize)
                    // Every other pixel is plenty for a middle value.
                    for y in stride(from: y0, to: y1, by: 2) {
                        for x in stride(from: x0, to: x1, by: 2) where inside[y * lab.width + x] {
                            l.append(lab.lightness[y * lab.width + x])
                            a.append(lab.greenRed[y * lab.width + x])
                            b.append(lab.blueYellow[y * lab.width + x])
                        }
                    }
                    // Too little surface in this square to learn from.
                    guard l.count * 20 >= (x1 - x0) * (y1 - y0) / 4 else { continue }
                    known[row * columns + column] = true
                    lightness[row * columns + column] = Self.middle(&l)
                    greenRed[row * columns + column] = Self.middle(&a)
                    blueYellow[row * columns + column] = Self.middle(&b)
                }
            }
            fillUnknown(known)
        }

        private static func middle(_ values: inout [Float]) -> Float {
            values.sort()
            return values[values.count / 2]
        }

        /// Squares with too little surface take the average of their known neighbours,
        /// spreading outward until every square has a value.
        private mutating func fillUnknown(_ known: [Bool]) {
            var known = known
            guard known.contains(true) else { return }
            while known.contains(false) {
                var next = known
                for row in 0..<rows {
                    for column in 0..<columns where !known[row * columns + column] {
                        var l: Float = 0, a: Float = 0, b: Float = 0, count: Float = 0
                        for r in max(0, row - 1)...min(rows - 1, row + 1) {
                            for c in max(0, column - 1)...min(columns - 1, column + 1) where known[r * columns + c] {
                                l += lightness[r * columns + c]
                                a += greenRed[r * columns + c]
                                b += blueYellow[r * columns + c]
                                count += 1
                            }
                        }
                        guard count > 0 else { continue }
                        lightness[row * columns + column] = l / count
                        greenRed[row * columns + column] = a / count
                        blueYellow[row * columns + column] = b / count
                        next[row * columns + column] = true
                    }
                }
                known = next
            }
        }

        /// For each pixel along one side of the picture: the two squares it lies between
        /// and how far it is toward the second. Each square's value sits at its middle.
        func blend(along length: Int, count: Int) -> [(first: Int, second: Int, share: Float)] {
            (0..<length).map { position in
                let place = min(Float(count - 1), max(0, (Float(position) + 0.5) / Float(blockSize) - 0.5))
                let first = Int(place)
                return (first, min(count - 1, first + 1), place - Float(first))
            }
        }
    }
}
