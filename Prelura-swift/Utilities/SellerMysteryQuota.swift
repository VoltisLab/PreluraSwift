import Foundation

/// Local + profile-backed seller tier for mystery box listing limits (server enforcement may follow).
enum WearhouseLocalSellerPlan: String {
    case silver
    case gold
}

enum SellerPlanUserDefaults {
    static let planTierKey = "wearhouse_seller_plan_tier"
    static let unlimitedMysteryKey = "wearhouse_unlimited_mystery_subscription"
    /// Legacy key for locally persisted renewal (removed); strip on Silver so stale values never linger.
    private static let legacyGoldNextRenewalKey = "wearhouse_gold_next_renewal_date"

    static var localPlan: WearhouseLocalSellerPlan {
        get {
            let raw = UserDefaults.standard.string(forKey: planTierKey) ?? WearhouseLocalSellerPlan.silver.rawValue
            return WearhouseLocalSellerPlan(rawValue: raw) ?? .silver
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: planTierKey)
            if newValue == .silver {
                UserDefaults.standard.removeObject(forKey: legacyGoldNextRenewalKey)
            }
            NotificationCenter.default.post(name: .wearhouseSellerPlanDidChange, object: nil)
        }
    }

    static var unlimitedMysterySubscribed: Bool {
        get { UserDefaults.standard.bool(forKey: unlimitedMysteryKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: unlimitedMysteryKey)
            NotificationCenter.default.post(name: .wearhouseSellerPlanDidChange, object: nil)
        }
    }
}

enum SellerMysteryQuota {
    /// Backend `profileTier` (e.g. PRO / ELITE) counts as Gold for mystery limits.
    static func apiProfileIndicatesGoldTier(_ profileTier: String) -> Bool {
        let t = profileTier.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return t == "PRO" || t == "ELITE"
    }

    /// Maximum **active** mystery box listings allowed. `nil` means unlimited.
    static func mysteryListingCap(profileTier: String?) -> Int? {
        if SellerPlanUserDefaults.unlimitedMysterySubscribed { return nil }
        let tier = profileTier ?? ""
        if apiProfileIndicatesGoldTier(tier) { return 5 }
        if SellerPlanUserDefaults.localPlan == .gold { return 5 }
        return 1
    }

    static func activeMysteryListingCount(from items: [Item]) -> Int {
        items.filter { $0.isMysteryBox && $0.status.uppercased() == "ACTIVE" }.count
    }

    /// Same rules as the Sell toolbar mystery gate: `false` when the user is at/over their plan’s active mystery cap.
    /// On network failure returns `true` so we do not block listing (matches prior `openMysteryPickerIfAllowed` catch path).
    @MainActor
    static func mysteryPickerEntryAllowed(authToken: String?) async -> Bool {
        let svc = UserService()
        svc.updateAuthToken(authToken)
        do {
            let user = try await svc.getUser(username: nil)
            let products = try await svc.getUserProducts(username: nil)
            let count = activeMysteryListingCount(from: products)
            if let cap = mysteryListingCap(profileTier: user.profileTier), count >= cap {
                return false
            }
            return true
        } catch {
            return true
        }
    }
}
