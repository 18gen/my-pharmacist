//
//  MedicationLine.swift
//  MyPharmacist
//

import SwiftUI

/// One medication in a home screen card: a large picture of the tablet to compare with
/// the one in hand, its name and strength, and what it's for (or, for one taken only when
/// needed, when that is). No dose times: the card says when. Under them, when its pill
/// was scanned. On the right, a circle to tick once it is taken; ticked, it turns green
/// with the time. A dose that is scanned or taken steps back a little.
struct MedicationLine: View {
    let medication: Medication
    /// When this dose's pill was scanned today; nil if it wasn't.
    var scannedAt: Date? = nil
    /// When the person marked this dose taken; nil if they didn't.
    var takenAt: Date? = nil
    /// Ticks or unticks the circle. Nil for a dose that can't be ticked yet: no circle.
    var onToggleTaken: (() -> Void)? = nil

    private var isDone: Bool { scannedAt != nil || takenAt != nil }

    @ScaledMetric(relativeTo: .title3) private var pictureSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title2) private var circleSize: CGFloat = 34
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 14) {
                // At accessibility text sizes the picture gives its room to the words.
                if !typeSize.isAccessibilitySize {
                    PillImage(medication: medication, size: pictureSize)
                }

                VStack(alignment: .leading, spacing: 3) {
                    name
                    detail
                    if let scannedAt {
                        Label("Scanned \(scannedAt.shortTime)", systemImage: "viewfinder")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.ok)
                    }
                }

                Spacer(minLength: 0)
            }
            .opacity(isDone ? 0.7 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(medication.displayName)
            .accessibilityValue([medication.asNeeded ?? medication.purpose,
                                 scannedAt.map { "Scanned at \($0.shortTime)" } ?? "",
                                 onToggleTaken == nil ? takenAt.map { "Taken at \($0.shortTime)" } ?? "" : ""]
                .filter { !$0.isEmpty }.joined(separator: ", "))

            if let onToggleTaken {
                takenCircle(onToggleTaken)
            }
        }
        .padding(.vertical, 8)
    }

    /// The circle to tick, with the word under it so it isn't only a shape: "Taken?"
    /// while empty, "Taken" and the time once ticked.
    private func takenCircle(_ toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            VStack(spacing: 2) {
                Image(systemName: takenAt == nil ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: circleSize, weight: takenAt == nil ? .regular : .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(takenAt.map { "Taken\n\($0.shortTime)" } ?? "Taken?")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize()
            }
            .foregroundStyle(takenAt == nil ? Palette.textSecondary : Palette.ok)
            .frame(minWidth: 56, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: takenAt != nil) { _, taken in taken }
        .accessibilityLabel("\(medication.displayName) taken")
        .accessibilityValue(takenAt.map { "Yes, at \($0.shortTime)" } ?? "No")
        .accessibilityHint(takenAt == nil ? "Double tap to mark it taken" : "Double tap to mark it not taken")
    }

    /// "Capecitabine  500 mg" on one line when it fits, the strength under the name when not.
    private var name: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                nameText
                strengthText
            }
            VStack(alignment: .leading, spacing: 0) {
                nameText
                strengthText
            }
        }
    }

    private var nameText: some View {
        Text(medication.name)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var strengthText: some View {
        Text(medication.strength)
            .font(.body)
            .foregroundStyle(Palette.textSecondary)
    }

    @ViewBuilder
    private var detail: some View {
        if let asNeeded = medication.asNeeded {
            // The same caution sign its pill gets in scan results.
            Label(asNeeded, systemImage: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(Palette.caution)
        } else if !medication.purpose.isEmpty {
            Text(medication.purpose)
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

/// Medications one under another, with dividers between them.
struct MedicationLineList: View {
    struct Item {
        let medication: Medication
        var scannedAt: Date? = nil
        var takenAt: Date? = nil
        var onToggleTaken: (() -> Void)? = nil
    }

    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider()
                }
                MedicationLine(medication: item.medication, scannedAt: item.scannedAt, takenAt: item.takenAt,
                               onToggleTaken: item.onToggleTaken)
            }
        }
    }
}
