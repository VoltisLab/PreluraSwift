import Foundation

/// Local + profile-backed seller tier for mystery box listing limits (server enforcement may follow).
enum WearhouseLocalSellerPlan: String {
    case silver
    case gold
}

enum SellerPlanUserDefaults {
    static let planTierKey = "wearhouse_seller_plan_tier"
    static let unlimitedMysteryKey = "wearhouse_unlimited_mystery_subscription"

    static var localPlan: WearhouseLocalSellerPlan {
        get {
            let raw = UserDefaults.standard.string(forKey: planTierKey) ?? WearhouseLocalSellerPlan.silver.rawValue
            return WearhouseLocalSellerPlan(rawValue: raw) ?? .silver
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: planTierKey)
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
        return 2
    }

    static func activeMysteryListingCount(from items: [Item]) -> Int {
        items.filter { $0.isMysteryBox && $0.status.uppercased() == "ACTIVE" }.count
    }
}
