//
//  MedicationLine.swift
//  MyPharmacist
//

import SwiftUI

/// One medication in a home screen card: a large picture of the tablet to compare with
/// the one in hand, its name and strength, and what it's for (or, for one taken only when
/// needed, when that is). No times or hours: the card says when. A scanned dose gets a
/// tick and steps back a little.
struct MedicationLine: View {
    let medication: Medication
    var isScanned = false

    @ScaledMetric(relativeTo: .title3) private var pictureSize: CGFloat = 64
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 14) {
            // At accessibility text sizes the picture gives its room to the words.
            if !typeSize.isAccessibilitySize {
                PillImage(medication: medication, size: pictureSize)
            }

            VStack(alignment: .leading, spacing: 3) {
                name
                detail
            }

            Spacer(minLength: 0)

            if isScanned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.ok)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .opacity(isScanned ? 0.7 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(medication.displayName)
        .accessibilityValue([medication.asNeeded ?? medication.purpose, isScanned ? "Scanned" : ""]
            .filter { !$0.isEmpty }.joined(separator: ", "))
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
    let items: [(medication: Medication, isScanned: Bool)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider()
                }
                MedicationLine(medication: item.medication, isScanned: item.isScanned)
            }
        }
    }
}
