import Foundation
import CoreData
import CloudKit

/// Surfaces iCloud backup status. SwiftData's CloudKit sync runs on
/// NSPersistentCloudKitContainer underneath, which posts an event for every
/// setup / import / export — we listen for those.
@Observable
@MainActor
final class SyncMonitor {
    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            MainActor.assumeIsolated { self?.handle(event) }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                Task { await self?.refreshAccountStatus() }
            }
        })
    }

    func refreshAccountStatus() async {
        do {
            accountStatus = try await CKContainer(identifier: AppConfig.cloudKitContainerID).accountStatus()
        } catch {
            accountStatus = .couldNotDetermine
        }
    }

    var accountDescription: String {
        switch accountStatus {
        case .available: return "Backing up to iCloud"
        case .noAccount: return "Not signed in to iCloud"
        case .restricted: return "iCloud is restricted on this device"
        case .temporarilyUnavailable: return "iCloud temporarily unavailable"
        case .couldNotDetermine: return "Checking iCloud…"
        @unknown default: return "Unknown iCloud status"
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            isSyncing = true
            return
        }
        isSyncing = false
        if event.succeeded {
            if event.type != .setup { lastSyncDate = event.endDate }
            lastErrorMessage = nil
        } else if let error = event.error {
            lastErrorMessage = error.localizedDescription
        }
    }
}
