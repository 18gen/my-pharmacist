//
//  LumaImage.swift
//  MyPharmacist
//

/// A small grayscale copy of part of a camera frame: brightness 0–255 per pixel, row by
/// row. Every quality check works on this, so the checks can be tested without a camera.
nonisolated struct LumaImage: Sendable, Equatable {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "Expected \(width * height) pixels, got \(pixels.count)")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    subscript(x: Int, y: Int) -> UInt8 {
        pixels[y * width + x]
    }
}
