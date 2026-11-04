import Foundation
import SwiftData
import UIKit
import UserNotifications

/// Long-lived objects that must exist even when iOS relaunches the app in the background
/// for a geofence event (no UI, no SwiftUI scene yet).
@MainActor
final class AppServices {
    static let shared = AppServices()

    let syncMonitor: SyncMonitor
    let modelContainer: ModelContainer
    let geofences: GeofenceManager

    /// Set when the user taps an arrival notification; RootView picks it up once active.
    var pendingArrivalPubID: String?

    private init() {
        // Listen for CloudKit events before the container exists, so we catch the initial
        // setup/import (which is what restores data on a fresh install).
        syncMonitor = SyncMonitor()

        let configuration = ModelConfiguration(
            schema: Schema([Bartender.self]),
            cloudKitDatabase: .private(AppConfig.cloudKitContainerID)
        )
        do {
            modelContainer = try ModelContainer(for: Bartender.self, configurations: configuration)
        } catch {
            fatalError("Couldn't open the database: \(error)")
        }

        geofences = GeofenceManager(container: modelContainer)
        geofences.start()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = AppServices.shared // start geofence monitoring as early as possible
        return true
    }

    // Show arrival notifications even if the app happens to be open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let pubID = response.notification.request.content.userInfo["pubID"] as? String else { return }
        await MainActor.run { AppServices.shared.pendingArrivalPubID = pubID }
    }
}
