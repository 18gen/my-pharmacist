//
//  CameraFraming.swift
//  MyPharmacist
//

import Foundation

/// How far to zoom so a few pills fill the camera view from a distance the camera can
/// focus at, and how wide the view then is in real life. Pure numbers, so it can be
/// tested without a camera.
///
/// Phones can't focus on something a few centimetres away, so instead of asking the
/// person to come close, the picture is zoomed (Apple's barcode-scanning approach) and
/// people naturally hold the phone where the pills are sharp.
nonisolated struct CameraFraming: Sendable, Equatable {
    /// Width of a few pills spread out, which should fill most of the view: about 7 cm,
    /// at ~80% of the width.
    static let pillsWidthMillimeters = 70.0
    static let pillsFillFraction = 0.8
    /// More zoom than this only enlarges blur.
    static let maximumZoom = 3.0
    /// A full-resolution zoom factor is used when the pills still fill at least this
    /// share of what they would at the zoom asked for.
    static let nativeZoomReach = 0.7

    /// The camera's field of view along the sensor's long side, in degrees, at zoom 1.
    var longSideFieldOfView: Double
    /// The closest the camera focuses, in millimetres; nil if it doesn't say.
    var minimumFocusDistance: Double?
    /// Width over height of the part of the picture the person sees, in portrait.
    var visibleAspect: Double
    /// The picture's short side over its long side: 3/4 for photos.
    var frameAspect = 3.0 / 4.0
    /// Zoom factors at which the camera reads its sensor at full resolution instead of
    /// enlarging the picture (2 on phones with a 48-megapixel camera).
    var nativeZoomFactors: [Double] = []
    /// The most the camera can zoom.
    var maximumDeviceZoom = 1.0

    /// Half the visible width over the distance to it, at zoom 1. The picture fills the
    /// view (cropping whichever side is too long), so the visible width is the view's
    /// share of the long side, or the picture's whole short side if the view is wider.
    private var halfWidthTangent: Double {
        tan(longSideFieldOfView / 2 * .pi / 180) * min(frameAspect, visibleAspect)
    }

    /// The distance at which the pills fill their share of the view at zoom 1, in mm.
    private var fillDistance: Double {
        (Self.pillsWidthMillimeters / Self.pillsFillFraction / 2) / halfWidthTangent
    }

    /// The zoom to start the camera at.
    var zoom: Double {
        let limit = max(1, min(maximumDeviceZoom, Self.maximumZoom))
        guard longSideFieldOfView > 0, visibleAspect > 0 else { return 1 }
        // Zoom in until the pills fill the view from the closest distance in focus.
        var needed = 1.0
        if let minimumFocusDistance, minimumFocusDistance > 0 {
            needed = min(max(1, minimumFocusDistance / fillDistance), limit)
        }
        // Prefer a factor the sensor delivers at full resolution: at the same distance it
        // shows the same detail as any zoom beyond it, without the enlarging.
        let native = nativeZoomFactors
            .filter { $0 > 1 && $0 <= limit && $0 >= needed * Self.nativeZoomReach }
            .min()
        return native ?? needed
    }

    /// How wide the visible view is in real life, in millimetres, with the phone held
    /// where the pills fill it, or at the closest distance in focus if that is further.
    /// Nothing sharp in the photo is closer than this, so nothing in it is larger than
    /// this scale makes it.
    var visibleWidthMillimeters: Double {
        let filled = Self.pillsWidthMillimeters / Self.pillsFillFraction
        guard longSideFieldOfView > 0, visibleAspect > 0 else { return filled }
        let zoom = zoom
        let distance = max(minimumFocusDistance ?? 0, fillDistance * zoom)
        return 2 * distance * halfWidthTangent / zoom
    }
}
