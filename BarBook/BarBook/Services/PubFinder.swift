import Foundation
import MapKit

/// Finds pubs near a location using Apple Maps (no API key, no cost).
enum PubFinder {
    private static let pubCategories: Set<MKPointOfInterestCategory> = [.nightlife, .brewery, .winery]

    /// Nearby pubs, best guess first. Combines a category search (nightlife/brewery) with
    /// text searches for "pub" and "bar", since Apple Maps files plenty of pubs under
    /// "restaurant".
    static func nearbyPubs(around location: CLLocation) async -> [Pub] {
        async let categorised = pointsOfInterest(around: location)
        async let pubs = textSearch("pub", near: location, radius: AppConfig.nearbySearchRadius)
        async let bars = textSearch("bar", near: location, radius: AppConfig.nearbySearchRadius)

        let all = await categorised + (pubs ?? []) + (bars ?? [])
        return rank(dedupe(all), from: location)
    }

    /// Free-text search for a pub by name, centred on the user if we know where they are.
    static func search(_ query: String, near location: CLLocation?) async -> [Pub] {
        let results = await textSearch(query, near: location, radius: 5_000, pubsOnly: false) ?? []
        guard let location else { return dedupe(results) }
        return rank(dedupe(results), from: location)
    }

    // MARK: - Private

    private static func pointsOfInterest(around location: CLLocation) async -> [Pub] {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: AppConfig.nearbySearchRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.nightlife, .brewery, .winery, .restaurant])
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.compactMap(pub(from:))
        } catch {
            return []
        }
    }

    private static func textSearch(_ query: String, near location: CLLocation?, radius: CLLocationDistance, pubsOnly: Bool = true) async -> [Pub]? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        if let location {
            request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: radius * 2, longitudinalMeters: radius * 2)
        }
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.compactMap { item in
                guard var pub = pub(from: item) else { return nil }
                if pubsOnly { pub.isLikelyPub = true }
                return pub
            }
        } catch {
            return nil
        }
    }

    private static func pub(from item: MKMapItem) -> Pub? {
        guard let name = item.name, !name.isEmpty else { return nil }
        let placemark = item.placemark
        let street = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }.joined(separator: " ")
        let address = [street, placemark.locality].filter { !$0.isEmpty }.joined(separator: ", ")
        let isPub = item.pointOfInterestCategory.map { pubCategories.contains($0) } ?? false
        return Pub(
            name: name,
            address: address,
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude,
            isLikelyPub: isPub
        )
    }

    private static func dedupe(_ pubs: [Pub]) -> [Pub] {
        var result: [Pub] = []
        for pub in pubs {
            if let index = result.firstIndex(where: { $0.isSamePlace(as: pub) }) {
                result[index].isLikelyPub = result[index].isLikelyPub || pub.isLikelyPub
            } else {
                result.append(pub)
            }
        }
        return result
    }

    /// Closest first, but nudge restaurants/cafés below actual bars at similar distances.
    private static func rank(_ pubs: [Pub], from location: CLLocation) -> [Pub] {
        func score(_ pub: Pub) -> Double {
            pub.location.distance(from: location) + (pub.isLikelyPub ? 0 : 60)
        }
        return Array(pubs.sorted { score($0) < score($1) }.prefix(30))
    }
}
