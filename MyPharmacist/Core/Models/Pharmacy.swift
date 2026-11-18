//
//  Pharmacy.swift
//  MyPharmacist
//

import CoreLocation
import Foundation

/// The person's pharmacy, as they typed it: who to call, when it's open, where it is, and
/// when the next refill is. Every part is optional.
struct Pharmacy: Codable, Equatable {
    var name = ""
    var phone = ""
    /// Opening hours in the person's own words, such as "Mon to Fri 9 to 6".
    var hours = ""
    /// The street address, as typed.
    var address = ""
    /// Where the address was found on the map; nil when it wasn't, or wasn't looked up.
    var latitude: Double?
    var longitude: Double?
    var nextRefill: Date?

    /// Nothing has been filled in yet.
    var isEmpty: Bool {
        [name, phone, hours, address].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } && nextRefill == nil
    }

    /// What to open to call the number: its digits, and a leading "+". Nil without a number.
    var callURL: URL? {
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:" + (trimmed.hasPrefix("+") ? "+" : "") + digits)
    }

    /// Where to put the pin on a map; nil when the address wasn't found.
    var coordinate: CLLocationCoordinate2D? {
        get {
            guard let latitude, let longitude else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    }

    /// What to open to show the pharmacy in Google Maps: the Google Maps app first, and
    /// the same search on the web for a phone without the app. Both look for the name and
    /// address, which lands on the pharmacy's own page; with no address, for the point on
    /// the map. Nil when there is neither.
    var googleMapsURLs: (app: URL, web: URL)? {
        let words = [name, address]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let query: String
        if !words[1].isEmpty {
            query = words.filter { !$0.isEmpty }.joined(separator: ", ")
        } else if let latitude, let longitude {
            query = "\(latitude),\(longitude)"
        } else {
            return nil
        }
        var app = URLComponents()
        app.scheme = "comgooglemaps"
        app.host = ""
        app.queryItems = [URLQueryItem(name: "q", value: query)]
        var web = URLComponents(string: "https://www.google.com/maps/search/")
        web?.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: query)]
        guard let appURL = app.url, let webURL = web?.url else { return nil }
        return (appURL, webURL)
    }

    /// What to open to show the pharmacy in Apple's Maps: a pin where the address was
    /// found, named after the pharmacy. Nil when the address wasn't found.
    var appleMapsURL: URL? {
        guard let latitude, let longitude else { return nil }
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var link = URLComponents(string: "https://maps.apple.com/")
        link?.queryItems = [URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                            URLQueryItem(name: "q", value: label.isEmpty ? "Pharmacy" : label)]
        return link?.url
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

extension Pharmacy {
    /// A pharmacy saved before it had an address has no such keys: every part is read
    /// only if it is there.
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try values.decodeIfPresent(String.self, forKey: .name) ?? "",
                  phone: try values.decodeIfPresent(String.self, forKey: .phone) ?? "",
                  hours: try values.decodeIfPresent(String.self, forKey: .hours) ?? "",
                  address: try values.decodeIfPresent(String.self, forKey: .address) ?? "",
                  latitude: try values.decodeIfPresent(Double.self, forKey: .latitude),
                  longitude: try values.decodeIfPresent(Double.self, forKey: .longitude),
                  nextRefill: try values.decodeIfPresent(Date.self, forKey: .nextRefill))
    }
}
