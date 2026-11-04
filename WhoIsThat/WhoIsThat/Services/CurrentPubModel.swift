import Foundation
import CoreLocation

/// Works out which pub the user is in right now and lets them override it.
@Observable
@MainActor
final class CurrentPubModel {
    enum State: Equatable {
        case idle
        case needsPermission
        case denied
        case locating
        case ready
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var location: CLLocation?
    private(set) var nearbyPubs: [Pub] = []
    private(set) var currentPub: Pub?
    /// True when the user picked the pub themselves; we keep their choice until they move.
    private(set) var isManualSelection = false

    @ObservationIgnored let locationService: LocationService

    init(locationService: LocationService) {
        self.locationService = locationService
        locationService.onAuthorizationChange = { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        guard state != .locating else { return }

        switch locationService.authorizationStatus {
        case .notDetermined:
            state = .needsPermission
            locationService.requestAuthorization()
            return
        case .denied, .restricted:
            state = .denied
            return
        default:
            break
        }

        state = .locating
        do {
            let here = try await locationService.currentLocation()
            location = here
            let pubs = await PubFinder.nearbyPubs(around: here)
            nearbyPubs = pubs

            let movedAway = currentPub.map { $0.location.distance(from: here) > AppConfig.samePubDistance * 1.5 } ?? true
            if !isManualSelection || movedAway {
                currentPub = pubs.first
                isManualSelection = false
            }
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func select(_ pub: Pub) {
        currentPub = pub
        isManualSelection = true
        if !nearbyPubs.contains(where: { $0.isSamePlace(as: pub) }) {
            nearbyPubs.insert(pub, at: 0)
        }
    }

    /// A hand-typed pub at the user's current position, for places Maps doesn't know.
    func customPub(named name: String) -> Pub? {
        guard let location else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Pub(name: trimmed, address: "", latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
}
