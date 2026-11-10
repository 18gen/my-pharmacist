//
//  WhenNeededCard.swift
//  MyPharmacist
//

import SwiftUI

/// Medications taken only when needed, below the day's times: they belong to no time of
/// day, but it helps to remember they're there, and when they're for. Folded to its header
/// line like every card that isn't due now; tapping it opens it.
struct WhenNeededCard: View {
    let medications: [Medication]
    @Binding var isExpanded: Bool
    /// Called once the card has finished opening.
    let onOpened: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 8) {
                    Label {
                        // Never due "now", so always in the softer black of the other
                        // times of day that aren't due.
                        Text("When needed")
                            .font(.title3.bold())
                            .foregroundStyle(Palette.textSubtitle)
                    } icon: {
                        Image(systemName: "cross.case.fill")
                            .font(.title3)
                            .foregroundStyle(Palette.textSubtitle)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(isExpanded ? "Double tap to hide these medications" : "Double tap to show these medications")

            DrawerLayout(openFraction: isExpanded ? 1 : 0) {
                MedicationLineList(items: medications.map { ($0, nil) })
                    .padding(.top, 8)
            }
            .clipped()
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    /// Opening reports back only once the card has finished growing, so the page can
    /// scroll to where the rows end up.
    private func toggle() {
        withAnimation(.spring(duration: 0.4)) {
            isExpanded.toggle()
        } completion: {
            if isExpanded { onOpened() }
        }
    }
}
