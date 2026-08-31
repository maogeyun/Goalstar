import Foundation
import StoreKit

enum StoreKitPurchaseOutcome: Equatable {
    case success
    case cancelled
    case pending
    case notFound
    case failed(String)
}

/// StoreKit 2 source of truth for lifetime Pro. Does not persist entitlement to UserDefaults.
@MainActor
final class StoreKitManager {
    static let shared = StoreKitManager()

    private(set) var product: Product?
    private(set) var hasLifetimePro = false
    private(set) var isLoadingProduct = false
    private(set) var isPurchasing = false

    var onEntitlementChange: (() -> Void)?

    private var updatesTask: Task<Void, Never>?

    func start() {
        guard updatesTask == nil else {
            Task { await refresh() }
            return
        }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        await loadProduct()
        await refreshEntitlements()
    }

    func loadProduct() async {
        isLoadingProduct = true
        onEntitlementChange?()
        defer {
            isLoadingProduct = false
            onEntitlementChange?()
        }
        do {
            let products = try await Product.products(for: [AppConstants.proLifetimeProductID])
            product = products.first
        } catch {
            product = nil
            #if DEBUG
            print("[StoreKit] load product failed: \(error)")
            #endif
        }
    }

    func purchase() async -> StoreKitPurchaseOutcome {
        if hasLifetimePro { return .success }
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            return .failed("暂时无法获取商品信息，请稍后重试")
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return hasLifetimePro ? .success : .failed("购买已完成，但未检测到 Pro 权益")
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("未知的购买结果")
            }
        } catch {
            return .failed(readableMessage(for: error))
        }
    }

    func restore() async -> StoreKitPurchaseOutcome {
        do {
            try await StoreKit.AppStore.sync()
        } catch {
            if isUserCancellation(error) {
                return .cancelled
            }
            return .failed(readableMessage(for: error))
        }
        await refreshEntitlements()
        return hasLifetimePro ? .success : .notFound
    }

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == AppConstants.proLifetimeProductID,
               transaction.revocationDate == nil {
                entitled = true
                break
            }
        }
        hasLifetimePro = entitled
        onEntitlementChange?()
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(transactionResult)
            await transaction.finish()
            await refreshEntitlements()
        } catch {
            #if DEBUG
            print("[StoreKit] unverified transaction: \(error)")
            #endif
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let storeKitError = error as? StoreKitError {
            if case .userCancelled = storeKitError { return true }
        }
        return false
    }

    private func readableMessage(for error: Error) -> String {
        if let storeKitError = error as? StoreKitError {
            return storeKitError.localizedDescription
        }
        return error.localizedDescription
    }
}
