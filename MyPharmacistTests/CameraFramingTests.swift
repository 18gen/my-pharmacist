//
//  CameraFramingTests.swift
//  MyPharmacistTests
//

import Testing
@testable import MyPharmacist

struct CameraFramingTests {
    /// A wide camera (70° along the long side) seen through a 9:16 view: the pills fill
    /// the view from about 111 mm away at zoom 1.
    private func framing(minimumFocus: Double?, native: [Double] = [], deviceZoom: Double = 10) -> CameraFraming {
        CameraFraming(longSideFieldOfView: 70, minimumFocusDistance: minimumFocus, visibleAspect: 9.0 / 16.0,
                      nativeZoomFactors: native, maximumDeviceZoom: deviceZoom)
    }

    @Test func zoomsInUntilThePillsFillTheViewFromWhereTheCameraFocuses() {
        let framing = framing(minimumFocus: 200)
        #expect(abs(framing.zoom - 1.80) < 0.01)
        #expect(abs(framing.visibleWidthMillimeters - 87.5) < 0.01)
    }

    @Test func aCameraThatFocusesCloseEnoughIsNotZoomed() {
        let framing = framing(minimumFocus: 80)
        #expect(framing.zoom == 1)
        #expect(abs(framing.visibleWidthMillimeters - 87.5) < 0.01)
    }

    @Test func withoutAFocusDistanceThereIsNoZoom() {
        #expect(framing(minimumFocus: nil).zoom == 1)
        #expect(framing(minimumFocus: -1).zoom == 1)
    }

    @Test func aFullResolutionZoomFactorIsPreferred() {
        // Asked for 1.8: the sensor's own 2× is used, and the phone is held a little
        // further away, where the pills fill the view just the same.
        let framing = framing(minimumFocus: 200, native: [2])
        #expect(framing.zoom == 2)
        #expect(abs(framing.visibleWidthMillimeters - 87.5) < 0.01)
    }

    @Test func aFullResolutionFactorBelowTheZoomAskedForWidensTheView() {
        // Asked for 2.7; at 2× the pills are smaller in the view but just as detailed.
        let framing = framing(minimumFocus: 300, native: [2])
        #expect(framing.zoom == 2)
        #expect(abs(framing.visibleWidthMillimeters - 118.2) < 0.1)
    }

    @Test func aFullResolutionFactorTooFarBelowIsNotUsed() {
        // Asked for 3 (the most allowed): 2× would leave the pills too small in the view.
        let framing = framing(minimumFocus: 400, native: [2])
        #expect(framing.zoom == 3)
    }

    @Test func zoomStaysWithinWhatTheCameraCanDo() {
        #expect(framing(minimumFocus: 1000).zoom == 3)
        #expect(framing(minimumFocus: 1000, deviceZoom: 2).zoom == 2)
        #expect(framing(minimumFocus: 200, native: [2], deviceZoom: 1.5).zoom == 1.5)
    }

    @Test func aViewWiderThanThePictureShowsItsWholeWidth() {
        // The picture's short side is 3/4 of its long side; a squarer view can't show more.
        let wide = CameraFraming(longSideFieldOfView: 70, minimumFocusDistance: 200, visibleAspect: 0.9, maximumDeviceZoom: 10)
        let exact = CameraFraming(longSideFieldOfView: 70, minimumFocusDistance: 200, visibleAspect: 0.75, maximumDeviceZoom: 10)
        #expect(wide.zoom == exact.zoom)
    }
}
