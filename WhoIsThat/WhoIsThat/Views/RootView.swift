import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrentPubModel.self) private var pubModel
    @Environment(PurchaseManager.self) private var purchases
    @Environment(AdsManager.self) private var ads
    @Environment(SyncMonitor.self) private var sync
    @AppStorage(ArrivalAlerts.enabledKey) private var arrivalAlertsEnabled = true
    @Query private var bartenders: [Bartender]

    @State private var selectedTab = Tab.here

    enum Tab { case here, directory, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            HereView()
                .tabItem { Label("Here", systemImage: "mappin.and.ellipse") }
                .tag(Tab.here)
            DirectoryView()
                .tabItem { Label("Directory", systemImage: "person.2.fill") }
                .tag(Tab.directory)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .task {
            await sync.refreshAccountStatus()
            await pubModel.refresh()
            await syncGeofences()
            await purchases.loadProducts()
            await purchases.refreshEntitlements()
            if !purchases.hasRemovedAds {
                await ads.gatherConsentAndStart()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                openPendingArrival()
                await pubModel.refresh()
                await syncGeofences()
            }
        }
        // Arriving at (or switching to) a pub you know → Live Activity.
        .onChange(of: pubModel.currentPub?.id) { _, _ in
            Task { await announceCurrentPub() }
        }
        // Added/removed a bartender → refresh the Live Activity and the watched pubs.
        .onChange(of: bartenders.count) { _, _ in
            Task {
                await announceCurrentPub()
                await syncGeofences()
            }
        }
        .onChange(of: arrivalAlertsEnabled) { _, enabled in
            Task {
                if enabled { await announceCurrentPub() } else { await ArrivalAlerts.end() }
                await syncGeofences()
            }
        }
    }

    private func announceCurrentPub() async {
        guard let pub = pubModel.currentPub else { return }
        await ArrivalAlerts.announce(pub: pub, bartenders: Bartender.recorded(at: pub, in: modelContext))
    }

    private func syncGeofences() async {
        await AppServices.shared.geofences.syncRegions(
            near: pubModel.location,
            alwaysAuthorized: pubModel.locationService.isAlwaysAuthorized
        )
    }

    /// The user tapped a "You're at The Crown" notification.
    private func openPendingArrival() {
        guard let id = AppServices.shared.pendingArrivalPubID else { return }
        AppServices.shared.pendingArrivalPubID = nil
        if let pub = AppServices.shared.geofences.pub(withID: id) {
            pubModel.select(pub)
        }
        selectedTab = .here
    }
}
