import Foundation
import StoreKit
import Combine

@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    enum AccessTier: String {
        case free
        case proYearly
        case lifetime

        var isPremium: Bool { self != .free }

        var displayName: String {
            switch self {
            case .free:
                return "Free"
            case .proYearly:
                return "Pro Yearly"
            case .lifetime:
                return "Lifetime"
            }
        }
    }

    enum ImportLimits {
        static let freeMaxAssets = 120
    }

    enum ProductIds {
        static let yearly = "com.tonyv2289.screenshotroll.pro.yearly"
        static let lifetime = "com.tonyv2289.screenshotroll.lifetime"
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var activeTier: AccessTier = .free
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var storeErrorMessage: String?

    var hasPremium: Bool { activeTier.isPremium }
    var freeMaxAssets: Int { ImportLimits.freeMaxAssets }
    var yearlyProduct: Product? { products.first(where: { $0.id == ProductIds.yearly }) }
    var lifetimeProduct: Product? { products.first(where: { $0.id == ProductIds.lifetime }) }

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: [ProductIds.yearly, ProductIds.lifetime])
                .sorted(by: { $0.price < $1.price })
        } catch {
            storeErrorMessage = "Could not load pricing. Please try again."
            Loggers.app.error("Failed to load StoreKit products: \(error.localizedDescription)")
        }
    }

    func refreshEntitlements() async {
        var resolvedTier: AccessTier = .free

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            if transaction.revocationDate != nil { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < Date() { continue }

            switch transaction.productID {
            case ProductIds.lifetime:
                resolvedTier = .lifetime
            case ProductIds.yearly where resolvedTier != .lifetime:
                resolvedTier = .proYearly
            default:
                break
            }
        }

        activeTier = resolvedTier
    }

    func purchaseYearly() async -> Bool {
        guard let product = yearlyProduct else { return false }
        return await purchase(product)
    }

    func purchaseLifetime() async -> Bool {
        guard let product = lifetimeProduct else { return false }
        return await purchase(product)
    }

    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        storeErrorMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    storeErrorMessage = "Purchase could not be verified."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .pending:
                storeErrorMessage = "Purchase is pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                storeErrorMessage = "Purchase failed. Please try again."
                return false
            }
        } catch {
            storeErrorMessage = "Purchase failed. Please try again."
            Loggers.app.error("Store purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            storeErrorMessage = "Could not restore purchases."
            Loggers.app.error("Restore purchases failed: \(error.localizedDescription)")
        }
    }

    func allowedImportCount(requested: Int, currentCount: Int) -> Int {
        guard requested > 0 else { return 0 }
        if hasPremium { return requested }
        let remaining = max(0, freeMaxAssets - currentCount)
        return min(requested, remaining)
    }

    func remainingFreeSlots(currentCount: Int) -> Int {
        guard !hasPremium else { return .max }
        return max(0, freeMaxAssets - currentCount)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }
}
