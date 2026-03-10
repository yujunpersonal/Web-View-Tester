import StoreKit
import SwiftUI

@Observable
final class SubscriptionManager {

    // MARK: - Unlock Code

    private static let unlockCodeKey = "proUnlockedByCode"
    private static let secretCode = "PeterIsAwesome"

    // MARK: - State

    var products: [Product] = []
    var isPro: Bool = false
    var isUnlockedByCode: Bool = UserDefaults.standard.bool(forKey: unlockCodeKey)
    var isLifetimeVIP: Bool = false
    var currentSubscription: Product?
    var subscriptionStatus: Product.SubscriptionInfo.RenewalState?
    var subscriptionExpirationDate: Date?
    var isLoading: Bool = false
    var errorMessage: String?
    var isPurchasing: Bool = false
    var lastPurchasedProductName: String?

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?

    // MARK: - Lifecycle

    init() {
        if isUnlockedByCode {
            isPro = true
        }
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    @MainActor
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        // Retry up to 3 times with a short delay — StoreKit testing
        // environment may not be ready immediately at app launch.
        let maxRetries = 3
        for attempt in 1...maxRetries {
            do {
                print("[StoreKit] Attempt \(attempt)/\(maxRetries) — requesting product IDs: \(StoreKitConstants.allProductIDs)")
                let storeProducts = try await Product.products(
                    for: StoreKitConstants.allProductIDs
                )
                print("[StoreKit] Loaded \(storeProducts.count) products: \(storeProducts.map { "\($0.id) (\($0.type))" })")
                products = storeProducts.sorted { $0.price < $1.price }

                if !products.isEmpty { return }

                if attempt < maxRetries {
                    print("[StoreKit] Got 0 products, retrying in 1s...")
                    try await Task.sleep(for: .seconds(1))
                }
            } catch {
                print("[StoreKit] Failed to load products: \(error)")
                errorMessage = "Failed to load products: \(error.localizedDescription)"
                if attempt < maxRetries {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }

        if products.isEmpty {
            print("[StoreKit] All retries exhausted — 0 products loaded. Verify that Products.storekit is selected in Scheme > Run > Options > StoreKit Configuration.")
        }
    }

    // MARK: - Purchase

    /// Returns `true` if purchase was successful.
    @MainActor
    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            lastPurchasedProductName = product.displayName
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore Purchases

    @MainActor
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Check Subscription Status

    @MainActor
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var hasLifetime = false
        var activeProduct: Product?
        var renewalState: Product.SubscriptionInfo.RenewalState?
        var expirationDate: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.productType == .autoRenewable,
               StoreKitConstants.subscriptionProductIDs.contains(transaction.productID) {
                hasActiveSubscription = true
                activeProduct = products.first { $0.id == transaction.productID }
                expirationDate = transaction.expirationDate

                if let product = activeProduct,
                   let subscription = product.subscription {
                    let statuses = try? await subscription.status
                    if let status = statuses?.first {
                        renewalState = status.state
                    }
                }
            }

            if transaction.productType == .nonConsumable,
               transaction.productID == StoreKitConstants.proPermanently {
                hasLifetime = true
            }
        }

        isLifetimeVIP = hasLifetime
        isPro = hasActiveSubscription || hasLifetime || isUnlockedByCode
        currentSubscription = activeProduct
        subscriptionStatus = renewalState
        subscriptionExpirationDate = expirationDate
    }

    // MARK: - Secret Code Unlock

    @MainActor
    func tryUnlock(code: String) -> Bool {
        if code == Self.secretCode {
            isUnlockedByCode = true
            isPro = true
            UserDefaults.standard.set(true, forKey: Self.unlockCodeKey)
            return true
        }
        return false
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }
                await transaction.finish()
                await self.updateSubscriptionStatus()
            }
        }
    }

    // MARK: - Helpers

    var subscriptionProducts: [Product] {
        products.filter { $0.type == .autoRenewable }
    }

    var lifetimeProduct: Product? {
        products.first { $0.id == StoreKitConstants.proPermanently }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
