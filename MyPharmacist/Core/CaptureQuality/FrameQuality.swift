//
//  FrameQuality.swift
//  MyPharmacist
//

/// Something about the camera picture that would make the pills hard to recognize.
/// Cases are in priority order: when several apply, the first one is the hint shown,
/// so big, slow-to-fix conditions (lighting) come before quick ones (holding still).
nonisolated enum QualityIssue: Int, CaseIterable, Comparable, Sendable {
    case tooDark
    case tooBright
    case glare
    case moving
    case focusing
    case blurry

    static func < (lhs: QualityIssue, rhs: QualityIssue) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// What the camera itself reported for a frame, read alongside its pixels.
nonisolated struct CameraState: Sendable, Equatable {
    var isAdjustingFocus = false
    /// How far the metered exposure is from the camera's target, in EV. Negative means
    /// the camera can't make the picture as bright as it wants to.
    var exposureOffset: Float = 0
    /// Current ISO as a share of the camera's maximum (0–1). Near 1 means very little light.
    var isoFraction: Float = 0
}

/// The numbers each check was decided on, kept for tuning the thresholds on a device.
nonisolated struct FrameMeasurements: Sendable, Equatable {
    /// Mean brightness, 0 (black) to 1 (white).
    var brightness: Double
    /// Share of pixels that are blown out to white.
    var clippedFraction: Double
    /// Variance of the Laplacian: higher means more fine detail, i.e. sharper.
    var sharpness: Double
    /// Sharpest recent frame, which `sharpness` is compared against.
    var recentBestSharpness: Double
    /// Mean change in brightness since the previous checked frame (0–1); nil for the first.
    var motion: Double?
}

/// The result of checking one camera frame.
nonisolated struct FrameQuality: Sendable, Equatable {
    var issues: Set<QualityIssue>
    var measurements: FrameMeasurements

    /// The one issue to tell the person about, if any.
    var topIssue: QualityIssue? { issues.min() }
    var isGood: Bool { issues.isEmpty }
}
