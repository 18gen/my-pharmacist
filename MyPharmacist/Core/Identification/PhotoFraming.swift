//
//  PhotoFraming.swift
//  MyPharmacist
//

import CoreGraphics

/// Which part of a photo to show so its pills fill a strip of a given shape.
nonisolated enum PhotoFraming {
    /// The region of the photo, in pixels with the origin at the top left, that holds every
    /// box with a margin around them, widened (or heightened) toward `aspect` as far as the
    /// photo allows. Never cuts a box off: if the photo is too small for the shape, the
    /// region keeps the boxes and the view shows it with bars.
    /// - Parameters:
    ///   - boxes: Normalized 0–1, origin at the top left.
    ///   - aspect: Width over height of where the region will be shown.
    ///   - margin: Around the boxes, as a share of the larger side of the area they cover.
    static func region(around boxes: [CGRect], imageSize: CGSize, aspect: CGFloat, margin: CGFloat = 0.15) -> CGRect {
        let image = CGRect(origin: .zero, size: imageSize)
        guard let first = boxes.first, aspect > 0 else { return image }
        let union = boxes.dropFirst().reduce(first) { $0.union($1) }
        var rect = CGRect(x: union.minX * imageSize.width, y: union.minY * imageSize.height,
                          width: union.width * imageSize.width, height: union.height * imageSize.height)
        let pad = max(rect.width, rect.height) * margin
        rect = rect.insetBy(dx: -pad, dy: -pad).intersection(image)

        // Grow the shorter side toward the strip's shape, centred, within the photo.
        if rect.width / rect.height < aspect {
            rect = grow(rect, toWidth: rect.height * aspect, within: image)
        } else {
            rect = grow(rect, toHeight: rect.width / aspect, within: image)
        }
        return rect
    }

    /// Where a box is on screen when `region` of the photo is shown `shownWidth` wide.
    /// - Parameter box: Normalized 0–1, origin at the top left of the photo.
    static func shown(_ box: CGRect, imageSize: CGSize, region: CGRect, shownWidth: CGFloat) -> CGRect {
        let scale = region.width > 0 ? shownWidth / region.width : 1
        return CGRect(x: (box.minX * imageSize.width - region.minX) * scale,
                      y: (box.minY * imageSize.height - region.minY) * scale,
                      width: box.width * imageSize.width * scale,
                      height: box.height * imageSize.height * scale)
    }

    private static func grow(_ rect: CGRect, toWidth width: CGFloat, within image: CGRect) -> CGRect {
        let width = min(width, image.width)
        let x = min(max(rect.midX - width / 2, image.minX), image.maxX - width)
        return CGRect(x: x, y: rect.minY, width: width, height: rect.height)
    }

    private static func grow(_ rect: CGRect, toHeight height: CGFloat, within image: CGRect) -> CGRect {
        let height = min(height, image.height)
        let y = min(max(rect.midY - height / 2, image.minY), image.maxY - height)
        return CGRect(x: rect.minX, y: y, width: rect.width, height: height)
    }
}
