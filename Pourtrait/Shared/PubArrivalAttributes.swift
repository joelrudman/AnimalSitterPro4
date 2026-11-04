import Foundation
import ActivityKit

/// The Live Activity shown when you walk into a pub where you've recorded bartenders.
/// Compiled into both the app (which starts it) and the widget extension (which draws it).
struct PubArrivalAttributes: ActivityAttributes {
    struct Person: Codable, Hashable {
        var name: String
        var note: String
        /// File name of a small JPEG in the shared App Group folder, if they have a photo.
        var thumbnailFile: String?
    }

    struct ContentState: Codable, Hashable {
        /// Up to `maxPeople` — ActivityKit caps the payload at 4 KB.
        var people: [Person]
        var totalCount: Int
    }

    static let maxPeople = 4

    var pubID: String
    var pubName: String
    var pubAddress: String
    var arrivedAt: Date
}

enum SharedConfig {
    static let appGroupID = "group.com.pourtrait.app"

    static var thumbnailsDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("LiveActivityThumbnails", isDirectory: true)
    }

    static func thumbnailURL(named name: String) -> URL? {
        thumbnailsDirectory?.appendingPathComponent(name)
    }
}
