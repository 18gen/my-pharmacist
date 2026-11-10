//
//  ScanPreview.swift
//  MyPharmacist
//

#if DEBUG
import SwiftUI

/// Canvas previews of the whole scan screen in each step: the instruction above, the
/// camera view with its moving picture, and the bar under it. The camera never starts in
/// a preview, so the live picture is black. Change `ScanLayout`, `ScanHeader` or
/// `CameraLens` and the canvas follows.
enum ScanPreview {
    /// Whether this is running in Xcode's canvas.
    static var isRunning: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

    /// The whole app with a scan open in `phase`, and the camera picture as given.
    @MainActor
    static func screen(_ phase: ScanFlow.Phase, status: QualityGate.Status = .checking,
                       hasLight: Bool = true, isLightOn: Bool = false) -> some View {
        let store = MedicationStore(entries: SampleMedications.demoList, storage: InMemoryDoseLogStorage())
        let scan = ScanFlow(store: store)
        scan.showForPreview(phase)
        scan.scanner.showForPreview(status: status, hasLight: hasLight, isLightOn: isLightOn)
        return RootView(store: store, scan: scan)
    }

    /// The demo's made-up photo of pills.
    static var photo: CGImage { DemoScan.samplePills().photo }
    static var boxes: [CGRect] { DemoScan.samplePills().pills.map(\.box) }
}

#Preview("Aiming") {
    ScanPreview.screen(.aiming)
}

#Preview("Hold still") {
    ScanPreview.screen(.aiming, status: .needs(.moving))
}

#Preview("Too dark: tap Light") {
    ScanPreview.screen(.aiming, status: .needs(.tooDark))
}

#Preview("Light on") {
    ScanPreview.screen(.aiming, isLightOn: true)
}

#Preview("Checking the photo") {
    ScanPreview.screen(.finding(ScanPreview.photo))
}

#Preview("Retake: spread apart") {
    ScanPreview.screen(.retake(ScanPreview.photo, .touching))
}

#Preview("Retake: no pills") {
    ScanPreview.screen(.retake(ScanPreview.photo, .noPills))
}

#Preview("Is every pill circled?") {
    ScanPreview.screen(.confirming(FoundPills(photo: ScanPreview.photo, boxes: ScanPreview.boxes)))
}

#Preview("Checking the pills") {
    ScanPreview.screen(.checking(FoundPills(photo: ScanPreview.photo, boxes: ScanPreview.boxes)))
}
#endif
