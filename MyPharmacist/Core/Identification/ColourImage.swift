//
//  ColourImage.swift
//  MyPharmacist
//

import CoreGraphics

/// A small picture as plain numbers: red, green, blue and an unused byte per pixel, row
/// by row from the top left. What the colour checks read, so they can be tested with
/// made-up pictures.
nonisolated struct ColourImage: Sendable {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(width: Int, height: Int, bytes: [UInt8]) {
        precondition(bytes.count == width * height * 4, "Expected \(width * height * 4) bytes, got \(bytes.count)")
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    /// The image drawn at the given size.
    init?(_ image: CGImage, width: Int, height: Int) {
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.init(width: width, height: height, bytes: bytes)
    }

    /// The picture as a `CGImage`, for drawing.
    func cgImage() -> CGImage? {
        var copy = bytes
        return copy.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?.makeImage()
        }
    }
}

/// Colours as people see them (CIE L*a*b*): lightness from 0 to 100, and two colour
/// axes, green to red and blue to yellow. Equal distances look about equally different,
/// which red, green and blue numbers don't give.
nonisolated struct LabImage: Sendable {
    let width: Int
    let height: Int
    private(set) var lightness: [Float]
    private(set) var greenRed: [Float]
    private(set) var blueYellow: [Float]

    init(_ image: ColourImage) {
        let count = image.width * image.height
        width = image.width
        height = image.height
        lightness = [Float](repeating: 0, count: count)
        greenRed = [Float](repeating: 0, count: count)
        blueYellow = [Float](repeating: 0, count: count)
        let linear = Self.linear, curve = Self.curve
        let steps = Float(Self.steps), last = Self.steps
        image.bytes.withUnsafeBufferPointer { bytes in
        linear.withUnsafeBufferPointer { linear in
        curve.withUnsafeBufferPointer { curve in
        lightness.withUnsafeMutableBufferPointer { lightness in
        greenRed.withUnsafeMutableBufferPointer { greenRed in
        blueYellow.withUnsafeMutableBufferPointer { blueYellow in
            for index in 0..<count {
                let r = linear[Int(bytes[index * 4])], g = linear[Int(bytes[index * 4 + 1])], b = linear[Int(bytes[index * 4 + 2])]
                // To the eye's three responses under daylight (D65), each as a share of white's.
                let x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
                let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
                let z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
                let fx = curve[min(last, Int(x * steps))]
                let fy = curve[min(last, Int(y * steps))]
                let fz = curve[min(last, Int(z * steps))]
                lightness[index] = 116 * fy - 16
                greenRed[index] = 500 * (fx - fy)
                blueYellow[index] = 200 * (fy - fz)
            }
        }}}}}}
    }

    /// Screen values (0–255) to amounts of light (0–1).
    private static let linear: [Float] = (0...255).map { value in
        let c = Float(value) / 255
        return c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4)
    }

    private static let steps = 4096
    /// The cube-root curve of L*a*b*, looked up instead of computed per pixel.
    private static let curve: [Float] = (0...steps).map { step in
        let t = Float(step) / Float(steps)
        return t > 0.008856 ? cbrtf(t) : 7.787 * t + 16.0 / 116
    }
}
