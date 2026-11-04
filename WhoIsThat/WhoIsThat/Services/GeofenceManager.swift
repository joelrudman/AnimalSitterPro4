import Foundation
import CoreLocation
import SwiftData

/// Watches a circle around each pub where you've recorded bartenders, so the app can be
/// woken up when you walk in — even if it's closed. iOS allows 20 monitored regions per
/// app, so we watch the 20 nearest such pubs and refresh the set as you move around.
///
/// Uses `CLMonitor` (iOS 17). It must be re-created with the same name early in every
/// launch — including background relaunches for a region event — which is why it lives
/// in `AppServices` and starts from `App.init`.
@MainActor
final class GeofenceManager {
    static let monitorName = "WhoIsThatPubs"
    static let maxRegions = 20
    static let regionRadius: CLLocationDistance = 100

    private let container: ModelContainer
    private var monitor: CLMonitor?
    private var eventsTask: Task<Void, Never>?
    private let watchedPubsKey = "geofenceWatchedPubs"

    init(container: ModelContainer) {
        self.container = container
    }

    func start() {
        guard eventsTask == nil else { return }
        eventsTask = Task { [weak self] in
            let monitor = await CLMonitor(Self.monitorName)
            self?.monitor = monitor
            do {
                for try await event in await monitor.events {
                    await self?.handle(identifier: event.identifier, state: event.state)
                }
            } catch {
                print("Geofence monitoring stopped: \(error)")
            }
        }
    }

    /// Re-pick which pubs to watch. Call on launch, when bartenders change, and when the
    /// user's location changes noticeably.
    func syncRegions(near location: CLLocation?, alwaysAuthorized: Bool) async {
        guard let monitor else { return }

        var wanted: [String: Pub] = [:]
        if ArrivalAlerts.isEnabled && alwaysAuthorized {
            let context = ModelContext(container)
            let bartenders = (try? context.fetch(FetchDescriptor<Bartender>())) ?? []
            var pubs = PubGroup.group(bartenders).map(\.pub)
            if let location {
                pubs.sort { $0.location.distance(from: location) < $1.location.distance(from: location) }
            }
            for pub in pubs.prefix(Self.maxRegions) { wanted[pub.id] = pub }
        }

        let existing = Set(await monitor.identifiers)
        for id in existing where wanted[id] == nil {
            await monitor.remove(id)
        }
        for (id, pub) in wanted where !existing.contains(id) {
            let condition = CLMonitor.CircularGeographicCondition(center: pub.coordinate, radius: Self.regionRadius)
            await monitor.add(condition, identifier: id, assuming: .unsatisfied)
        }
        saveWatchedPubs(wanted)
    }

    private func handle(identifier: String, state: CLMonitor.Event.State) async {
        guard let pub = loadWatchedPubs()[identifier] else { return }
        switch state {
        case .satisfied:
            let bartenders = Bartender.recorded(at: pub, in: ModelContext(container))
            await ArrivalAlerts.announce(pub: pub, bartenders: bartenders)
        case .unsatisfied:
            await ArrivalAlerts.end(pubID: pub.id)
        default:
            break
        }
    }

    func pub(withID id: String) -> Pub? {
        loadWatchedPubs()[id]
    }

    // The pub details are persisted so a background relaunch can turn a region
    // identifier back into a name without waiting on anything else.
    private func saveWatchedPubs(_ pubs: [String: Pub]) {
        if let data = try? JSONEncoder().encode(pubs) {
            UserDefaults.standard.set(data, forKey: watchedPubsKey)
        }
    }

    private func loadWatchedPubs() -> [String: Pub] {
        guard let data = UserDefaults.standard.data(forKey: watchedPubsKey),
              let pubs = try? JSONDecoder().decode([String: Pub].self, from: data) else { return [:] }
        return pubs
    }
}
