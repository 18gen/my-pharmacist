//
//  PharmacyTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

@MainActor
struct PharmacyTests {
    @Test func aNewPharmacyIsEmpty() {
        #expect(Pharmacy().isEmpty)
        #expect(Pharmacy(name: "  ").isEmpty)
        #expect(!Pharmacy(phone: "519-555-0142").isEmpty)
        #expect(!Pharmacy(nextRefill: Date()).isEmpty)
    }

    @Test func aPharmacySavedBeforeItHadAnAddressStillLoads() throws {
        let saved = Data(#"{"name":"Corner Drugs","phone":"555-0100","hours":"9 to 5"}"#.utf8)
        let pharmacy = try JSONDecoder().decode(Pharmacy.self, from: saved)
        #expect(pharmacy == Pharmacy(name: "Corner Drugs", phone: "555-0100", hours: "9 to 5"))
        #expect(pharmacy.coordinate == nil)
    }

    @Test func aPharmacyWithEverythingSurvivesSavingAndLoading() throws {
        let pharmacy = Pharmacy.sample(now: Date(timeIntervalSince1970: 1_800_000_000))
        let loaded = try JSONDecoder().decode(Pharmacy.self, from: JSONEncoder().encode(pharmacy))
        #expect(loaded == pharmacy)
        #expect(loaded.coordinate != nil)
        #expect(!loaded.address.isEmpty)
    }

    @Test func googleMapsIsAskedForTheNameAndAddress() throws {
        let urls = try #require(Pharmacy(name: "Corner Drugs", address: "12 Main St, Waterloo").googleMapsURLs)
        #expect(urls.web.absoluteString == "https://www.google.com/maps/search/?api=1&query=Corner%20Drugs,%2012%20Main%20St,%20Waterloo")
        #expect(urls.app.scheme == "comgooglemaps")
        #expect(URLComponents(url: urls.app, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "Corner Drugs, 12 Main St, Waterloo")

        // The address alone, without a name.
        let unnamed = try #require(Pharmacy(address: "12 Main St").googleMapsURLs)
        #expect(URLComponents(url: unnamed.web, resolvingAgainstBaseURL: false)?.queryItems?.last?.value == "12 Main St")
    }

    @Test func googleMapsIsAskedForThePointWhenThereIsNoAddress() throws {
        let urls = try #require(Pharmacy(name: "Corner Drugs", latitude: 43.5, longitude: -80.5).googleMapsURLs)
        #expect(URLComponents(url: urls.web, resolvingAgainstBaseURL: false)?.queryItems?.last?.value == "43.5,-80.5")
        #expect(Pharmacy(name: "Corner Drugs").googleMapsURLs == nil)
    }

    @Test func theCallURLKeepsOnlyDigitsAndALeadingPlus() {
        #expect(Pharmacy(phone: "(519) 555-0142").callURL?.absoluteString == "tel:5195550142")
        #expect(Pharmacy(phone: " +1 519 555 0142").callURL?.absoluteString == "tel:+15195550142")
        #expect(Pharmacy(phone: "").callURL == nil)
        #expect(Pharmacy(phone: "ask at the desk").callURL == nil)
    }

    @Test func theRefillCountdownCountsWholeDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 23)))
        func refill(in days: Int) -> Pharmacy {
            // Early in the day, so a count by hours would come out a day short.
            let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))
            return Pharmacy(nextRefill: day)
        }
        #expect(refill(in: 0).refillCountdown(now: now, calendar: calendar) == "today")
        #expect(refill(in: 1).refillCountdown(now: now, calendar: calendar) == "tomorrow")
        #expect(refill(in: 8).refillCountdown(now: now, calendar: calendar) == "in 8 days")
        #expect(refill(in: -1).refillCountdown(now: now, calendar: calendar) == nil)
        #expect(Pharmacy().refillCountdown(now: now, calendar: calendar) == nil)
    }

    @Test func thePharmacyIsSavedAsItChanges() throws {
        let name = "PharmacyTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        let store = PharmacyStore(defaults: defaults)
        #expect(store.pharmacy.isEmpty)
        store.pharmacy.name = "Maple Street Pharmacy"
        store.pharmacy.phone = "519-555-0142"

        #expect(PharmacyStore(defaults: defaults).pharmacy == store.pharmacy)
    }

    @Test func aNewInstallStartsWithThePharmacyItIsGivenAndKeepsIt() throws {
        let name = "PharmacyTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let firstLaunch = Date(timeIntervalSince1970: 1_800_000_000)

        let store = PharmacyStore(pharmacy: .sample(now: firstLaunch), defaults: defaults)
        #expect(store.pharmacy.name == "Student Health Pharmacy")

        // A later launch offers a later refill date; the first one was saved and stays.
        let later = PharmacyStore(pharmacy: .sample(now: firstLaunch.addingTimeInterval(86_400 * 3)), defaults: defaults)
        #expect(later.pharmacy == store.pharmacy)
    }

    @Test func loadingTheSampleReplacesThePharmacyAndSavesIt() throws {
        let name = "PharmacyTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let store = PharmacyStore(pharmacy: Pharmacy(name: "Corner Drugs", phone: "555-0100"), defaults: defaults)
        store.loadSample(now: now)

        #expect(store.pharmacy == .sample(now: now))
        #expect(store.pharmacy.callURL?.absoluteString == "tel:5197464500")
        #expect(PharmacyStore(defaults: defaults).pharmacy == store.pharmacy)
    }
}
