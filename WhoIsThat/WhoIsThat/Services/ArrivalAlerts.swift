import Foundation
import UIKit
import ActivityKit
import UserNotifications

/// "You're at The Crown — Sam, Jo and Priya work here."
///
/// iOS only lets an app *start* a Live Activity while it's in the foreground (the one
/// exception is a server-sent push-to-start, which needs a backend). So:
///  - App open (or opened) in a pub you know → Live Activity on the Lock Screen and in
///    the Dynamic Island straight away.
///  - App closed when you walk in → the geofence wakes the app in the background and it
///    posts a Time Sensitive notification listing the bartenders. Tapping it opens the
///    app, which then starts the Live Activity.
///  - Walk out → the Live Activity ends (ending/updating *is* allowed from the background).
@MainActor
enum ArrivalAlerts {
    nonisolated static let enabledKey = "arrivalAlertsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Don't re-notify for the same pub within this window (GPS jitter at the door).
    private static let renotifyInterval: TimeInterval = 3 * 60 * 60
    private static let lastNotifiedKey = "arrivalLastNotified"

    static func announce(pub: Pub, bartenders: [Bartender]) async {
        guard isEnabled else { return }
        guard !bartenders.isEmpty else {
            await end()
            return
        }
        let state = makeState(for: pub, bartenders: bartenders)

        if UIApplication.shared.applicationState == .active {
            await startOrUpdateActivity(pub: pub, state: state)
        } else if !(await tryStartInBackground(pub: pub, state: state)) {
            await notify(pub: pub, bartenders: bartenders)
        }
    }

    static func end(pubID: String? = nil) async {
        for activity in Activity<PubArrivalAttributes>.activities where pubID == nil || activity.attributes.pubID == pubID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Live Activity

    @discardableResult
    private static func startOrUpdateActivity(pub: Pub, state: PubArrivalAttributes.ContentState) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(4 * 60 * 60))

        if let existing = Activity<PubArrivalAttributes>.activities.first(where: { $0.attributes.pubID == pub.id }) {
            await existing.update(content)
            return true
        }
        await end() // only ever one pub at a time

        let attributes = PubArrivalAttributes(pubID: pub.id, pubName: pub.name, pubAddress: pub.address, arrivedAt: Date())
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            return true
        } catch {
            return false
        }
    }

    /// Usually fails (iOS restriction), but costs nothing to try.
    private static func tryStartInBackground(pub: Pub, state: PubArrivalAttributes.ContentState) async -> Bool {
        await startOrUpdateActivity(pub: pub, state: state)
    }

    private static func makeState(for pub: Pub, bartenders: [Bartender]) -> PubArrivalAttributes.ContentState {
        let directory = SharedConfig.thumbnailsDirectory
        if let directory {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let people = bartenders.prefix(PubArrivalAttributes.maxPeople).enumerated().map { index, bartender in
            var file: String?
            if let data = bartender.thumbnailData,
               let image = UIImage(data: data),
               let small = ImageProcessor.squareThumbnail(image, side: 96).jpegData(compressionQuality: 0.7),
               let directory {
                let name = "\(UUID().uuidString)-\(index).jpg"
                if (try? small.write(to: directory.appendingPathComponent(name))) != nil { file = name }
            }
            return PubArrivalAttributes.Person(name: bartender.name, note: String(bartender.notes.prefix(60)), thumbnailFile: file)
        }
        return PubArrivalAttributes.ContentState(people: Array(people), totalCount: bartenders.count)
    }

    // MARK: - Notification fallback

    static func requestNotificationPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private static func notify(pub: Pub, bartenders: [Bartender]) async {
        var lastNotified = UserDefaults.standard.dictionary(forKey: lastNotifiedKey) as? [String: Date] ?? [:]
        if let last = lastNotified[pub.id], Date().timeIntervalSince(last) < renotifyInterval { return }

        let content = UNMutableNotificationContent()
        content.title = "You're at \(pub.name)"
        content.body = "Bartenders you know here: \(namesSentence(bartenders.map(\.name)))"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "arrival"
        content.userInfo = ["pubID": pub.id]

        let request = UNNotificationRequest(identifier: "arrival-\(pub.id)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)

        lastNotified[pub.id] = Date()
        UserDefaults.standard.set(lastNotified, forKey: lastNotifiedKey)
    }

    /// "Sam", "Sam and Jo", "Sam, Jo and Priya", "Sam, Jo, Priya and 2 more"
    static func namesSentence(_ names: [String]) -> String {
        let shown = Array(names.prefix(3))
        let extra = names.count - shown.count
        if extra > 0 { return shown.joined(separator: ", ") + " and \(extra) more" }
        guard shown.count > 1 else { return shown.first ?? "" }
        return shown.dropLast().joined(separator: ", ") + " and " + shown.last!
    }
}
