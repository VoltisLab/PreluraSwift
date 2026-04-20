import Foundation

/// In-app notification (matches Flutter NotificationModel / GraphQL NotificationType).
struct AppNotification: Identifiable, Codable {
    let id: String
    let sender: NotificationSender?
    let message: String
    let model: String
    let modelId: String?
    let modelGroup: String?
    let isRead: Bool
    let createdAt: Date?
    let meta: [String: String]?

    struct NotificationSender: Codable {
        let username: String?
        let profilePictureUrl: String?
        let thumbnailUrl: String?
    }
}

extension AppNotification {
    /// Looks up a meta value by key name (case-insensitive). Backend may use `is_mystery_box`, `IsMysteryBox`, etc.
    func metaValue(caseInsensitiveKey key: String) -> String? {
        guard let meta = meta else { return nil }
        let lk = key.lowercased()
        for (k, v) in meta where k.lowercased() == lk {
            return v
        }
        return nil
    }

    /// Chat / DM rows (new message, reactions) stay out of the bell list until they are unread this long.
    private static let chatNotificationMinAgeToShow: TimeInterval = 30 * 60

    /// Matches `model_group == "Chat"` from the backend (message + reaction pushes).
    var isChatCentricNotification: Bool {
        (modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Chat") == .orderedSame
    }

    /// Bell list + notification detail list: hide fresh chat noise; inbox tab holds the unread counter.
    func shouldShowOnNotificationsPage(referenceDate: Date = Date()) -> Bool {
        guard isChatCentricNotification else { return true }
        if isRead { return false }
        guard let created = createdAt else { return true }
        return referenceDate.timeIntervalSince(created) >= Self.chatNotificationMinAgeToShow
    }

    var shouldCountTowardBellBadge: Bool {
        shouldShowOnNotificationsPage() && !isRead
    }

    /// Lookbook-specific rows (feed, likes on looks, lookbook comments, etc.). Used to split the notifications list from general app activity.
    var isLookbookRelatedNotification: Bool {
        let mg = (modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if mg == "lookbook" { return true }
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if m.contains("lookbook") { return true }
        let lookbookMetaKeys: Set<String> = [
            "lookbook_id", "lookbookid", "lookbook_post_id", "lookbookpostid",
            "lookbook_entry_id", "lookbookentryid",
        ]
        guard let meta = meta else { return false }
        for k in meta.keys {
            if lookbookMetaKeys.contains(k.lowercased()) { return true }
        }
        return false
    }
}

// MARK: - Bell list: migrate static mystery listing JPEGs to animated tile

/// Strips legacy `media_thumbnail` URLs that point at generated mystery-box cover JPEGs so rows use `MysteryBoxAnimatedMediaView` instead of a buggy static image.
enum BellNotificationMysteryThumbnailMigration {
    private static let metaImageKeys: Set<String> = [
        "media_thumbnail", "product_image", "product_image_url",
        "thumbnail_url", "thumbnailUrl", "image_url", "imageUrl",
        "product_thumbnail", "media_url", "lookbook_image", "lookbook_thumbnail",
        "thumbnail", "image", "photo_url", "photoUrl", "listing_image", "item_image",
        "listing_image_url", "productImage", "listingImage",
    ]

    /// Returns updated meta (or the original reference) with mystery JPEG URLs cleared and `is_mystery_box` set when appropriate.
    static func migratedMeta(from meta: [String: String]?) -> [String: String]? {
        guard var m = meta, !m.isEmpty else { return meta }
        var stripped = false
        for (k, v) in m {
            let kl = k.lowercased()
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            let looksLikeImageKey = metaImageKeys.contains(kl) || kl.contains("thumb") || kl.contains("image") || kl.contains("photo")
            guard looksLikeImageKey || t.hasPrefix("http") else { continue }
            guard isLikelyStaticMysteryCoverURL(t) else { continue }
            m[k] = ""
            stripped = true
        }
        if stripped {
            let hasFlag = m.keys.contains { $0.caseInsensitiveCompare("is_mystery_box") == .orderedSame }
            if !hasFlag {
                m["is_mystery_box"] = "true"
            }
        }
        return stripped ? m : meta
    }

    /// Heuristic: generated listing cover or obvious mystery asset paths (URLs rarely include the word “mystery”).
    static func isLikelyStaticMysteryCoverURL(_ raw: String) -> Bool {
        let l = raw.lowercased()
        if l.contains("mystery") { return true }
        if l.contains("mysterybox") || l.contains("mystery_box") { return true }
        // Generic backend placeholder/default assets that should never render in the bell feed.
        if l.contains("placeholder") || l.contains("default") { return true }
        // Moderation / placeholder assets that must not replace the in-app mystery animation tile.
        if l.contains("unapproved") || l.contains("rejected") || l.contains("pending_review") { return true }
        if l.contains("moderation") && (l.contains("image") || l.contains("thumb") || l.contains("listing")) { return true }
        // Listing cover upload filenames used when creating mystery listings (see `MysteryBoxListingCoverImage`).
        if l.contains("listing_cover") && (l.hasSuffix(".jpg") || l.hasSuffix(".jpeg") || l.contains(".jpeg")) { return true }
        // Client-generated mystery raster is portrait ~900×1170; some CDNs encode dimensions in the path.
        if l.contains("900") && l.contains("1170") { return true }
        return false
    }
}
