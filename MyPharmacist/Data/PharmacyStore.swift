//
//  PharmacyStore.swift
//  MyPharmacist
//

import Foundation
import Observation

/// The person's pharmacy, as they typed it: who to call, when it's open, and when the
/// next refill is. Every part is optional.
struct Pharmacy: Codable, Equatable {
    var name = ""
    var phone = ""
    /// Opening hours in the person's own words, such as "Mon to Fri 9 to 6".
    var hours = ""
    var nextRefill: Date?

    /// Nothing has been filled in yet.
    var isEmpty: Bool {
        [name, phone, hours].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } && nextRefill == nil
    }

    /// What to open to call the number: its digits, and a leading "+". Nil without a number.
    var callURL: URL? {
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:" + (trimmed.hasPrefix("+") ? "+" : "") + digits)
    }

    /// "today", "tomorrow" or "in 8 days" until the next refill; nil without a date or
    /// once it has passed.
    func refillCountdown(now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let nextRefill,
              let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                                 to: calendar.startOfDay(for: nextRefill)).day,
              days >= 0 else { return nil }
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(days) days"
        }
    }
}

/// Keeps the pharmacy, saved on the device in UserDefaults as JSON under "pharmacy.v1".
@Observable
final class PharmacyStore {
    private static let key = "pharmacy.v1"

    /// Saved as it changes: there is no Save to forget.
    var pharmacy: Pharmacy {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults?

    /// - Parameters:
    ///   - pharmacy: What to start with when nothing was saved; it is saved then, unless
    ///     it is empty, so that its refill date stays the one it started with.
    ///   - defaults: Where it is saved; nil keeps it in memory only, for tests, previews
    ///     and demos.
    init(pharmacy: Pharmacy = Pharmacy(), defaults: UserDefaults? = nil) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Pharmacy.self, from: data) {
            self.pharmacy = saved
        } else {
            self.pharmacy = pharmacy
            if !pharmacy.isEmpty { save() }
        }
    }

    /// Replaces the pharmacy with the sample one, for starting a demo over.
    func loadSample(now: Date = Date()) {
        pharmacy = .sample(now: now)
    }

    private func save() {
        guard let defaults, let data = try? JSONEncoder().encode(pharmacy) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

extension Pharmacy {
    /// The pharmacy a new install and "Reset demo" start with: the University of
    /// Waterloo's Student Health Pharmacy, with a refill a week away so its card has one
    /// to show. Its phone number and hours are from public health directories.
    static func sample(now: Date = Date(), calendar: Calendar = .current) -> Pharmacy {
        Pharmacy(name: "Student Health Pharmacy",
                 phone: "519-746-4500",
                 hours: "Monday to Friday  9 AM – 4:30 PM\nStudent Life Centre, 200 University Ave W",
                 nextRefill: calendar.date(byAdding: .day, value: 7, to: now))
    }
}
