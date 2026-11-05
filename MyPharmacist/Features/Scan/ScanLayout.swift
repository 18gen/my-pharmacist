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
    /// Space below the results page's buttons, clear of the home indicator. The close
    /// button is hidden there, so the page's own buttons take its place.
    static let pageBottomPadding: CGFloat = 24
    /// Height at the bottom of the home screen used by the "Scan Pills" hint and button.
    static let homeReservedHeight: CGFloat = 130

    /// The open camera view: 10pt from each side and about 80% of the screen height.
    static func openLensSize(in container: CGSize) -> CGSize {
        CGSize(width: container.width - 2 * lensEdgeGap, height: container.height * 0.8)
    }

    /// The space between the status bar and the top of the open camera view, where the
    /// scan's instruction goes. The camera view ends `lensEdgeGap` above the bottom of the
    /// safe area (it doesn't reach into the home indicator's strip), so that is all there
    /// is below it; counting the strip as well made this space too tall, and its centred
    /// picture and words ran into the camera view.
    static func headerHeight(in container: CGSize) -> CGFloat {
        max(0, container.height - openLensSize(in: container).height - lensEdgeGap)
    }
}
