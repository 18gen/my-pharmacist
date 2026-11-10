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
///
/// While the pills are still being checked, the same page stands ready: "Checking…" with
/// a spinner where the summary and its icon will be, the photo with each pill in a
/// neutral ring, and grey placeholders for the list. When the answer comes, only the
/// contents change, in place, so nothing on the page moves.
struct PillResultsView: View {
    /// What the page shows.
    enum Content {
        /// The pills the person confirmed, being recognized.
        case checking(FoundPills)
        case ready(PillScanResult)
    }

    let content: Content
    let onDone: () -> Void
    let onScanAgain: () -> Void

    init(content: Content, onDone: @escaping () -> Void, onScanAgain: @escaping () -> Void) {
        self.content = content
        self.onDone = onDone
        self.onScanAgain = onScanAgain
    }

    init(result: PillScanResult, onDone: @escaping () -> Void, onScanAgain: @escaping () -> Void) {
        self.init(content: .ready(result), onDone: onDone, onScanAgain: onScanAgain)
    }

    private static let fadeHeight: CGFloat = 24
    static let checkingText = "Checking…"

    @State private var highlighted: Int?

    private var result: PillScanResult? {
        if case .ready(let result) = content { result } else { nil }
    }

    private var photo: CGImage {
        switch content {
        case .checking(let found): found.photo
        case .ready(let result): result.photo
        }
    }

    /// One ring per pill, numbered in reading order in both states, so each keeps its
    /// place when it takes its colour.
    private var rings: [ResultPhoto.Ring] {
        switch content {
        case .checking(let found):
            found.boxes.enumerated().map { ResultPhoto.Ring(id: $0.offset + 1, box: $0.element, level: nil) }
        case .ready(let result):
            result.pills.map { ResultPhoto.Ring(id: $0.id, box: $0.box, level: $0.verdict.level) }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            summary
            ResultPhoto(photo: photo, rings: rings, highlighted: highlighted)
            list
            nextStep
        }
        .animation(.easeInOut(duration: 0.3), value: result == nil)
    }

    /// What to do, in one line, with its level's icon: the page's heading. Spoken when
    /// the page appears (`ScanFeedback`). While checking, "Checking…" with a spinner in
    /// the icon's place.
    private var summary: some View {
        let text = result?.summary ?? Self.checkingText
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            // The icon's slot: an invisible symbol keeps it the icon's size and on the
            // words' baseline, so the words start in the same place in both states.
            Image(systemName: "circle.fill")
                .hidden()
                .overlay {
                    if let result {
                        Image(systemName: result.summaryLevel.icon)
                            .foregroundStyle(result.summaryLevel.color)
                            .fixedSize()
                            .transition(.opacity)
                    } else {
                        ProgressView()
                            .transition(.opacity)
                    }
                }
                .accessibilityHidden(true)
            ZStack(alignment: .leading) {
                Text(text)
                    .foregroundStyle(Palette.textPrimary)
                    // "Checking…" stays on one line, a little smaller if it must, rather
                    // than leaving its dots on a line of their own.
                    .lineLimit(result == nil ? 1 : nil)
                    .minimumScaleFactor(result == nil ? 0.6 : 1)
                    .fixedSize(horizontal: false, vertical: result != nil)
                    .id(text)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .font(.title2.bold())
        .padding(.horizontal, 10)
        .padding(.top, 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(result?.summary ?? "Checking your pills")
        .accessibilityAddTraits(.isHeader)
    }

    /// Every pill grouped by what to do with it, or placeholders while checking. Both
    /// start at the same place, one over the other while they swap.
    private var list: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                switch content {
                case .ready(let result):
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(result.groups) { group in
                            ResultSection(group: group, highlighted: $highlighted)
                        }
                    }
                    .transition(.opacity)
                case .checking(let found):
                    ResultSkeleton(count: found.boxes.count)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            // Room to scroll the last row clear of the fade.
            .padding(.bottom, Self.fadeHeight)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDisabled(result == nil)
        // Rows below the buttons fade out instead of being cut off, a hint that
        // there is more to scroll to.
        .mask {
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.fadeHeight)
            }
        }
    }

    @ViewBuilder
    private var nextStep: some View {
        if let result {
            Group {
                if result.needsRescan {
                    // One row while both fit; at the largest text sizes, one above the other.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            scanAgainButton(result)
                            closeButton
                        }
                        VStack(spacing: 8) {
                            scanAgainButton(result)
                            closeButton
                        }
                    }
                } else {
                    WideButton(title: "Done", systemImage: "checkmark", action: onDone)
                }
            }
            .transition(.opacity)
        } else {
            // No buttons yet: the close button (drawn by the screen) sits here, and can
            // still stop the check.
            Color.clear.frame(height: ScanLayout.buttonSize)
        }
    }

    private func scanAgainButton(_ result: PillScanResult) -> some View {
        WideButton(title: "Scan again", systemImage: "camera.fill", action: onScanAgain)
            .accessibilityHint(result.putBackCount > 0 ? "Put back the pills not to take first" : "Spread the pills apart first")
    }

    /// Second to "Scan again": grey, and only as wide as its word.
    private var closeButton: some View {
        SecondaryButton(title: "Close", action: onDone)
    }
}

