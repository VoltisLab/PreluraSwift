import Foundation
import StoreKit

/// App Store subscription purchase for seller **Gold** (StoreKit 2). Requires product `Constants.wearhouseGoldMonthlyProductId` in App Store Connect.
enum SellerGoldSubscriptionError: LocalizedError {
    case productUnavailable
    case userCancelled
    case pending
    case unverified(String)
    case backendSyncFailed(Error)

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return L10n.string("Gold subscription isn’t available in App Store Connect for this build yet.")
        case .userCancelled:
            return L10n.string("Purchase was cancelled.")
        case .pending:
            return L10n.string("Purchase is pending approval.")
        case .unverified(let reason):
            return reason
        case .backendSyncFailed(let error):
            return L10n.userFacingError(error)
        }
    }
}

@MainActor
enum SellerGoldSubscriptionService {

    static func loadGoldProduct() async throws -> Product? {
        let ids = [Constants.wearhouseGoldMonthlyProductId]
        let products = try await Product.products(for: ids)
        return products.first
    }

    /// Runs StoreKit purchase, sets local Gold, and posts IAP payload + `sellerGoldRenewsAt` to `updateProfile(meta:)` for the server to echo on `viewMe`.
    static func purchaseGoldMonthly(authToken: String?) async throws {
        guard let product = try await loadGoldProduct() else {
            throw SellerGoldSubscriptionError.productUnavailable
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            do {
                try await syncTransactionToBackend(authToken: authToken, transaction: transaction)
            } catch {
                SellerPlanUserDefaults.localPlan = .gold
                await transaction.finish()
                throw SellerGoldSubscriptionError.backendSyncFailed(error)
            }
            SellerPlanUserDefaults.localPlan = .gold
            await transaction.finish()
        case .userCancelled:
            throw SellerGoldSubscriptionError.userCancelled
        case .pending:
            throw SellerGoldSubscriptionError.pending
        @unknown default:
            throw SellerGoldSubscriptionError.productUnavailable
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw SellerGoldSubscriptionError.unverified(error.localizedDescription)
        case .verified(let safe):
            return safe
        }
    }

    private static func syncTransactionToBackend(authToken: String?, transaction: Transaction) async throws {
        let svc = UserService()
        svc.updateAuthToken(authToken)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let renewalInstant: Date? = transaction.expirationDate
            ?? Calendar.current.date(byAdding: .month, value: 1, to: transaction.purchaseDate)
        var meta: [String: Any] = [
            "wearhouseIosSellerGold": [
                "productId": transaction.productID,
                "transactionId": "\(transaction.id)",
                "purchasedAt": iso.string(from: transaction.purchaseDate),
                "expiresAt": transaction.expirationDate.map { iso.string(from: $0) } ?? "",
            ],
        ]
        if let renewalInstant {
            meta["sellerGoldRenewsAt"] = iso.string(from: renewalInstant)
        }
        try await svc.updateProfile(meta: meta)
    }
}
