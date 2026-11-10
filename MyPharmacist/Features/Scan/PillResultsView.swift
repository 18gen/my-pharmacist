//
//  PillResultsView.swift
//  MyPharmacist
//

import SwiftUI

/// The results page, once the camera is off: the photo with each pill ringed in its
/// colour, every pill grouped by what to do with it, most serious first, and one large
/// button for what comes next. When a pill should go back, that button is "Scan again",
/// so whatever is taken in the end has been checked as a whole, with a smaller "Close"
/// beside it. Tapping a pill's row picks it out in the photo, for pills that look alike.
struct PillResultsView: View {
    let result: PillScanResult
    let onDone: () -> Void
    let onScanAgain: () -> Void

    private static let fadeHeight: CGFloat = 24

    @State private var highlighted: Int?

    var body: some View {
        VStack(spacing: 12) {
            summary
            ResultPhoto(photo: result.photo, pills: result.pills, highlighted: highlighted)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(result.groups) { group in
                        ResultSection(group: group, highlighted: $highlighted)
                    }
                }
                .padding(.top, 8)
                // Room to scroll the last row clear of the fade.
                .padding(.bottom, Self.fadeHeight)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            // Rows below the buttons fade out instead of being cut off, a hint that
            // there is more to scroll to.
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: Self.fadeHeight)
                }
            }

            nextStep
        }
    }

    /// What to do, in one line, with its level's icon: the page's heading. Spoken when
    /// the page appears (`ScanFeedback`).
    private var summary: some View {
        let level = result.summaryLevel
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: level.icon)
                .foregroundStyle(level.color)
                .accessibilityHidden(true)
            Text(result.summary)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.title2.bold())
        .padding(.horizontal, 10)
        .padding(.top, 18)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var nextStep: some View {
        if result.needsRescan {
            // One row while both fit; at the largest text sizes, one above the other.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    scanAgainButton
                    closeButton
                }
                VStack(spacing: 8) {
                    scanAgainButton
                    closeButton
                }
            }
        } else {
            WideButton(title: "Done", systemImage: "checkmark", action: onDone)
        }
    }

    private var scanAgainButton: some View {
        WideButton(title: "Scan again", systemImage: "camera.fill", action: onScanAgain)
            .accessibilityHint(result.putBackCount > 0 ? "Put back the pills not to take first" : "Spread the pills apart first")
    }

    /// Second to "Scan again": grey, and only as wide as its word.
    private var closeButton: some View {
        Button(action: onDone) {
            Text("Close")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(minHeight: 34)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Palette.textMuted)
        .fixedSize()
    }
}

/// One level's heading and its rows.
private struct ResultSection: View {
    let group: ResultGroup
    @Binding var highlighted: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(group.level.title, systemImage: group.level.icon)
                .font(.title3.bold())
                .foregroundStyle(group.level.color)
                .accessibilityAddTraits(.isHeader)
            ForEach(group.lines) { line in
                if case .pill(let pill) = line {
                    Button {
                        highlighted = highlighted == pill.id ? nil : pill.id
                    } label: {
                        ResultRow(line: line, isHighlighted: highlighted == pill.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows this pill in the photo")
                } else {
                    ResultRow(line: line)
                }
            }
        }
    }
}

#if DEBUG
/// For the canvas: results for the demo's made-up photo at 8 AM, when the morning pills
/// are due, so the preview looks the same whatever the time.
private enum ResultsPreview {
    /// - Parameter keeping: Which of the sample's pills to keep (0 metoclopramide,
    ///   1 exemestane, 2 a second metoclopramide, 3 ondansetron, 4 a pill not on the list);
    ///   nil for all of them.
    static func result(keeping: [Int]? = nil, mayHaveMissedPill: Bool = false) -> PillScanResult {
        let store = MedicationStore(startingIDs: SampleMedications.startingIDs, storage: InMemoryDoseLogStorage())
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        let sample = DemoScan.samplePills()
        let pills = keeping.map { $0.map { sample.pills[$0] } } ?? sample.pills
        let identities = pills.map { pill in store.medications.first { $0.id == pill.match.medicationID } }
        let check = store.check(identities, now: morning)
        let scanned = pills.indices.map { index in
            ScannedPill(id: index + 1, box: pills[index].box, crop: pills[index].crop, medication: identities[index],
                        verdict: check.verdicts[index], match: pills[index].match)
        }
        return PillScanResult(photo: sample.photo, pills: scanned, mayHaveMissedPill: mayHaveMissedPill)
    }
}

/// The page with the same insets it has in the scan view.
private struct ResultsPreviewPage: View {
    let result: PillScanResult

    var body: some View {
        PillResultsView(result: result, onDone: {}, onScanAgain: {})
            .padding(.horizontal, 6)
            .padding(.bottom, ScanLayout.pageBottomPadding)
            .padding(.horizontal, ScanLayout.lensEdgeGap)
            .background(Palette.background)
    }
}

#Preview("Put back pills") {
    ResultsPreviewPage(result: ResultsPreview.result())
}

#Preview("All OK") {
    ResultsPreviewPage(result: ResultsPreview.result(keeping: [0, 1]))
}

#Preview("A pill may be unchecked") {
    ResultsPreviewPage(result: ResultsPreview.result(keeping: [0, 1], mayHaveMissedPill: true))
}
#endif
