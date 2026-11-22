//
//  SharePhoto.swift
//  MyPharmacist
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A scanned pill's cut-out as the pharmacy demo takes it: a small JPEG, about 10 KB, so a
/// week of scans stays light for the phone and the dashboard. The dashboard refuses more
/// than 48 KB.
nonisolated enum SharePhoto {
    /// The longest side, in pixels: the dashboard shows it at 38 points, twice that on a
    /// sharp screen, with room to spare.
    static let longestSide = 192
    static let quality = 0.7

    /// `image` scaled down to `longestSide` (never up) and written as a JPEG; nil if it
    /// can't be drawn or written.
    static func jpeg(_ image: CGImage, longestSide: Int = longestSide, quality: Double = quality) -> Data? {
        let scale = min(1, Double(longestSide) / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        // A JPEG has no transparency: anything see-through in the cut-out turns white.
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage() else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, scaled, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
