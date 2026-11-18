//
//  PharmacyLocator.swift
//  MyPharmacist
//

import MapKit

/// Finds where a typed address is, to put a pin on the pharmacy's map. The address is
/// sent to Apple's place search; nothing else is.
enum PharmacyLocator {
    enum Outcome: Equatable {
        case found(latitude: Double, longitude: Double)
        /// Apple's search found no such place.
        case notFound
        /// Apple's search couldn't be reached: no connection, say.
        case unreachable
    }

    /// The first place Apple's search finds for the address.
    static func find(_ address: String) async -> Outcome {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        request.resultTypes = [.address, .pointOfInterest]
        do {
            guard let item = try await MKLocalSearch(request: request).start().mapItems.first else { return .notFound }
            let coordinate: CLLocationCoordinate2D
            if #available(iOS 26, *) {
                coordinate = item.location.coordinate
            } else {
                coordinate = item.placemark.coordinate
            }
            return .found(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } catch let error as MKError where error.code == .placemarkNotFound {
            return .notFound
        } catch {
            return .unreachable
        }
    }
}
