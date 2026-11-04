import Foundation
import StoreKit

/// One-off "Remove Ads" purchase (StoreKit 2). Restores automatically on a new device
/// because entitlements are tied to the Apple ID, not the install.
@Observable
@MainActor
final class PurchaseManager {
    private(set) var removeAdsProduct: Product?
    private(set) var isPurchasing = false
    var errorMessage: String?

    /// Cached so ads don't flash on launch before StoreKit answers.
    private(set) var hasRemovedAds: Bool = UserDefaults.standard.bool(forKey: "hasRemovedAds") {
        didSet { UserDefaults.standard.set(hasRemovedAds, forKey: "hasRemovedAds") }
    }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.apply(result)
            }
        }
    }

    func loadProducts() async {
        do {
            removeAdsProduct = try await Product.products(for: [AppConfig.removeAdsProductID]).first
        } catch {
            errorMessage = "Couldn't reach the App Store: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AppConfig.removeAdsProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        hasRemovedAds = owned
    }

    func purchaseRemoveAds() async {
        guard let product = removeAdsProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await apply(verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlements()
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            errorMessage = "The purchase couldn't be verified."
            return
        }
        if transaction.productID == AppConfig.removeAdsProductID {
            hasRemovedAds = transaction.revocationDate == nil
        }
        await transaction.finish()
    }
}
