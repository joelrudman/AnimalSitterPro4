import SwiftUI
import GoogleMobileAds

/// A single adaptive banner pinned to the bottom of a screen. Takes up no space until an
/// ad has actually loaded (so there's never an empty grey box), and disappears entirely
/// once the user has bought "Remove Ads" or hasn't consented to ads.
struct BannerAdSlot: View {
    @Environment(AdsManager.self) private var ads
    @Environment(PurchaseManager.self) private var purchases
    @State private var isLoaded = false

    var body: some View {
        if ads.canRequestAds && !purchases.hasRemovedAds {
            let width = UIApplication.keyWindowWidth
            let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
            BannerAdView(adUnitID: AppConfig.bannerAdUnitID, adSize: adSize, isLoaded: $isLoaded)
                .frame(width: adSize.size.width, height: isLoaded ? adSize.size.height : 0)
                .frame(maxWidth: .infinity)
                .background(.bar)
                .clipped()
                .opacity(isLoaded ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isLoaded)
        }
    }
}

private struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize
    @Binding var isLoaded: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoaded: $isLoaded) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.topViewController
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        private var isLoaded: Binding<Bool>
        init(isLoaded: Binding<Bool>) { self.isLoaded = isLoaded }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            isLoaded.wrappedValue = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            isLoaded.wrappedValue = false
        }
    }
}

extension View {
    /// Adds the (unobtrusive) banner ad below this screen's content.
    func bannerAdInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            BannerAdSlot()
        }
    }
}
