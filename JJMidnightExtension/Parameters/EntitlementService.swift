import Foundation
import StoreKit

@MainActor
@Observable
final class EntitlementService {
    static let shared = EntitlementService()

    private(set) var accessState: AccessState
    private(set) var unlockProduct: Product?
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?
    // In-flight work, so callers that overlap — init, the app's first
    // appearance, the panel and the paywall all ask at launch — wait on one
    // StoreKit round-trip instead of each starting their own.
    private var refreshTask: Task<Void, Never>?
    private var productsTask: Task<Void, Never>?

    var isEffectAllowed: Bool { accessState.isEffectAllowed }

    private init() {
        UnlockStore.ensureInstallDate()
        accessState = UnlockStore.computeAccessState(hasUnlock: false)
        UnlockStore.write(accessState: accessState)

        updatesTask = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if let transaction = Self.matchingUnlock(from: result) {
                    await transaction.finish()
                    await self.refresh()
                }
            }
        }
        Task { await refresh() }
        Task { await loadProducts() }
    }

    func refresh() async {
        if let refreshTask { return await refreshTask.value }
        let task = Task {
            let hasUnlock = await hasUnlockEntitlement()
            apply(UnlockStore.computeAccessState(hasUnlock: hasUnlock))
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    func loadProducts() async {
        guard unlockProduct == nil else { return }
        if let productsTask { return await productsTask.value }
        let task = Task {
            isLoadingProducts = true
            defer { isLoadingProducts = false }
            do {
                let products = try await Product.products(for: [PurchaseProducts.unlock])
                unlockProduct = products.first { $0.id == PurchaseProducts.unlock }
                lastError = unlockProduct == nil ? "Unlock product not available yet." : nil
            } catch {
                lastError = error.localizedDescription
            }
        }
        productsTask = task
        await task.value
        productsTask = nil
    }

    func purchaseUnlock() async {
        guard let unlockProduct else {
            lastError = "Unlock is not available yet. Check your connection and try again."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            // Plain purchase() — shared with the AUv3 extension where UIApplication.shared is unavailable.
            let result = try await unlockProduct.purchase()

            switch result {
            case .success(let verification):
                if let transaction = Self.matchingUnlock(from: verification) {
                    await transaction.finish()
                    await refresh()
                    lastError = nil
                }
            case .userCancelled:
                break
            case .pending:
                lastError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refresh()
            if case .unlocked = accessState {
                lastError = nil
            } else {
                lastError = "No purchases found for this Apple ID."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func hasUnlockEntitlement() async -> Bool {
        if let latest = await Transaction.latest(for: PurchaseProducts.unlock),
           Self.matchingUnlock(from: latest) != nil {
            return true
        }
        for await result in Transaction.currentEntitlements {
            if Self.matchingUnlock(from: result) != nil { return true }
        }
        return false
    }

    private func apply(_ state: AccessState) {
        guard state != accessState else { return }
        // Observers watch `accessState` itself; the App Group copy is for the
        // audio unit's render path and for the other process.
        accessState = state
        UnlockStore.write(accessState: state)
    }

    private static func matchingUnlock(
        from result: VerificationResult<StoreKit.Transaction>
    ) -> StoreKit.Transaction? {
        let transaction: StoreKit.Transaction
        switch result {
        case .verified(let t):
            transaction = t
        case .unverified:
            return nil
        }
        guard transaction.productID == PurchaseProducts.unlock else { return nil }
        guard transaction.revocationDate == nil else { return nil }
        return transaction
    }
}
