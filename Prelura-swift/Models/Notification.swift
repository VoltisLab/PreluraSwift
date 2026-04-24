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
    /// From GraphQL: listing JPEG for this row; omit when `relatedProductIsMysteryBox` (client uses animated tile only).
    let productThumbnailUrl: String?
    /// When true, row uses `MysteryBoxAnimatedMediaView` only-do not load `productThumbnailUrl` as an image.
    let relatedProductIsMysteryBox: Bool?

    struct NotificationSender: Codable {
        let username: String?
        let profilePictureUrl: String?
        let thumbnailUrl: String?
    }
}

extension AppNotification {
    /// Integer id for `readNotifications` / `deleteNotification` when the GraphQL schema expects `[Int]` (numeric string or leading digit run).
    var bellNotificationDatabaseIntId: Int? {
        let t = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if let v = Int(t) { return v }
        let digits = t.prefix { $0.isNumber }
        guard !digits.isEmpty, let v = Int(String(digits)) else { return nil }
        return v
    }

    /// Looks up a meta value by key name (case-insensitive).
    func metaValue(caseInsensitiveKey key: String) -> String? {
        guard let meta = meta else { return nil }
        let lk = key.lowercased()
        for (k, v) in meta where k.lowercased() == lk {
            return v
        }
        return nil
    }

    /// Chat / DM rows (new message, reactions) stay out of the bell list until they are unread this long. Matches `origin/main`.
    private static let chatNotificationMinAgeToShow: TimeInterval = 30 * 60

    /// Matches `model_group == "Chat"` from the backend (message + reaction pushes).
    var isChatCentricNotification: Bool {
        (modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Chat") == .orderedSame
    }

    /// Bell list + notification detail: hide read chat; defer **fresh** unread chat by `chatNotificationMinAgeToShow` (inbox has the real-time list). Matches `origin/main` / production Flutter.
    func shouldShowOnNotificationsPage(referenceDate: Date = Date()) -> Bool {
        guard isChatCentricNotification else { return true }
        if isRead { return false }
        guard let created = createdAt else { return true }
        return referenceDate.timeIntervalSince(created) >= Self.chatNotificationMinAgeToShow
    }

    var shouldCountTowardBellBadge: Bool {
        shouldShowOnNotificationsPage() && !isRead
    }

    /// Same row with an updated read flag (list optimistic updates / mark-read batch).
    func withIsRead(_ read: Bool) -> AppNotification {
        AppNotification(
            id: id,
            sender: sender,
            message: message,
            model: model,
            modelId: modelId,
            modelGroup: modelGroup,
            isRead: read,
            createdAt: createdAt,
            meta: meta,
            productThumbnailUrl: productThumbnailUrl,
            relatedProductIsMysteryBox: relatedProductIsMysteryBox
        )
    }

    /// Lookbook-specific rows. **Conservative:** only the backend’s lookbook `modelGroup` or explicit lookbook id fields in meta.
    /// Message/URL heuristics (word “lookbook” in text or CDN paths) were classifying the majority of General rows as lookbook, emptying the General tab.
    var isLookbookRelatedNotification: Bool {
        let mg = (modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if mg == "lookbook" { return true }
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

// MARK: - Bell thumbnails: meta flags & legacy static mystery JPEG URLs

enum BellNotificationMysteryHelpers {
    /// Heuristic: generated cover or obvious placeholder paths - prefer animated mystery tile, never as a “normal” product JPEG.
    static func isLikelyStaticMysteryOrPlaceholderCoverURL(_ raw: String) -> Bool {
        let l = raw.lowercased()
        if l.contains("mystery") { return true }
        if l.contains("mysterybox") || l.contains("mystery_box") { return true }
        if l.contains("placeholder") || l.contains("default") { return true }
        if l.contains("unapproved") || l.contains("rejected") || l.contains("pending_review") { return true }
        if l.contains("moderation") && (l.contains("image") || l.contains("thumb") || l.contains("listing")) { return true }
        if l.contains("listing_cover") && (l.hasSuffix(".jpg") || l.hasSuffix(".jpeg") || l.contains(".jpeg")) { return true }
        if l.contains("900") && l.contains("1170") { return true }
        // Server-generated mystery placeholder tiles (legacy CDN paths without "mystery" in the filename).
        if l.contains("mystery-cover") || l.contains("mystery_cover") || l.contains("mysterybox-cover") { return true }
        return false
    }
}

extension AppNotification {
    /// When GraphQL `relatedProductIsMysteryBox` is absent, meta may still carry a flag.
    var bellMysteryFromMeta: Bool {
        let keys = [
            "related_product_is_mystery_box", "relatedProductIsMysteryBox",
            "is_mystery_box", "isMysteryBox", "is_mystery", "mystery", "mystery_box",
        ]
        for k in keys {
            let v = metaValue(caseInsensitiveKey: k)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if v == "true" || v == "1" || v == "yes" { return true }
        }
        return false
    }
}

// MARK: - Bell list: product id resolution

extension AppNotification {
    /// Numeric product id from flat meta (orders, offers, chat context when the server includes it).
    var bellProductIdFromMeta: Int? {
        guard let meta = meta else { return nil }
        let keys = [
            "sold_product_id", "product_id", "productId", "listing_id", "listingId",
            "item_id", "itemId", "related_product_id", "relatedProductId",
            "order_product_id", "orderProductId", "line_item_product_id", "lineItemProductId",
            "primary_product_id", "primaryProductId", "soldProductId", "listingProductId",
            "conversation_product_id", "conversationProductId", "thread_product_id", "threadProductId",
        ]
        let lowerIndex: [String: String] = Dictionary(uniqueKeysWithValues: meta.map { ($0.key.lowercased(), $0.value) })
        for k in keys {
            let raw = (meta[k] ?? lowerIndex[k.lowercased()])?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let raw, !raw.isEmpty else { continue }
            if let v = Int(raw), v > 0 { return v }
        }
        return nil
    }

    /// When `model` / `model_group` point at a listing or offer row, the primary id is often `modelId`.
    func bellModelBackedProductId(modelGroupLowercased: String) -> Int? {
        guard let midRaw = modelId?.trimmingCharacters(in: .whitespacesAndNewlines), !midRaw.isEmpty,
              let v = Int(midRaw), v > 0 else { return nil }
        let modelLower = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if modelLower == "product" || modelLower == "offer" { return v }
        if modelLower.isEmpty, (modelGroupLowercased == "offer" || modelGroupLowercased == "product") { return v }
        return nil
    }

    /// Stable conversation id for chat / DM bell rows (server may use snake or camel case).
    var bellConversationIdFromMeta: String? {
        let raw = metaValue(caseInsensitiveKey: "conversation_id")
            ?? metaValue(caseInsensitiveKey: "conversationId")
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }

    /// When the row is order-scoped (`modelId` is often an **order** id, not a product id), used to load line-item art from `userOrders` (seller) so thumbnails work even when `product()` omits images for sold listings.
    var bellOrderIdForNotificationThumbnail: Int? {
        for k in ["order_id", "orderId", "related_order_id", "relatedOrderId"] {
            if let raw = metaValue(caseInsensitiveKey: k)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let v = Int(raw), v > 0 { return v }
        }
        let mg = (modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if mg == "order" || m == "order" {
            if let mid = modelId?.trimmingCharacters(in: .whitespacesAndNewlines), let v = Int(mid), v > 0 { return v }
        }
        return nil
    }
}
