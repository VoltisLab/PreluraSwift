import Foundation

/// Persists the last successful in-app notifications feed per signed-in user (offline-first paint + faster return visits).
enum InAppNotificationsCache {
    private static let storageKeyPrefix = "Wearhouse.InAppNotifications.v1."

    private static func key(forAccount accountKey: String) -> String {
        storageKeyPrefix + accountKey.lowercased()
    }

    /// Stable key: signed-in username (matches profile); no cache when unknown to avoid cross-user bleed.
    static func accountKey(username: String?) -> String? {
        if let u = username?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
            return u
        }
        return nil
    }

    static func load(accountKey: String) -> [AppNotification]? {
        let key = Self.key(forAccount: accountKey)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .millisecondsSince1970
        return try? dec.decode([AppNotification].self, from: data)
    }

    static func save(_ notifications: [AppNotification], accountKey: String) {
        let key = Self.key(forAccount: accountKey)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? enc.encode(notifications) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear(accountKey: String) {
        UserDefaults.standard.removeObject(forKey: Self.key(forAccount: accountKey))
    }
}

// MARK: - Locally opened / read notification ids (survives list dismiss + API lag)

/// UserDefaults-backed set of notification **string ids** the user has opened on this device. Merged after every fetch/cache load so rows stay “read” even when the server still returns `isRead: false` (e.g. non-numeric ids or delayed persistence).
enum BellLocallyReadNotificationIds {
    private static let storageKeyPrefix = "Wearhouse.BellLocallyReadIds.v1."
    private static let maxStoredIds = 4000

    private static func key(forAccount accountKey: String) -> String {
        storageKeyPrefix + accountKey.lowercased()
    }

    static func record(accountKey: String, notificationId: String) {
        let trimmed = notificationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var ids = loadIds(accountKey: accountKey)
        if ids.contains(trimmed) { return }
        ids.append(trimmed)
        if ids.count > maxStoredIds {
            ids = Array(ids.suffix(maxStoredIds))
        }
        saveIds(accountKey: accountKey, ids: ids)
    }

    /// After bulk server mark-read, remember ids so the next cold paint matches until the feed reflects reads.
    static func recordMany(accountKey: String, notificationIds: [String]) {
        for raw in notificationIds {
            record(accountKey: accountKey, notificationId: raw)
        }
    }

    static func mergedWithLocalReadState(accountKey: String, notifications: [AppNotification]) -> [AppNotification] {
        let read = Set(loadIds(accountKey: accountKey))
        guard !read.isEmpty else { return notifications }
        return notifications.map { n in
            read.contains(n.id) ? n.withIsRead(true) : n
        }
    }

    private static func loadIds(accountKey: String) -> [String] {
        guard let arr = UserDefaults.standard.array(forKey: key(forAccount: accountKey)) as? [String] else { return [] }
        return arr
    }

    private static func saveIds(accountKey: String, ids: [String]) {
        UserDefaults.standard.set(ids, forKey: key(forAccount: accountKey))
    }
}
