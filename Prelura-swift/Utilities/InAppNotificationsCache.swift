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
