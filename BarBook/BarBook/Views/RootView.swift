import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CurrentPubModel.self) private var pubModel
    @Environment(PurchaseManager.self) private var purchases
    @Environment(AdsManager.self) private var ads
    @Environment(SyncMonitor.self) private var sync

    var body: some View {
        TabView {
            HereView()
                .tabItem { Label("Here", systemImage: "mappin.and.ellipse") }
            DirectoryView()
                .tabItem { Label("Directory", systemImage: "person.2.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            await sync.refreshAccountStatus()
            await pubModel.refresh()
            await purchases.loadProducts()
            await purchases.refreshEntitlements()
            if !purchases.hasRemovedAds {
                await ads.gatherConsentAndStart()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await pubModel.refresh() }
            }
        }
    }
}
