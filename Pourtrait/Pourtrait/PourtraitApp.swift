import SwiftUI
import SwiftData

@main
struct PourtraitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var syncMonitor: SyncMonitor
    @State private var pubModel: CurrentPubModel
    @State private var purchases = PurchaseManager()
    @State private var ads = AdsManager()

    private let services = AppServices.shared

    init() {
        _syncMonitor = State(initialValue: AppServices.shared.syncMonitor)
        _pubModel = State(initialValue: CurrentPubModel(locationService: LocationService()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(syncMonitor)
                .environment(pubModel)
                .environment(purchases)
                .environment(ads)
        }
        .modelContainer(services.modelContainer)
    }
}
