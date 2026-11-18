//
//  PillResultsView.swift
//  MyPharmacist
//

import SwiftUI

/// The results page, once the camera is off: the photo with each pill ringed in its
/// colour, every pill grouped by what to do with it, most serious first, and one large
/// button for what comes next. When a pill should go back, that button is "Close", on
/// the right, with a smaller "Scan again" on its left, to check the pills again once the
/// wrong ones are put back. When nothing goes back, it is "Done": the pills OK to take were already
/// marked taken when the page opened. Tapping a pill's row picks it out in
/// the photo, for pills that look alike, and opens it to show its directions, its times
/// and, for a pill to ask about, a button to call the pharmacy.
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
    /// What to open to call the person's pharmacy; nil when no number is saved.
    var pharmacyCall: URL? = nil

    init(content: Content, onDone: @escaping () -> Void, onScanAgain: @escaping () -> Void,
         pharmacyCall: URL? = nil) {
        self.content = content
        self.pharmacyCall = pharmacyCall
        self.onDone = onDone
        self.onScanAgain = onScanAgain
    }

    init(result: PillScanResult, onDone: @escaping () -> Void, onScanAgain: @escaping () -> Void) {
        self.init(content: .ready(result), onDone: onDone, onScanAgain: onScanAgain)
    }

    private static let fadeHeight: CGFloat = 24

    /// The pill picked out in the photo, whose row is open.
    @State private var highlighted: Int? = Self.startsOpen

    /// For screenshots: the row a debug launch asks to have open.
    private static var startsOpen: Int? {
        #if DEBUG
        DemoScan.openRow
        #else
        nil
        #endif
    }

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
            // Guideline 1.4.1: a reminder to check with a professional.
            Text("Not medical advice. Ask your pharmacist if unsure.")
                .font(.footnote)
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            nextStep
        }
        .animation(.easeInOut(duration: 0.3), value: result == nil)
    }

    /// What to do, in one line, with its level's icon: the page's heading. Spoken when
    /// the page appears (`ScanFeedback`). While checking, "Checking…" with a spinner in
    /// the icon's place.
    private var summary: some View {
        let text = result?.summary ?? ScanInstruction.checking.text
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
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(result?.summary ?? ScanInstruction.checking.spoken ?? ScanInstruction.checking.text)
        .accessibilityAddTraits(.isHeader)
    }

    /// Every pill grouped by what to do with it, or placeholders while checking. Both
    /// start at the same place, one over the other while they swap.
    private var list: some View {
        ScrollViewReader { proxy in
        ScrollView {
            ZStack(alignment: .topLeading) {
                switch content {
                case .ready(let result):
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(result.groups) { group in
                            ResultSection(group: group, pharmacyCall: pharmacyCall, highlighted: $highlighted)
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
        // A row opened near the bottom is brought fully into view, clear of the fade.
        .onChange(of: highlighted) { _, opened in
            guard let opened else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(ResultLine.pillID(opened), anchor: nil)
            }
        }
        }
    }

    @ViewBuilder
    private var nextStep: some View {
        if let result {
            Group {
                // One row while both fit; at the largest text sizes, one above the other.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        nextStepButtons(result)
                    }
                    VStack(spacing: 8) {
                        nextStepButtons(result)
                    }
                }
            }
            .transition(.opacity)
        } else {
            // No buttons yet: the close button (drawn by the screen) sits here, and can
            // still stop the check.
            Color.clear.frame(height: ScanLayout.buttonSize)
        }
    }

    /// "Scan again" on the left and "Close", the main way on, on the right, when a pill goes
    /// back or may be unchecked; otherwise "Done".
    @ViewBuilder
    private func nextStepButtons(_ result: PillScanResult) -> some View {
        if result.needsRescan {
            scanAgainButton(result)
            closeButton
        } else {
            WideButton(title: "Done", systemImage: "checkmark", action: onDone)
        }
    }

    private func scanAgainButton(_ result: PillScanResult) -> some View {
        SecondaryButton(title: "Scan again", systemImage: "camera.fill", action: onScanAgain)
            .accessibilityHint(result.putBackCount > 0 ? "Put back the pills not to take first" : "Spread the pills apart first")
    }

    /// The main way on, dark and wide: most people close once the wrong pills are put back.
    private var closeButton: some View {
        WideButton(title: "Close", systemImage: "xmark", action: onDone)
    }
}

#if DEBUG
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
