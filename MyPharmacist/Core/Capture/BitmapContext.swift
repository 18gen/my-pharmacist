//
//  BitmapContext.swift
//  MyPharmacist
//

import CoreGraphics

nonisolated extension CGContext {
    /// A picture to draw into: 8-bit sRGB, with images drawn into it scaled smoothly.
    /// - Parameters:
    ///   - transparent: Whether pixels can be see-through, as around a cut-out. Otherwise
    ///     every pixel is solid.
    ///   - data: Memory to draw into, four bytes a pixel, `width * 4` a row; nil to let
    ///     Core Graphics keep its own.
    static func bitmap(width: Int, height: Int, transparent: Bool = false, data: UnsafeMutableRawPointer? = nil) -> CGContext? {
        let alpha: CGImageAlphaInfo = transparent ? .premultipliedLast : .noneSkipLast
        let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: data == nil ? 0 : width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: alpha.rawValue)
        context?.interpolationQuality = .high
        return context
    }
}
