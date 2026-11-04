import SwiftUI
import SwiftData

@main
struct BarBookApp: App {
    private let modelContainer: ModelContainer

    @State private var syncMonitor: SyncMonitor
    @State private var pubModel: CurrentPubModel
    @State private var purchases = PurchaseManager()
    @State private var ads = AdsManager()

    init() {
        // Start listening for CloudKit events before the container exists, so we catch
        // the initial setup/import (which is what restores data on a fresh install).
        _syncMonitor = State(initialValue: SyncMonitor())
        _pubModel = State(initialValue: CurrentPubModel(locationService: LocationService()))

        let configuration = ModelConfiguration(
            schema: Schema([Bartender.self]),
            cloudKitDatabase: .private(AppConfig.cloudKitContainerID)
        )
        do {
            modelContainer = try ModelContainer(for: Bartender.self, configurations: configuration)
        } catch {
            fatalError("Couldn't open the BarBook database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(syncMonitor)
                .environment(pubModel)
                .environment(purchases)
                .environment(ads)
        }
        .modelContainer(modelContainer)
    }
}
