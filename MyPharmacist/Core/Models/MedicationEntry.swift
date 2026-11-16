//
//  MedicationEntry.swift
//  MyPharmacist
//

import Foundation

/// One medication on the person's list, as saved on the device: everything about it, so
/// the list needs nothing else to be shown or checked.
nonisolated struct MedicationEntry: Identifiable, Hashable, Codable, Sendable {
    /// What a medication taken only when needed says when its own words are empty.
    static let defaultAsNeeded = "Only when needed"

    let id: String
    var name: String
    var strength: String
    /// What it's for, in the person's words: "Cancer treatment".
    var purpose: String
    /// What the tablet looks like: "Pink oval · XELODA / 500". Shown to the checker with
    /// the photos; the built-in samples have it, the person's own medications may not.
    var appearance: String
    /// Photos of the tablet, front and back.
    var photos: [MedicationPhoto]
    /// The times of day it's taken. Kept while it's taken only when needed, so switching
    /// back brings them back.
    var doseTimes: [DoseTime]
    var isAsNeeded: Bool
    /// When to take it, for one taken only when needed: "Only when you feel sick".
    var asNeededNote: String
    /// How to take it, as on the label: "With water, after a meal."
    var directions: String

    init(id: String = UUID().uuidString, name: String = "", strength: String = "", purpose: String = "",
         appearance: String = "", photos: [MedicationPhoto] = [], doseTimes: [DoseTime] = [DoseTime(8)],
         isAsNeeded: Bool = false, asNeededNote: String = "", directions: String = "") {
        self.id = id
        self.name = name
        self.strength = strength
        self.purpose = purpose
        self.appearance = appearance
        self.photos = photos
        self.doseTimes = doseTimes
        self.isAsNeeded = isAsNeeded
        self.asNeededNote = asNeededNote
        self.directions = directions
    }

    /// A list saved before medications had directions has no such key: read if there.
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(String.self, forKey: .id),
                  name: try values.decode(String.self, forKey: .name),
                  strength: try values.decode(String.self, forKey: .strength),
                  purpose: try values.decode(String.self, forKey: .purpose),
                  appearance: try values.decode(String.self, forKey: .appearance),
                  photos: try values.decode([MedicationPhoto].self, forKey: .photos),
                  doseTimes: try values.decode([DoseTime].self, forKey: .doseTimes),
                  isAsNeeded: try values.decode(Bool.self, forKey: .isAsNeeded),
                  asNeededNote: try values.decode(String.self, forKey: .asNeededNote),
                  directions: try values.decodeIfPresent(String.self, forKey: .directions) ?? "")
    }

    /// The entry for a medication described in code: the samples, and tests.
    init(_ medication: Medication) {
        self.init(id: medication.id, name: medication.name, strength: medication.strength,
                  purpose: medication.purpose, appearance: medication.appearance, photos: medication.photos,
                  doseTimes: medication.doseTimes.isEmpty ? [DoseTime(8)] : medication.doseTimes,
                  isAsNeeded: medication.asNeeded != nil, asNeededNote: medication.asNeeded ?? "",
                  directions: medication.directions)
    }

    /// The times in order, each once: two doses at the same time would be the same dose.
    var orderedTimes: [DoseTime] {
        Array(Set(doseTimes)).sorted()
    }

    /// Whether it can be on the list: a name, and set times unless taken only when needed.
    /// A medication with set times but none at all would silently never be due.
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (isAsNeeded || !doseTimes.isEmpty)
    }

    /// The same entry with its words trimmed and its times in order, as it's saved.
    var tidied: MedicationEntry {
        var entry = self
        entry.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.strength = strength.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.asNeededNote = asNeededNote.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.directions = directions.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.doseTimes = orderedTimes
        return entry
    }

    /// As the schedule, the screens and the checker see it: no times when it's taken only
    /// when needed, and then its "when" words.
    var medication: Medication {
        Medication(
            id: id,
            name: name,
            strength: strength,
            doseTimes: isAsNeeded ? [] : orderedTimes,
            appearance: appearance,
            photos: photos,
            purpose: purpose,
            asNeeded: isAsNeeded ? (asNeededNote.isEmpty ? Self.defaultAsNeeded : asNeededNote) : nil,
            directions: directions
        )
    }
}

/// A photo of a tablet: one built into the app (the samples), or one the person took,
/// kept as a file on the device (`MedicationPhotoStore`).
nonisolated enum MedicationPhoto: Hashable, Codable, Sendable {
    case asset(String)
    case file(String)
}
