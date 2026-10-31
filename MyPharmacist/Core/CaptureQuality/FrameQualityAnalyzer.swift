//
//  FrameQualityAnalyzer.swift
//  MyPharmacist
//

/// Checks each camera frame for lighting, glare, movement and sharpness before any pill
/// recognition runs. Cheap pixel maths on a small grayscale image, meant to run several
/// times a second. It remembers the previous frame (for movement) and recent sharpness
/// (blur is judged relative to what this scene looks like when sharp).
///
/// Until pills are located, the checks look at the middle of the frame, where the palm
/// usually is. Once there is a pill detector they should look at the pill boxes instead.
nonisolated struct FrameQualityAnalyzer {
    /// Starting points from the research report, not tuned values: adjust them on real
    /// palm photos (the debug readout in the camera view shows the measurements).
    struct Thresholds {
        var darkBelow = 0.18
        var brightAbove = 0.82
        /// Low light from the camera's own metering: maxed-out ISO and still under target.
        var lowLightISOFraction: Float = 0.8
        var lowLightExposureOffset: Float = -1
        var overexposedExposureOffset: Float = 1
        /// Pixels at or above this are treated as blown out.
        var clippedLevel: UInt8 = 250
        var glareAbove = 0.02
        /// So much of the picture is blown out that it is overexposure, not glare.
        var clippedTooBrightAbove = 0.25
        var movingAbove = 0.03
        /// Below this there is too little detail for an imprint to be readable at all.
        var sharpnessFloor = 12.0
        var sharpnessShareOfRecentBest = 0.7
        /// How many recent frames count as "recent" for the best sharpness (~2 s).
        var recentFrames = 20
    }

    var thresholds = Thresholds()

    /// Size of the blocks the image is averaged into for the movement check, so sensor
    /// noise doesn't look like movement.
    private static let motionBlockSize = 8

    private var previousBlocks: [Double] = []
    private var recentSharpness: [Double] = []

    mutating func analyze(_ image: LumaImage, camera: CameraState = CameraState()) -> FrameQuality {
        let brightness = Self.meanBrightness(of: image)
        let clipped = Self.fraction(of: image, atLeast: thresholds.clippedLevel)
        let sharpness = Self.laplacianVariance(of: image)

        let blocks = Self.blockMeans(of: image, blockSize: Self.motionBlockSize)
        var motion: Double?
        if blocks.count == previousBlocks.count, !blocks.isEmpty {
            motion = zip(blocks, previousBlocks).map { abs($0 - $1) }.reduce(0, +) / Double(blocks.count) / 255
        }
        previousBlocks = blocks

        recentSharpness.append(sharpness)
        if recentSharpness.count > thresholds.recentFrames {
            recentSharpness.removeFirst(recentSharpness.count - thresholds.recentFrames)
        }
        let recentBest = recentSharpness.max() ?? sharpness

        var issues: Set<QualityIssue> = []
        let lowLight = camera.isoFraction >= thresholds.lowLightISOFraction
            && camera.exposureOffset < thresholds.lowLightExposureOffset
        if brightness < thresholds.darkBelow || lowLight {
            issues.insert(.tooDark)
        }
        if brightness > thresholds.brightAbove
            || clipped > thresholds.clippedTooBrightAbove
            || camera.exposureOffset > thresholds.overexposedExposureOffset {
            issues.insert(.tooBright)
        } else if clipped > thresholds.glareAbove {
            issues.insert(.glare)
        }
        if let motion, motion > thresholds.movingAbove {
            issues.insert(.moving)
        }
        if camera.isAdjustingFocus {
            issues.insert(.focusing)
        }
        if sharpness < thresholds.sharpnessFloor || sharpness < recentBest * thresholds.sharpnessShareOfRecentBest {
            issues.insert(.blurry)
        }

        let measurements = FrameMeasurements(
            brightness: brightness,
            clippedFraction: clipped,
            sharpness: sharpness,
            recentBestSharpness: recentBest,
            motion: motion
        )
        return FrameQuality(issues: issues, measurements: measurements)
    }

    // MARK: - Measurements

    static func meanBrightness(of image: LumaImage) -> Double {
        guard !image.pixels.isEmpty else { return 0 }
        let total = image.pixels.reduce(0) { $0 + Int($1) }
        return Double(total) / Double(image.pixels.count) / 255
    }

    static func fraction(of image: LumaImage, atLeast level: UInt8) -> Double {
        guard !image.pixels.isEmpty else { return 0 }
        let count = image.pixels.reduce(0) { $0 + ($1 >= level ? 1 : 0) }
        return Double(count) / Double(image.pixels.count)
    }

    /// Variance of the 4-neighbour Laplacian over the image's interior. Sharp edges give
    /// large values; a blurred or featureless picture gives values near zero.
    static func laplacianVariance(of image: LumaImage) -> Double {
        let width = image.width, height = image.height
        guard width >= 3, height >= 3 else { return 0 }
        var sum = 0.0, sumOfSquares = 0.0
        image.pixels.withUnsafeBufferPointer { p in
            for y in 1..<(height - 1) {
                let row = y * width
                for x in 1..<(width - 1) {
                    let i = row + x
                    let center = 4 * Int(p[i])
                    let neighbours = Int(p[i - 1]) + Int(p[i + 1]) + Int(p[i - width]) + Int(p[i + width])
                    let laplacian = Double(center - neighbours)
                    sum += laplacian
                    sumOfSquares += laplacian * laplacian
                }
            }
        }
        let count = Double((width - 2) * (height - 2))
        let mean = sum / count
        return sumOfSquares / count - mean * mean
    }

    /// Mean brightness (0–255) of each whole `blockSize`×`blockSize` block, row by row.
    static func blockMeans(of image: LumaImage, blockSize: Int) -> [Double] {
        let columns = image.width / blockSize, rows = image.height / blockSize
        guard columns > 0, rows > 0 else { return [] }
        var means = [Double](repeating: 0, count: columns * rows)
        image.pixels.withUnsafeBufferPointer { p in
            for y in 0..<(rows * blockSize) {
                let row = y * image.width
                let blockRow = (y / blockSize) * columns
                for x in 0..<(columns * blockSize) {
                    means[blockRow + x / blockSize] += Double(p[row + x])
                }
            }
        }
        let area = Double(blockSize * blockSize)
        return means.map { $0 / area }
    }
}
