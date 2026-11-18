//
//  ResultsPreview.swift
//  MyPharmacist
//

#if DEBUG
import SwiftUI

/// For the canvas: results for the demo's made-up photo at 8 AM, when the morning pills
/// are due, so the preview looks the same whatever the time.
enum ResultsPreview {
    /// - Parameter keeping: Which of the sample's pills to keep (0 metoclopramide,
    ///   1 exemestane, 2 a second metoclopramide, 3 ondansetron, 4 a pill not on the list);
    ///   nil for all of them.
    static func result(keeping: [Int]? = nil, mayHaveMissedPill: Bool = false) -> PillScanResult {
        let store = MedicationStore(entries: SampleMedications.demoList)
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        let sample = DemoScan.samplePills()
        let pills = keeping.map { $0.map { sample.pills[$0] } } ?? sample.pills
        return PillScanResult.judging(pills, photo: sample.photo, store: store, now: morning,
                                      mayHaveMissedPill: mayHaveMissedPill)
    }
}

/// The page with the same insets it has in the scan view.
struct ResultsPreviewPage: View {
    let content: PillResultsView.Content

    init(result: PillScanResult) {
        content = .ready(result)
    }

    init(checking found: FoundPills) {
        content = .checking(found)
    }

    var body: some View {
        PillResultsView(content: content, onDone: {}, onScanAgain: {})
            .padding(.horizontal, 6)
            .padding(.bottom, ScanLayout.pageBottomPadding)
            .padding(.horizontal, ScanLayout.lensEdgeGap)
            .background(Palette.background)
    }
}
#endif
