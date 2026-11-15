//
//  MedicationCard.swift
//  MyPharmacist
//

import Foundation

/// What the QR code on a keychain card says: which of the app's built-in medications the
/// card is for, and when to take it. Written as a link, so the same code can be read by
/// the app's own scanner and by the iPhone's Camera:
///
///     mypharmacist://add?v=1&id=capecitabine-500&t=1230,2000
///     mypharmacist://add?v=1&id=ondansetron-8&prn=1
///
/// It carries no more than the card's printed words.
nonisolated struct MedicationCard: Hashable, Sendable {
    /// When the card says to take it.
    enum Schedule: Hashable, Sendable {
        /// At these times of day, earliest first.
        case times([DoseTime])
        /// Only when needed.
        case whenNeeded
    }

    static let scheme = "mypharmacist"
    /// The only version of the format so far; a card of a later one isn't guessed at.
    static let version = "1"
    /// More times a day than this is a damaged or made-up card.
    static let mostTimes = 6

    let medicationID: String
    let schedule: Schedule

    init(medicationID: String, schedule: Schedule) {
        self.medicationID = medicationID
        self.schedule = schedule
    }

    /// The card for a medication as it is on the list.
    init(_ entry: MedicationEntry) {
        self.init(medicationID: entry.id, schedule: entry.isAsNeeded ? .whenNeeded : .times(entry.orderedTimes))
    }

    /// Reads a scanned code. Nil for anything that isn't exactly a card: another link,
    /// a later version, no medication, both or neither kind of schedule, or a time that
    /// isn't a time of day.
    init?(_ text: String) {
        guard let link = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              link.scheme?.lowercased() == Self.scheme, link.host == "add" else { return nil }
        var values: [String: String] = [:]
        for item in link.queryItems ?? [] {
            // The same thing said twice is a damaged card.
            guard values[item.name] == nil, let value = item.value else { return nil }
            values[item.name] = value
        }
        guard values["v"] == Self.version, let id = values["id"], !id.isEmpty else { return nil }

        switch (values["t"], values["prn"]) {
        case (let times?, nil):
            let parsed = times.split(separator: ",", omittingEmptySubsequences: false).map(Self.time)
            let found = parsed.compactMap { $0 }
            guard found.count == parsed.count, (1...Self.mostTimes).contains(found.count),
                  Set(found).count == found.count else { return nil }
            self.init(medicationID: id, schedule: .times(found.sorted()))
        case (nil, "1"):
            self.init(medicationID: id, schedule: .whenNeeded)
        default:
            return nil
        }
    }

    /// The code's text, as printed on the card.
    var text: String {
        let schedule: String
        switch self.schedule {
        case .times(let times):
            schedule = "t=" + times.map { String(format: "%02d%02d", $0.hour, $0.minute) }.joined(separator: ",")
        case .whenNeeded:
            schedule = "prn=1"
        }
        return "\(Self.scheme)://add?v=\(Self.version)&id=\(medicationID)&\(schedule)"
    }

    /// "1230" as half past twelve; nil unless it is four digits naming a time of day.
    private static func time(_ text: Substring) -> DoseTime? {
        guard text.count == 4, text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let hour = Int(text.prefix(2)), let minute = Int(text.suffix(2)),
              hour < 24, minute < 60 else { return nil }
        return DoseTime(hour, minute)
    }
}
