//
//  PharmacyLocator.swift
//  MyPharmacist
//

import MapKit

/// Finds where a typed address is, to put a pin on the pharmacy's map. The address is
/// sent to Apple's place search; nothing else is.
enum PharmacyLocator {
    /// The first place Apple's search finds for the address; nil when it finds none or
    /// can't be reached.
    static func find(_ address: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        request.resultTypes = [.address, .pointOfInterest]
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        if #available(iOS 26, *) {
            return item.location.coordinate
        } else {
            return item.placemark.coordinate
        }
    }
}
