import CryptoKit
import Foundation

/// Client-side login throttling guard.
///
/// This does not replace backend enforcement. It reduces rapid brute-force retries on this device and keeps
/// lock state across app restarts.
enum LoginRateLimitGuard {
    private static let attemptsByCredentialKey = "wearhouse_login_attempts_by_credential_v1"
    private static let attemptsByAccountKey = "wearhouse_login_attempts_by_account_v1"
    private static let strikesByAccountKey = "wearhouse_login_strikes_by_account_v1"
    private static let lockoutsByAccountKey = "wearhouse_login_lockouts_by_account_v1"
    private static let windowSeconds: TimeInterval = 60
    private static let maxAttemptsPerWindow = 5

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    /// Used as local pepper for credential fingerprinting.
    static func credentialFingerprint(username: String, password: String, deviceInstallId: String) -> String {
        let raw = "\(normalizedAccount(username))|\(password)|\(deviceInstallId)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func activeLockRemainingSeconds(for username: String, now: Date = Date()) -> TimeInterval? {
        let account = normalizedAccount(username)
        guard !account.isEmpty else { return nil }
        let lockouts = loadDateMap(forKey: lockoutsByAccountKey)
        guard let lockUntil = lockouts[account], lockUntil > now else { return nil }
        return max(1, lockUntil.timeIntervalSince(now))
    }

    static func clearStateForSuccessfulLogin(username: String, password: String, deviceInstallId: String) {
        let account = normalizedAccount(username)
        guard !account.isEmpty else { return }
        let fingerprint = credentialFingerprint(username: username, password: password, deviceInstallId: deviceInstallId)

        var byCredential = loadTimestampMap(forKey: attemptsByCredentialKey)
        byCredential.removeValue(forKey: fingerprint)
        saveTimestampMap(byCredential, forKey: attemptsByCredentialKey)

        var byAccount = loadTimestampMap(forKey: attemptsByAccountKey)
        byAccount.removeValue(forKey: account)
        saveTimestampMap(byAccount, forKey: attemptsByAccountKey)

        var strikes = loadIntMap(forKey: strikesByAccountKey)
        strikes.removeValue(forKey: account)
        saveIntMap(strikes, forKey: strikesByAccountKey)

        var lockouts = loadDateMap(forKey: lockoutsByAccountKey)
        lockouts.removeValue(forKey: account)
        saveDateMap(lockouts, forKey: lockoutsByAccountKey)
    }

    /// Records a failed attempt and returns lockout seconds when this failure triggers (or extends) lockout.
    @discardableResult
    static func registerFailedAttempt(username: String, password: String, deviceInstallId: String, now: Date = Date()) -> TimeInterval? {
        let account = normalizedAccount(username)
        guard !account.isEmpty else { return nil }
        let fingerprint = credentialFingerprint(username: username, password: password, deviceInstallId: deviceInstallId)

        var byCredential = loadTimestampMap(forKey: attemptsByCredentialKey)
        var byAccount = loadTimestampMap(forKey: attemptsByAccountKey)
        var strikes = loadIntMap(forKey: strikesByAccountKey)
        var lockouts = loadDateMap(forKey: lockoutsByAccountKey)

        let windowStart = now.addingTimeInterval(-windowSeconds)

        var credentialAttempts = (byCredential[fingerprint] ?? []).filter { $0 >= windowStart }
        var accountAttempts = (byAccount[account] ?? []).filter { $0 >= windowStart }
        credentialAttempts.append(now)
        accountAttempts.append(now)
        byCredential[fingerprint] = credentialAttempts
        byAccount[account] = accountAttempts

        let exceeded = credentialAttempts.count > maxAttemptsPerWindow || accountAttempts.count > maxAttemptsPerWindow
        var remaining: TimeInterval?
        if exceeded {
            let nextStrike = (strikes[account] ?? 0) + 1
            strikes[account] = nextStrike
            // Enforce a strong minimum lock, then escalate per repeated bursts: 30m, 60m, 120m, 240m (max).
            let lockMinutes = min(240, 30 * Int(pow(2.0, Double(max(0, nextStrike - 1)))))
            let newLock = now.addingTimeInterval(TimeInterval(lockMinutes * 60))
            let currentLock = lockouts[account] ?? .distantPast
            let effectiveLock = max(currentLock, newLock)
            lockouts[account] = effectiveLock
            remaining = max(1, effectiveLock.timeIntervalSince(now))
            // Fresh window after lock trigger so users don't instantly stack multiple strikes on one tap burst.
            byCredential[fingerprint] = []
            byAccount[account] = []
        }

        saveTimestampMap(byCredential, forKey: attemptsByCredentialKey)
        saveTimestampMap(byAccount, forKey: attemptsByAccountKey)
        saveIntMap(strikes, forKey: strikesByAccountKey)
        saveDateMap(lockouts, forKey: lockoutsByAccountKey)

        return remaining
    }

    private static func normalizedAccount(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func loadTimestampMap(forKey key: String) -> [String: [Date]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? decoder.decode([String: [Date]].self, from: data) else { return [:] }
        return decoded
    }

    private static func saveTimestampMap(_ value: [String: [Date]], forKey key: String) {
        if let data = try? encoder.encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadIntMap(forKey key: String) -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? decoder.decode([String: Int].self, from: data) else { return [:] }
        return decoded
    }

    private static func saveIntMap(_ value: [String: Int], forKey key: String) {
        if let data = try? encoder.encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadDateMap(forKey key: String) -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? decoder.decode([String: Date].self, from: data) else { return [:] }
        return decoded
    }

    private static func saveDateMap(_ value: [String: Date], forKey key: String) {
        if let data = try? encoder.encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
