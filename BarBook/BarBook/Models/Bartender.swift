import Foundation
import SwiftData

/// A bartender you've met. Stored with SwiftData and mirrored automatically to the
/// user's *private* CloudKit database, so it backs up to iCloud and comes back on a new
/// phone or after a reinstall when signed in to the same Apple ID.
///
/// CloudKit-backed SwiftData rules: every property has a default (or is optional),
/// no `@Attribute(.unique)`, and no non-optional relationships.
@Model
final class Bartender {
    var name: String = ""
    var notes: String = ""

    /// Full-size photo (downscaled JPEG). External storage → synced as a CKAsset.
    @Attribute(.externalStorage) var photoData: Data?
    /// Small JPEG for lists, so scrolling doesn't decode full-size photos.
    var thumbnailData: Data?

    // The pub is stored flat on the record (rather than as a relationship) so two devices
    // that both add "The Crown" offline can't create duplicate pub records that later
    // need merging — grouping happens in code via `Pub.isSamePlace(as:)`.
    var pubName: String = ""
    var pubAddress: String = ""
    var pubLatitude: Double = 0
    var pubLongitude: Double = 0

    var isFavourite: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String, notes: String, pub: Pub, photoData: Data? = nil, thumbnailData: Data? = nil) {
        self.name = name
        self.notes = notes
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.pubName = pub.name
        self.pubAddress = pub.address
        self.pubLatitude = pub.latitude
        self.pubLongitude = pub.longitude
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var pub: Pub {
        get { Pub(name: pubName, address: pubAddress, latitude: pubLatitude, longitude: pubLongitude) }
        set {
            pubName = newValue.name
            pubAddress = newValue.address
            pubLatitude = newValue.latitude
            pubLongitude = newValue.longitude
        }
    }
}
