//
//  MedicationStore+Card.swift
//  MyPharmacist
//

import Foundation

/// What scanning a keychain card would do to the list. Nothing is changed until the
/// person agrees to it.
enum CardOutcome: Equatable {
    /// Not on the list: this is what would be added.
    case add(MedicationEntry)
    /// On the list with other times: this is how it would be afterwards.
    case changeSchedule(MedicationEntry)
    /// On the list, with the card's times already.
    case alreadyThere(MedicationEntry)
    /// Not a card, or not for a medication the app has photos of.
    case notACard
}

extension MedicationStore {
    /// What a scanned code would do, without doing it.
    func outcome(ofCard text: String) -> CardOutcome {
        guard let card = MedicationCard(text) else { return .notACard }
        if let onList = entry(card.medicationID) {
            // Only when to take it comes from the card; the person's own words stay.
            let changed = onList.following(card.schedule).tidied
            return changed == onList ? .alreadyThere(onList) : .changeSchedule(changed)
        }
        guard let builtIn = SampleMedications.builtIn(card.medicationID) else { return .notACard }
        return .add(builtIn.following(card.schedule).tidied)
    }

    /// Does what `outcome(ofCard:)` said: adds the medication or changes when it's taken.
    func apply(_ outcome: CardOutcome) {
        switch outcome {
        case .add(let entry): add(entry)
        case .changeSchedule(let entry): update(entry)
        case .alreadyThere, .notACard: break
        }
    }
}

private extension MedicationEntry {
    /// The same medication, taken when a card says.
    func following(_ schedule: MedicationCard.Schedule) -> MedicationEntry {
        var entry = self
        switch schedule {
        case .times(let times):
            entry.isAsNeeded = false
            entry.doseTimes = times
        case .whenNeeded:
            entry.isAsNeeded = true
        }
        return entry
    }
}
