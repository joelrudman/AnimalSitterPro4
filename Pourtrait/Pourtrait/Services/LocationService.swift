import Foundation
import CoreLocation

enum LocationError: LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied: return "Location access is off. Turn it on in Settings to find the pub you're in."
        case .unavailable: return "Couldn't get your location. Try again in a moment."
        }
    }
}

/// Thin async wrapper around CLLocationManager for one-shot "where am I?" requests.
@Observable
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var pending: [CheckedContinuation<CLLocation, Error>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isAlwaysAuthorized: Bool { authorizationStatus == .authorizedAlways }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Needed for arrival alerts while the app is closed (geofences run in the background).
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func currentLocation() async throws -> CLLocation {
        guard isAuthorized else { throw LocationError.denied }
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            if pending.count == 1 {
                manager.requestLocation()
            }
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        let waiting = pending
        pending.removeAll()
        waiting.forEach { $0.resume(with: result) }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            self.onAuthorizationChange?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.finish(.success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(.failure(LocationError.unavailable)) }
    }
}
