import Foundation

/// Identifiers you'll need to change to your own before shipping. See README.
enum AppConfig {
    /// Must match the container in BarBook.entitlements.
    static let cloudKitContainerID = "iCloud.com.barbook.app"

    /// Non-consumable in-app purchase that turns adverts off.
    static let removeAdsProductID = "com.barbook.app.removeads"

    #if DEBUG
    /// Google's public test banner unit — always fills, never earns.
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    #else
    /// TODO: replace with your real AdMob banner ad unit ID.
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    #endif

    /// Two records count as "the same pub" when their names match and they're this close.
    static let samePubDistance: Double = 250

    /// How far around you to look for pubs.
    static let nearbySearchRadius: Double = 400
}
