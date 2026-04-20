import Foundation

/// Bell list + foreground push: show **usernames in lowercase** (avoids title-case / server casing like `Alex`).
enum NotificationUsernameDisplay {
    static func canonicalUsernameForDisplay(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return t }
        let withoutAt = t.hasPrefix("@") ? String(t.dropFirst()) : t
        return withoutAt.lowercased()
    }

    /// If `fullText` starts with `username` (case-insensitive), replace that prefix with the canonical lowercase form.
    static func replacingLeadingUsername(fullText: String, username rawUsername: String) -> String {
        let username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return fullText }
        let canonical = canonicalUsernameForDisplay(username)
        guard !fullText.isEmpty else { return fullText }
        let lu = username.lowercased()
        let lt = fullText.lowercased()
        guard lt.hasPrefix(lu) else { return fullText }
        guard fullText.count >= username.count else { return fullText }
        let prefix = String(fullText.prefix(username.count))
        guard prefix.lowercased() == lu else { return fullText }
        let suffix = fullText.dropFirst(username.count)
        return canonical + suffix
    }
}
