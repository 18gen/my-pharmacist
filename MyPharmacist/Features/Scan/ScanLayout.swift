//
//  ScanLayout.swift
//  MyPharmacist
//

import CoreGraphics

/// Sizes shared by the camera button and the camera view it grows into, so the button
/// sits at exactly the same spot whether the camera is open or closed.
enum ScanLayout {
    static let buttonSize: CGFloat = 72
    /// Gap between the open camera view and the screen's sides and bottom.
    static let lensEdgeGap: CGFloat = 10
    /// Gap between the close button and the bottom of the open camera view.
    static let buttonGapInLens: CGFloat = 24
    /// Distance from the physical bottom of the screen to the button, on both screens.
    static let buttonBottomInset: CGFloat = lensEdgeGap + buttonGapInLens
    /// Roughly follows the screen's rounded corners at the 10pt inset.
    static let lensCornerRadius: CGFloat = 44
    /// Space below the outcome banner inside the camera view: just above the close button.
    static let bannerBottomPadding: CGFloat = buttonSize + buttonGapInLens + 14
    /// Height at the bottom of the home screen used by the "Scan Pills" hint and button.
    static let homeReservedHeight: CGFloat = 170

    /// The open camera view: 10pt from each side and about 80% of the screen height.
    static func openLensSize(in container: CGSize) -> CGSize {
        CGSize(width: container.width - 2 * lensEdgeGap, height: container.height * 0.8)
    }
}
