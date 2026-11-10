//
//  ScanLayout.swift
//  MyPharmacist
//

import SwiftUI

/// Sizes shared by the camera button and the camera view it grows into, so the button
/// sits at exactly the same spot whether the camera is open or closed.
enum ScanLayout {
    static let buttonSize: CGFloat = 72
    /// How the camera opens and closes: the button growing into the picture and back.
    static let openingAnimation = Animation.spring(duration: 0.5, bounce: 0.15)
    /// Gap between the open camera view and the screen's sides and bottom.
    static let lensEdgeGap: CGFloat = 10
    /// Gap between the close button and the bottom of the open camera view.
    static let buttonGapInLens: CGFloat = 24
    /// Distance from the physical bottom of the screen to the button, on both screens.
    static let buttonBottomInset: CGFloat = lensEdgeGap + buttonGapInLens
    /// Roughly follows the screen's rounded corners at the 10pt inset.
    static let lensCornerRadius: CGFloat = 44
    /// Space below a button inside the camera view, so it sits just above the close button.
    static let lensButtonBottomPadding: CGFloat = buttonSize + buttonGapInLens + 12
    /// Space below the results page's buttons, clear of the home indicator. The close
    /// button is hidden there, so the page's own buttons take its place.
    static let pageBottomPadding: CGFloat = 24
    /// Height at the bottom of the home screen used by the "Scan Pills" hint and button.
    static let homeReservedHeight: CGFloat = 130

    /// Above the open camera view: room for the scan's instruction in up to two lines,
    /// more at the largest text sizes. The moving picture that goes with it is drawn on
    /// the camera picture instead.
    static let headerWordsHeight: CGFloat = 84
    static let largeTextHeaderWordsHeight: CGFloat = 126
    /// How much higher the camera picture sits, as extra room in the bar under it. Raising
    /// it moves the picture up without changing its size, as the room for the instruction
    /// shrinks by the same amount; the close button stays where the home screen's camera
    /// button is.
    static let lensLift: CGFloat = 24
    /// The camera picture's rounded corners, and the photo's on the confirm step.
    static let pictureCornerRadius: CGFloat = 28

    static func headerWordsHeight(largeText: Bool) -> CGFloat {
        largeText ? largeTextHeaderWordsHeight : headerWordsHeight
    }
    /// The bar at the bottom of the open camera view, under the camera picture: the close
    /// button and the light, or Retake and Cancel, in one row at the close button's height,
    /// with `lensLift` of room above them.
    static let controlBarHeight: CGFloat = buttonGapInLens + buttonSize + 14 + lensLift

    /// The open camera view: 10pt from each side and from the bottom, reaching up to the
    /// instruction.
    /// - Parameter largeText: The person uses one of the accessibility text sizes.
    static func openLensSize(in container: CGSize, largeText: Bool = false) -> CGSize {
        CGSize(width: container.width - 2 * lensEdgeGap,
               height: max(0, container.height - headerWordsHeight(largeText: largeText) - lensEdgeGap))
    }

    /// The camera picture's height: the open camera view above its bar.
    static func pictureHeight(in container: CGSize, largeText: Bool = false) -> CGFloat {
        max(0, openLensSize(in: container, largeText: largeText).height - controlBarHeight)
    }

    /// Gap between the status bar and the top of the results page.
    static let resultsTopGap: CGFloat = 8

    /// The results page: from just under the status bar, where the scan's instruction
    /// was, down to the sides' gap from the screen's physical bottom. It has no close
    /// button under it, so it takes that room too. The page says what to do at its own top.
    /// - Parameters:
    ///   - container: The screen inside its safe area.
    ///   - bottomInset: The home indicator's strip under it, which the page reaches into.
    static func resultsPageSize(in container: CGSize, bottomInset: CGFloat = 0) -> CGSize {
        CGSize(width: container.width - 2 * lensEdgeGap,
               height: max(0, container.height + bottomInset - resultsTopGap - lensEdgeGap))
    }

    /// Width over height of the camera picture: the open camera view above its bar.
    static func lensAspect(in container: CGSize, largeText: Bool = false) -> Double {
        let width = openLensSize(in: container, largeText: largeText).width
        let height = pictureHeight(in: container, largeText: largeText)
        return height > 0 ? Double(width / height) : 9.0 / 16.0
    }

    /// The room for the scan's instruction, from the status bar down. The camera view is
    /// as tall as the safe area less this and `lensEdgeGap`, and ends `lensEdgeGap` above
    /// the screen's physical bottom.
    static func headerHeight(in container: CGSize, largeText: Bool = false) -> CGFloat {
        max(0, container.height - openLensSize(in: container, largeText: largeText).height - lensEdgeGap)
    }
}
