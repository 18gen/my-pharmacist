//
//  TakenDosesToggle.swift
//  MyPharmacist
//

import SwiftUI

/// The header row of the "Taken" card: a peek at the taken medications' pictures and
/// how many there are. Tapping shows or hides those rows.
struct TakenDosesToggle: View {
    let doses: [Dose]
    @Binding var isExpanded: Bool

    /// At most this many pictures overlap in the peek.
    private static let maxPreviews = 3
    @ScaledMetric(relativeTo: .headline) private var pillSize: CGFloat = 30

    /// One picture per medication, so morning and evening Metformin show once.
    private var previews: [Medication] {
        var seen: Set<String> = []
        return doses.map(\.medication).filter { seen.insert($0.id).inserted }.prefix(Self.maxPreviews).map { $0 }
    }

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.4)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: -pillSize * 0.35) {
                    ForEach(previews) { medication in
                        PillImage(medication: medication, size: pillSize)
                            .background(
                                // A ring in the card's colour separates the overlapping pictures.
                                RoundedRectangle(cornerRadius: pillSize * 0.25 + 2, style: .continuous)
                                    .fill(Palette.cardFill)
                                    .padding(-2)
                            )
                    }
                }

                Text("Taken")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text("\(doses.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Palette.taken)
                    .contentTransition(.numericText())

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Taken, \(doses.count) \(doses.count == 1 ? "dose" : "doses")")
        .accessibilityValue(isExpanded ? "Shown" : "Hidden")
        .accessibilityHint(isExpanded ? "Double tap to hide taken doses" : "Double tap to show taken doses")
        .accessibilityAddTraits(.isButton)
    }
}
