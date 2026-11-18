//
//  MedicationCardSheet.swift
//  MyPharmacist
//

import SwiftUI

/// What a scanned keychain card would do, shown before it is done: the medication it
/// would add or the times it would change, with the choice to go ahead. A card never
/// changes the list by itself.
struct MedicationCardSheet: View {
    let outcome: CardOutcome
    /// Adds the medication or changes its times, as shown.
    let onConfirm: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(Palette.pageTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let entry {
                    MedicationRow(medication: entry.medication)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardBackground()
                }

                Text(explanation)
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    switch outcome {
                    case .add:
                        WideButton(title: "Add to my medications", systemImage: "plus", action: onConfirm)
                        SecondaryButton(title: "Cancel", fillsWidth: true, action: onClose)
                    case .changeSchedule:
                        WideButton(title: "Use the card's times", systemImage: "clock", action: onConfirm)
                        SecondaryButton(title: "Cancel", fillsWidth: true, action: onClose)
                    case .alreadyThere, .notACard:
                        SecondaryButton(title: "Close", fillsWidth: true, action: onClose)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        // A little over half the screen: room for the longest of the four, buttons included.
        .presentationDetents([.fraction(0.64), .large])
        .presentationDragIndicator(.visible)
    }

    /// The medication the card is for, as it would be afterwards; nil if it isn't a card.
    private var entry: MedicationEntry? {
        switch outcome {
        case .add(let entry), .changeSchedule(let entry), .alreadyThere(let entry): entry
        case .notACard: nil
        }
    }

    private var title: String {
        switch outcome {
        case .add: "Add this medication?"
        case .changeSchedule: "Change when you take it?"
        case .alreadyThere: "Already on your list"
        case .notACard: "Not a My Pharmacist card"
        }
    }

    private var explanation: String {
        switch outcome {
        case .add:
            "From the card: its name, its pill's pictures and when to take it. You can change them later in Pills."
        case .changeSchedule(let entry):
            "\(entry.name) is already on your list, at other times. These are the card's."
        case .alreadyThere(let entry):
            "\(entry.name) is on your list, taken when the card says. Nothing to change."
        case .notACard:
            "Scan the square code on one of your medication cards."
        }
    }
}

#if DEBUG
#Preview("Add") {
    Color.clear.sheet(isPresented: .constant(true)) {
        MedicationCardSheet(outcome: .add(SampleMedications.sampleList[0]), onConfirm: {}, onClose: {})
    }
}

#Preview("Not a card") {
    Color.clear.sheet(isPresented: .constant(true)) {
        MedicationCardSheet(outcome: .notACard, onConfirm: {}, onClose: {})
    }
}
#endif
