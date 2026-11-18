//
//  PharmacyStore.swift
//  MyPharmacist
//

import Foundation
import Observation

/// Keeps the pharmacy, saved on the device in UserDefaults as JSON under "pharmacy.v1".
@Observable
final class PharmacyStore {
    private static let key = "pharmacy.v1"

    /// Saved as it changes: there is no Save to forget.
    var pharmacy: Pharmacy {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults?
    /// Finds where an address is: Apple's place search unless another is given.
    @ObservationIgnored private let locate: (String) async -> PharmacyLocator.Outcome
    @ObservationIgnored private var lookup: Task<Void, Never>?

    /// - Parameters:
    ///   - pharmacy: What to start with when nothing was saved; it is saved then, unless
    ///     it is empty, so that its refill date stays the one it started with.
    ///   - defaults: Where it is saved; nil keeps it in memory only, for tests, previews
    ///     and demos.
    init(pharmacy: Pharmacy = Pharmacy(), defaults: UserDefaults? = nil,
         locate: @escaping (String) async -> PharmacyLocator.Outcome = PharmacyLocator.find) {
        self.defaults = defaults
        self.locate = locate
        if case .value(let saved) = defaults?.saved(Pharmacy.self, forKey: Self.key) {
            self.pharmacy = saved
        } else {
            self.pharmacy = pharmacy
            if !pharmacy.isEmpty { save() }
        }
    }

    /// Keeps the pharmacy as typed. An address without its place on the map yet (Save came
    /// before the look-up made while typing) is looked up now, and its pin added once
    /// found, if the address is still the same then.
    func save(_ new: Pharmacy) {
        lookup?.cancel()
        pharmacy = new
        let address = new.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, new.coordinate == nil else { return }
        lookup = Task { [weak self, locate] in
            guard case .found(let latitude, let longitude) = await locate(address), let self, !Task.isCancelled,
                  pharmacy.address.trimmingCharacters(in: .whitespacesAndNewlines) == address,
                  pharmacy.coordinate == nil else { return }
            pharmacy.latitude = latitude
            pharmacy.longitude = longitude
        }
    }

    /// Replaces the pharmacy with the sample one, for starting a demo over.
    func loadSample(now: Date = Date()) {
        pharmacy = .sample(now: now)
    }

    private func save() {
        defaults?.save(pharmacy, forKey: Self.key)
    }
}

extension Pharmacy {
    /// The pharmacy a new install and "Reset demo" start with: a made-up one, with a
    /// phone number from the range kept for fiction, so no one trying the app calls a
    /// real business. Its refill is a week away so its card has one to show, and where it
    /// is comes built in, so its map needs no lookup.
    static func sample(now: Date = Date(), calendar: Calendar = .current) -> Pharmacy {
        Pharmacy(name: "Sample Pharmacy",
                 phone: "519-555-0100",
                 hours: "Monday to Friday 9 AM – 6 PM",
                 address: "200 University Ave W, Waterloo, ON",
                 latitude: 43.4716,
                 longitude: -80.5453,
                 nextRefill: calendar.date(byAdding: .day, value: Self.sampleRefillDays, to: now))
    }

    /// How far away a new refill date starts: the sample's, and the date picker's first.
    static let sampleRefillDays = 7
}
