//
//  LumaSampler.swift
//  MyPharmacist
//

import CoreVideo

/// Copies a small grayscale version of the middle of a camera frame for the quality
/// checks. Reads the brightness (Y) plane directly, so there is no colour conversion and
/// no image object per frame.
nonisolated enum LumaSampler {
    /// Share of the frame's width and height that is checked, centred. The edges are
    /// usually background around the hand.
    static let regionFraction = 0.6
    /// Roughly how wide the copy is. Enough detail to judge blur, cheap enough for 10 Hz.
    static let targetWidth = 256

    /// Returns nil for pixel formats other than the camera's 4:2:0 YCbCr formats.
    static func sample(_ buffer: CVPixelBuffer) -> LumaImage? {
        let isFullRange: Bool
        switch CVPixelBufferGetPixelFormatType(buffer) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: isFullRange = true
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: isFullRange = false
        default: return nil
        }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }

        let planeWidth = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let planeHeight = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let regionWidth = Int(Double(planeWidth) * regionFraction)
        let regionHeight = Int(Double(planeHeight) * regionFraction)
        let left = (planeWidth - regionWidth) / 2
        let top = (planeHeight - regionHeight) / 2

        let step = max(1, regionWidth / targetWidth)
        // Each output pixel averages a 2×2 patch (when stepping), which damps sensor noise.
        let patch = step > 1 ? 1 : 0
        let width = (regionWidth - patch) / step
        let height = (regionHeight - patch) / step
        guard width >= 3, height >= 3 else { return nil }

        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var pixels = [UInt8](repeating: 0, count: width * height)
        pixels.withUnsafeMutableBufferPointer { out in
            for y in 0..<height {
                let row = bytes + (top + y * step) * bytesPerRow
                let nextRow = row + patch * bytesPerRow
                for x in 0..<width {
                    let sx = left + x * step
                    let sum = Int(row[sx]) + Int(row[sx + patch]) + Int(nextRow[sx]) + Int(nextRow[sx + patch])
                    var value = (sum + 2) / 4
                    if !isFullRange {
                        // Video range keeps brightness in 16–235; stretch it to 0–255.
                        value = min(255, max(0, (value - 16) * 255 / 219))
                    }
                    out[y * width + x] = UInt8(value)
                }
            }
        }
        return LumaImage(width: width, height: height, pixels: pixels)
    }
}
