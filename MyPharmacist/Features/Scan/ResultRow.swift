//
//  ResultRow.swift
//  MyPharmacist
//

import SwiftUI

/// One line of the results page: the pill as it looked in the photo, its name, and one
/// short reason. Tinted and outlined in its level's colour; the section heading above
/// says what to do with it. A pill's row opens on a tap to show more: how to take it,
/// when its dose can be taken, and a button to call the pharmacy when it is one to ask
/// about. Closed, it is the size it always was.
struct ResultRow: View {
    let line: ResultLine
    /// Picked out in the photo above, and opened.
    var isHighlighted = false
    /// What the row shows when opened; nil or empty, it only picks the pill out.
    var detail: ResultDetail? = nil
    /// Tapping the row; nil for a line that is not a pill.
    var onTap: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .title3) private var pictureSize: CGFloat = 64
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) private var openURL

    private var opens: Bool { detail.map { !$0.isEmpty } ?? false }

    var body: some View {
        let level = line.level
        VStack(alignment: .leading, spacing: 0) {
            if let onTap {
                Button(action: onTap) { header }
                    .buttonStyle(.plain)
                    .accessibilityHint(opens ? "Shows this pill in the photo, and more about it" : "Shows this pill in the photo")
            } else {
                header
            }
            if isHighlighted, let detail, !detail.isEmpty {
                more(detail)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(level.fill))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(level.color, lineWidth: isHighlighted ? 4 : 2))
    }

    private var header: some View {
        HStack(spacing: 14) {
            // At accessibility text sizes the picture gives its room to the words.
            if !typeSize.isAccessibilitySize {
                picture
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(line.reason)
                    .font(.body)
                    .foregroundStyle(Palette.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if opens {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .rotationEffect(.degrees(isHighlighted ? 180 : 0))
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.title)
        .accessibilityValue("\(line.level.title). \(line.reason)")
    }

    /// Under a thin line: the directions, the dose's times, and the way to call.
    private func more(_ detail: ResultDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.top, 10)
            if let directions = detail.directions {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Directions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                    Text(directions)
                        .font(.body)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            ForEach(detail.times, id: \.self) { time in
                Label(time, systemImage: "clock")
                    .font(.body)
                    .foregroundStyle(Palette.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let callURL = detail.callURL {
                // The phone asks before it dials.
                WideButton(title: "Call pharmacy", systemImage: "phone.fill", tint: Palette.due) {
                    openURL(callURL)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var picture: some View {
        switch line {
        case .pill(let pill):
            Image(decorative: pill.crop, scale: 1)
                .resizable()
                .scaledToFit()
                .padding(6)
                .frame(width: pictureSize, height: pictureSize)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.85)))
        case .uncheckedPill:
            Image(systemName: "pills")
                .font(.system(size: pictureSize * 0.45, weight: .semibold))
                .foregroundStyle(Palette.caution)
                .frame(width: pictureSize, height: pictureSize)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.background))
        }
    }
}
