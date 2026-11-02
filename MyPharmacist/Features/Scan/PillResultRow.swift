//
//  PillResultRow.swift
//  MyPharmacist
//

import SwiftUI

/// One pill from the photo: the cut-out of it, what it was recognized as (with that
/// medication's reference photo to compare), and whether to take it.
struct PillResultRow: View {
    let pill: ScannedPill

    var body: some View {
        let content = pill.verdict.presentation
        HStack(spacing: 12) {
            Image(decorative: pill.crop, scale: 1)
                .resizable()
                .scaledToFit()
                .padding(6)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.85)))
                .overlay(alignment: .topLeading) {
                    PillNumber(number: pill.id, color: content.color)
                        .offset(x: -6, y: -6)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(pill.medication?.displayName ?? "Unknown pill")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Label(content.title, systemImage: content.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(content.color)
                Text(content.detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                #if DEBUG
                if let distance = pill.match.distance {
                    Text(String(format: "distance %.3f", distance))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Palette.textMuted)
                }
                #endif
            }

            Spacer(minLength: 0)

            if let medication = pill.medication {
                PillImage(medication: medication, size: 44)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(content.color, lineWidth: 2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pill \(pill.id): \(pill.medication?.displayName ?? "Unknown pill")")
        .accessibilityValue("\(content.title). \(content.detail)")
    }
}

/// A dose due now that wasn't in the photo.
struct MissingDoseRow: View {
    let dose: Dose

    var body: some View {
        HStack(spacing: 12) {
            PillImage(medication: dose.medication, size: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(dose.medication.displayName)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Label("Missing", systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.late)
                Text("Due at \(dose.scheduled.shortTime), but not in the photo.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.late, lineWidth: 2))
        .accessibilityElement(children: .combine)
    }
}
