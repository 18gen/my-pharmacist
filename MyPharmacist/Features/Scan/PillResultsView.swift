//
//  PillResultsView.swift
//  MyPharmacist
//

import SwiftUI

/// The results page, once the camera is off: the photo with each pill ringed in its
/// colour, every pill grouped by what to do with it, most serious first, and one large
/// button for what comes next. When a pill should go back, that button is "Scan again",
/// so whatever is taken in the end has been checked as a whole. Tapping a pill's row
/// picks it out in the photo, for pills that look alike.
struct PillResultsView: View {
    let result: PillScanResult
    let onDone: () -> Void
    let onScanAgain: () -> Void

    private static let fadeHeight: CGFloat = 24

    @State private var highlighted: Int?

    var body: some View {
        VStack(spacing: 12) {
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

    @ViewBuilder
    private var nextStep: some View {
        if result.needsRescan {
            VStack(spacing: 4) {
                WideButton(title: "Scan again", systemImage: "camera.fill", action: onScanAgain)
                    .accessibilityHint("Put back the pills not to take first")
                Button("Close", action: onDone)
                    .font(.title3)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        } else {
            WideButton(title: "Done", systemImage: "checkmark", action: onDone)
        }
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
