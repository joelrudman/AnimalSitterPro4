# Pourtrait

An iPhone app for remembering bartenders. Save a bartender's name, a description and a
photo. The app tags each one with the pub you're in, which it works out from GPS and
Apple Maps. Open it in a pub and you'll see the bartenders you've saved there.

- **Here tab:** detects the pub you're in, lists the bartenders you've saved there, and
  lets you add one. Tap "Not here? Change pub" if the guess is wrong.
- **Directory tab:** every bartender you've saved, grouped by pub with the nearest pub
  first. You can search names, pubs and notes, and filter to favourites.
- **Arrival Live Activity:** walk into a pub where you've saved bartenders and their names
  and photos appear on your Lock Screen and in the Dynamic Island. See
  [Arrival alerts](#arrival-alerts-live-activity) below.
- **Settings tab:** iCloud backup status, Remove Ads / Restore Purchases, and ad privacy
  choices.

Built in a Linux container without Xcode, so it **has not been compiled or run yet**.
It's a complete SwiftUI source tree. To build it, ship it and fix whatever comes up on the
first compile (most likely small API-name details in the Google Ads SDK, see below), you
need a Mac with Xcode 16 or later.

## How it works

| Requirement | Implementation |
|---|---|
| Name, description, picture | `Models/Bartender.swift` (SwiftData) and `Views/BartenderEditView.swift`. Camera or photo library. Photos are shrunk to about 1600 px JPEG, plus a 200 px thumbnail for lists. |
| Pub detected automatically | `Services/LocationService.swift` gets a one-off GPS fix. `Services/PubFinder.swift` asks Apple Maps (MapKit, free, no API key) for nearby nightlife/brewery points of interest and runs "pub" and "bar" searches. It removes duplicates and puts the closest actual bar first. |
| Directory for the pub you're in | `Views/HereView.swift`. Two records count as the same pub when their names match (ignoring case, accents and a leading "The") and they're within 250 m of each other. GPS drift indoors doesn't split one pub into two. |
| Unobtrusive ads | Google AdMob: one adaptive banner at the bottom of the Here and Directory screens (`Views/Components/BannerAdView.swift`). No interstitials, no video, and no ads on the add/edit screen or the camera. The banner takes no space until an ad loads. A one-off **Remove Ads** in-app purchase (StoreKit 2, `Services/PurchaseManager.swift`) turns ads off for good. |
| Ad consent (UK/EEA law) | Google UMP consent form on first launch (`Services/AdsManager.swift`). It is required to serve ads in the UK/EEA. |
| iCloud / CloudKit backup and restore | SwiftData with `cloudKitDatabase: .private(...)` mirrors everything, photos included (as CKAssets), to the user's **private** CloudKit database. To restore, sign in to the same Apple ID on a new phone or after a reinstall. The data comes back automatically. `Services/SyncMonitor.swift` shows sync status in Settings. It also works offline in a pub with no signal and syncs later. |

## Arrival alerts (Live Activity)

Files: `Services/GeofenceManager.swift`, `Services/ArrivalAlerts.swift`,
`Shared/PubArrivalAttributes.swift` and the `PourtraitWidgets/` extension target, which
draws the Lock Screen and Dynamic Island views.

1. `GeofenceManager` uses `CLMonitor` (iOS 17) to watch a 100 m circle around each pub
   where you've saved bartenders. iOS allows 20 circles per app, so it watches the 20
   nearest and refreshes them as you move. This needs **"Always"** location; the user
   turns it on in Settings → Arrival alerts.
2. **App open when you arrive:** a Live Activity starts right away. It shows "You're at
   The Crown", up to 4 bartenders with photos and names, and "+N" for the rest.
3. **App closed when you arrive:** the geofence wakes the app in the background. **iOS
   doesn't let an app start a Live Activity from the background.** The only exception is
   a server-sent "push-to-start", and that needs a backend with an APNs key. So the app
   sends a **Time Sensitive notification** instead, e.g. "You're at The Crown. Bartenders
   you know here: Sam, Jo and Priya". Tapping it opens the app and starts the Live
   Activity. The same pub won't notify again within 3 hours.
4. When you leave, the Live Activity ends. Ending is allowed from the background. If
   that doesn't happen, it goes stale after 4 hours.

To make the Live Activity appear with no tap at all while the app is closed, you'd add a
small server. On region entry, the app sends the pub ID to the server, which sends a
push-to-start notification. The app already structures the data for this, but it would
mean sending location-derived data off the phone, so it isn't included.

Photos for the Live Activity are copied as 96 px thumbnails into the shared App Group
container (`group.com.pourtrait.app`) so the widget extension can read them.

### Privacy design choice

Data goes into each user's **private** iCloud database, so each person has their own
directory and nobody else sees it. A shared, crowd-sourced directory (everyone's
bartenders visible to everyone at that pub) would mean switching to the CloudKit public
database. It would also mean adding the App Store's user-generated-content requirements:
reporting, blocking, moderation, and a way for bartenders to ask to be removed. Photos of
real people posted publicly raise consent issues, so that was left out of v1.

## Setup on your Mac

1. Get the code onto your Mac, either with
   `git clone https://github.com/joelrudman/animalsitterpro4.git` followed by
   `git checkout claude/pub-bartender-app`, or by downloading the branch as a ZIP from
   GitHub.
2. Double-click **`Pourtrait/Pourtrait.xcodeproj`**. The first time it opens, Xcode
   downloads the Google Mobile Ads and UMP Swift packages, which takes a minute.
   If Xcode says it can't resolve them, choose **File → Packages → Resolve Package
   Versions**.

   The project is committed, so you don't need XcodeGen. To regenerate it after adding
   files, run `ruby scripts/generate_xcodeproj.rb` (needs `gem install xcodeproj`), or
   `xcodegen generate` if you prefer XcodeGen.
3. **Signing & Capabilities** (Pourtrait target):
   - Set your Team.
   - Change the bundle ID `com.pourtrait.app` to your own. Update it in `project.yml`, the
     iCloud container in `Pourtrait.entitlements` and `AppConfig.cloudKitContainerID`.
   - Check that **iCloud → CloudKit**, **Push Notifications** and **Background Modes →
     Remote notifications** are on. CloudKit sync uses silent pushes.
   - Do the same for the `PourtraitWidgets` target (bundle ID `com.pourtrait.app.widgets`).
     Both targets need the **App Group** `group.com.pourtrait.app`, renamed to match
     your bundle ID. The app also needs **Time Sensitive Notifications**.
4. Run it on a real iPhone signed in to iCloud. MapKit pub search and the camera don't
   work well in the simulator.
5. The scheme uses `Configuration.storekit`, so you can test the Remove Ads purchase
   locally without App Store Connect.

### Before you ship to the App Store

- **AdMob:** create an app and a banner ad unit at admob.google.com. Then:
  - Replace `GADApplicationIdentifier` in `Info.plist` and `bannerAdUnitID` (release
    branch) in `AppConfig.swift`. Both currently hold Google's *test* IDs.
  - Paste Google's full `SKAdNetworkItems` list into `Info.plist`. Only Google's own
    entry is there now.
  - In AdMob → Privacy & messaging, create a GDPR message. You can add an IDFA (App
    Tracking Transparency) message too; UMP will then show the ATT prompt.
- **CloudKit:** save a bartender once in a development build. Then open the CloudKit
  Console and **deploy the schema to Production**. Otherwise App Store builds can't sync.
- **In-app purchase:** create a non-consumable product `com.pourtrait.app.removeads` (or
  your renamed ID) in App Store Connect.
- **App icon:** add a 1024×1024 image to `Assets.xcassets/AppIcon.appiconset`.
- **App privacy labels:** declare Location (app functionality, not linked), Photos (user
  content), and the data the Google Mobile Ads SDK collects (Google publishes the list).
  The SDK includes its own privacy manifest.

## Screenshots

`docs/screenshots/` contains **design mockups** of the main screens and the Live
Activity. They're HTML recreations of the SwiftUI layouts, rendered at iPhone size,
because this code hasn't been run on a device yet. Real simulator screenshots will
differ in small details.

## Things to check on first compile

- The Google Mobile Ads SDK renamed its Swift API in v12 (`BannerView`, `MobileAds.shared`,
  `Request`, `currentOrientationAnchoredAdaptiveBanner(width:)`, and UMP's
  `ConsentInformation.shared` / `ConsentForm`). This code targets v12+ and UMP v3+. If
  Xcode resolves older packages, the old names are `GADBannerView`, `GADMobileAds.sharedInstance()`,
  `UMPConsentInformation.sharedInstance` and so on.
- `MKMapItem.placemark` is deprecated on iOS 26. It still works and only produces a
  warning. The app targets iOS 17+.

## Ideas for later

- Push-to-start server so the Live Activity appears without tapping the notification
  (see above).
- A Home Screen widget showing your favourite bartenders.
- Optional shared directory through the CloudKit public database, with moderation (see
  above).