/// The list's shape while the pills are checked: a heading and one row per pill, in the
/// sizes of the real ones, in grey. The levels aren't known yet, so neither are the
/// headings or the order: no pictures or words, only where they will be. The blocks
/// slowly breathe, and hold still with Reduce Motion.
private struct ResultSkeleton: View {
    let count: Int

    @ScaledMetric(relativeTo: .title3) private var pictureSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title3) private var headingSize: CGFloat = 22
    @ScaledMetric(relativeTo: .title3) private var titleHeight: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var reasonHeight: CGFloat = 14
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                blocks
            } else {
                PhaseAnimator([false, true]) { dimmed in
                    blocks.opacity(dimmed ? 0.45 : 1)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
            }
        }
        // The heading above says the pills are being checked.
        .accessibilityHidden(true)
    }

    private var blocks: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .frame(width: headingSize, height: headingSize)
                Capsule()
                    .frame(width: 150, height: headingSize * 0.75)
            }
            .foregroundStyle(Palette.skeleton)
            ForEach(0..<count, id: \.self) { _ in
                row
            }
        }
    }

    /// In the shape of `ResultRow`.
    private var row: some View {
        HStack(spacing: 14) {
            if !typeSize.isAccessibilitySize {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .frame(width: pictureSize, height: pictureSize)
            }
            VStack(alignment: .leading, spacing: 10) {
                Capsule()
                    .frame(maxWidth: 170)
                    .frame(height: titleHeight)
                Capsule()
                    .frame(maxWidth: 110)
                    .frame(height: reasonHeight)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.skeleton)
        .padding(12)
        .frame(minHeight: pictureSize + 24)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.cardFill))
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
        let store = MedicationStore(entries: SampleMedications.demoList, storage: InMemoryDoseLogStorage())
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        let sample = DemoScan.samplePills()
        let pills = keeping.map { $0.map { sample.pills[$0] } } ?? sample.pills
        let identities = pills.map { pill in store.medications.first { $0.id == pill.medicationID } }
        let check = store.check(identities, now: morning)
        let scanned = pills.indices.map { index in
            ScannedPill(id: index + 1, box: pills[index].box, crop: pills[index].crop, medication: identities[index],
                        verdict: check.verdicts[index])
        }
        return PillScanResult(photo: sample.photo, pills: scanned, mayHaveMissedPill: mayHaveMissedPill)
    }
}

/// The page with the same insets it has in the scan view.
private struct ResultsPreviewPage: View {
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

#Preview("Put back pills") {
    ResultsPreviewPage(result: ResultsPreview.result())
}

#Preview("All OK") {
    ResultsPreviewPage(result: ResultsPreview.result(keeping: [0, 1]))
}

#Preview("A pill may be unchecked") {
    ResultsPreviewPage(result: ResultsPreview.result(keeping: [0, 1], mayHaveMissedPill: true))
}

#Preview("Checking (skeleton)") {
    let sample = DemoScan.samplePills()
    ResultsPreviewPage(checking: FoundPills(photo: sample.photo, boxes: sample.pills.map(\.box)))
}
#endif
