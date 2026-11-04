import Foundation
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

/// Handles ad consent (GDPR/UK GDPR via Google's UMP — required to serve ads in the
/// UK/EEA) and starting the Google Mobile Ads SDK.
///
/// Ad policy for Pourtrait is deliberately light: one small banner at the bottom of the
/// browsing screens. No interstitials, no video, no ads on the add/edit screens or
/// camera, and none at all once "Remove Ads" is bought.
@Observable
@MainActor
final class AdsManager {
    private(set) var canRequestAds = false
    private(set) var isPrivacyOptionsRequired = false
    @ObservationIgnored private var hasStartedSDK = false
    @ObservationIgnored private var isGatheringConsent = false

    func gatherConsentAndStart() async {
        guard !isGatheringConsent else { return }
        isGatheringConsent = true
        defer { isGatheringConsent = false }

        let parameters = RequestParameters()
        #if DEBUG
        // Uncomment to test the consent form as if you were in the EEA/UK:
        // let debug = DebugSettings()
        // debug.geography = .EEA
        // parameters.debugSettings = debug
        #endif

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: UIApplication.topViewController)
        } catch {
            // Consent failures aren't fatal — we can still request ads if a previous
            // session's consent is valid.
            print("Consent error: \(error.localizedDescription)")
        }
        updateConsentState()
    }

    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: UIApplication.topViewController)
        } catch {
            print("Privacy options error: \(error.localizedDescription)")
        }
        updateConsentState()
    }

    private func updateConsentState() {
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        if ConsentInformation.shared.canRequestAds {
            startSDKIfNeeded()
            canRequestAds = true
        }
    }

    private func startSDKIfNeeded() {
        guard !hasStartedSDK else { return }
        hasStartedSDK = true
        MobileAds.shared.start(completionHandler: nil)
    }
}

extension UIApplication {
    /// Top-most view controller, for SDKs that need something to present from.
    static var topViewController: UIViewController? {
        let scenes = shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    static var keyWindowWidth: CGFloat {
        let scene = shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.keyWindow?.bounds.width ?? scene?.screen.bounds.width ?? 390
    }
}
