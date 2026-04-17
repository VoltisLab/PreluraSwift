import Foundation

/// Client-side cap for **new** listings created with `scheduledPublishAt` (server may add its own limits later).
/// Billing periods are month-sized intervals anchored to the first persisted anchor for this account on this device.
/// When App Store subscription start is exposed on `viewMe`, prefer that as the anchor instead of `ensureBillingAnchorIfUnset`.
enum SellerScheduledListingQuota {
    private static let anchorPrefix = "wearhouse_scheduled_listing_billing_anchor_"
    private static let eventsPrefix = "wearhouse_scheduled_listing_events_"

    /// Same Gold detection as mystery caps (staff tier + local preview).
    static func isGoldTier(profileTier: String) -> Bool {
        SellerMysteryQuota.apiProfileIndicatesGoldTier(profileTier) || SellerPlanUserDefaults.localPlan == .gold
    }

    static func monthlyScheduledListingCap(profileTier: String) -> Int {
        isGoldTier(profileTier: profileTier) ? 50 : 5
    }

    static func stableUserKey(from user: User) -> String {
        if let id = user.userId { return "uid:\(id)" }
        let u = user.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return u.isEmpty ? "anon" : "user:\(u)"
    }

    private static func anchorKey(userKey: String) -> String { anchorPrefix + userKey }
    private static func eventsKey(userKey: String) -> String { eventsPrefix + userKey }

    /// Persists a billing anchor (start of local day) the first time we need one for this user key.
    static func ensureBillingAnchorIfUnset(userKey: String, now: Date = Date(), calendar: Calendar = .current) {
        let key = anchorKey(userKey: userKey)
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        let start = calendar.startOfDay(for: now)
        UserDefaults.standard.set(start.timeIntervalSince1970, forKey: key)
    }

    private static func loadAnchor(userKey: String) -> Date? {
        let key = anchorKey(userKey: userKey)
        guard let t = UserDefaults.standard.object(forKey: key) as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    /// Start of the billing period that contains `asOf` (inclusive), using month steps from the anchor.
    static func billingPeriodStart(anchor: Date, asOf: Date, calendar: Calendar = .current) -> Date {
        let anchorStart = calendar.startOfDay(for: anchor)
        let asOfDay = calendar.startOfDay(for: asOf)
        if asOfDay < anchorStart { return anchorStart }
        var start = anchorStart
        while let next = calendar.date(byAdding: .month, value: 1, to: start), next <= asOfDay {
            start = next
        }
        return start
    }

    private static func billingPeriodEnd(periodStart: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart.addingTimeInterval(86400 * 31)
    }

    private static func loadEventTimestamps(userKey: String) -> [TimeInterval] {
        let key = eventsKey(userKey: userKey)
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TimeInterval].self, from: data) else { return [] }
        return decoded
    }

    private static func saveEventTimestamps(_ values: [TimeInterval], userKey: String) {
        let key = eventsKey(userKey: userKey)
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Counts scheduled listing creations recorded in the current billing month window.
    static func scheduledCreationsInCurrentPeriod(userKey: String, profileTier: String, now: Date = Date(), calendar: Calendar = .current) -> Int {
        ensureBillingAnchorIfUnset(userKey: userKey, now: now, calendar: calendar)
        guard let anchor = loadAnchor(userKey: userKey) else { return 0 }
        let periodStart = billingPeriodStart(anchor: anchor, asOf: now, calendar: calendar)
        let periodEnd = billingPeriodEnd(periodStart: periodStart, calendar: calendar)
        let stamps = loadEventTimestamps(userKey: userKey).map { Date(timeIntervalSince1970: $0) }
        return stamps.filter { $0 >= periodStart && $0 < periodEnd }.count
    }

    static func assertCanCreateScheduledListing(userKey: String, profileTier: String, now: Date = Date()) throws {
        let cap = monthlyScheduledListingCap(profileTier: profileTier)
        let used = scheduledCreationsInCurrentPeriod(userKey: userKey, profileTier: profileTier, now: now)
        guard used < cap else {
            throw NSError(
                domain: "SellerScheduledListingQuota",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L10n.string("You've reached your scheduled listing limit for this billing period. Gold allows more each month. Open Settings → Plan to upgrade.")]
            )
        }
    }

    /// Call after a successful `createProduct` when `scheduledPublishAt` was set.
    static func recordScheduledListingCreation(userKey: String, at: Date = Date()) {
        ensureBillingAnchorIfUnset(userKey: userKey, now: at)
        var all = loadEventTimestamps(userKey: userKey)
        all.append(at.timeIntervalSince1970)
        // Prune very old marks (keep ~18 months) to bound UserDefaults size.
        let cutoff = at.addingTimeInterval(-86400 * 550)
        all = all.filter { Date(timeIntervalSince1970: $0) >= cutoff }
        saveEventTimestamps(all, userKey: userKey)
    }
}
