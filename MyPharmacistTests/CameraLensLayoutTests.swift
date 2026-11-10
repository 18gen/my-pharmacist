//
//  CameraLensLayoutTests.swift
//  MyPharmacistTests
//

import SwiftUI
import Testing
@testable import MyPharmacist

/// The camera picture stays in one place from step to step: what the bar under it holds
/// (the light, Retake and Cancel, or nothing) must not move it.
@MainActor
struct CameraLensLayoutTests {
    private let size = CGSize(width: 373, height: 680)

    /// The camera view drawn in `phase`, as an image at 1 pixel per point.
    private func render(_ phase: ScanFlow.Phase) throws -> CGImage {
        let store = MedicationStore(startingIDs: SampleMedications.startingIDs, storage: InMemoryDoseLogStorage())
        let scan = ScanFlow(store: store)
        scan.showForPreview(phase)
        scan.scanner.showForPreview(status: .checking, hasLight: false)
        let view = CameraLens(scan: scan, isOpen: true, openSize: size)
            .frame(width: size.width, height: size.height + ScanLayout.lensEdgeGap, alignment: .bottom)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    /// The first row from the top that isn't white, in a column at 22% of the width.
    private func pictureTop(_ image: CGImage) -> Int? {
        let x = Int(Double(image.width) * 0.22)
        return (0..<image.height).first { y in
            let p = pixel(of: image, x: x, y: y)
            return p.red + p.green + p.blue < 690
        }
    }

    @Test func thePictureStaysPutWhileCheckingAndOnRetake() throws {
        let photo = DemoScan.samplePills().photo
        let checking = try #require(pictureTop(try render(.finding(photo))))
        let retake = try #require(pictureTop(try render(.retake(photo, .noPills))))
        #expect(checking == retake, "Checking puts the picture at \(checking), retake at \(retake)")
        #expect(retake < 10, "The picture should start at the top of the camera view, not \(retake) down")
    }

    @Test func aimingWithoutALightPutsThePictureInTheSamePlace() throws {
        // A phone with no light, and the Simulator: the bar is empty while aiming. The
        // live camera itself can't be drawn here, but the black box behind it can.
        let photo = DemoScan.samplePills().photo
        let aiming = try #require(pictureTop(try render(.aiming)))
        let retake = try #require(pictureTop(try render(.retake(photo, .noPills))))
        #expect(aiming == retake, "Aiming puts the picture at \(aiming), retake at \(retake)")
    }
}
