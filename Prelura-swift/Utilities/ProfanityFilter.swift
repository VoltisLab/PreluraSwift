import Foundation

/// Client-side profanity masking for user-generated text (chat, listings, bios, reports, lookbook captions).
/// Whole-word / phrase matching is case-insensitive; obfuscated spellings are not detected.
enum ProfanityFilter {
    /// True when trimming `text` is non-empty and sanitization would change the string (profanity was present).
    static func maskingWouldChange(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        return t != sanitize(t)
    }

    /// Replaces blocked words and phrases with `replacement` (default asterisks).
    static func sanitize(_ text: String, replacement: String = "***") -> String {
        guard !text.isEmpty else { return text }
        var result = text
        for phrase in multiWordPhrases {
            guard let regex = phraseRegex(phrase) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
        }
        for term in singleWordTerms {
            let escaped = NSRegularExpression.escapedPattern(for: term)
            let pattern = "(?i)\\b\(escaped)\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
        }
        return result
    }

    private static func phraseRegex(_ phrase: String) -> NSRegularExpression? {
        let parts = phrase.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }
        guard !parts.isEmpty else { return nil }
        let core = parts.joined(separator: "\\s+")
        let pattern = "(?i)(?<![\\p{L}\\p{N}_])\(core)(?![\\p{L}\\p{N}_])"
        return try? NSRegularExpression(pattern: pattern, options: [])
    }

    /// Longer phrases first (handled in order).
    private static let multiWordPhrases: [String] = [
        "son of a bitch",
        "son of a whore",
        "piece of shit",
        "dumb ass",
        "dumb fuck",
        "mother fucker",
        "mother fucking",
        "jack off",
        "jerk off",
        "cock sucker",
        "cluster fuck",
        "shut the fuck up",
        "what the fuck",
        "go fuck yourself",
        "fuck off",
        "fuck you",
        "god damn",
        "goddamn it",
    ]

    private static let singleWordTerms: [String] = [
        "arse", "arsehole", "ass", "asshole", "bastard", "bitch", "bitches", "bollocks", "boner", "bullshit",
        "chink", "clit", "cock", "cocksucker", "coon", "crap", "cum", "cunt", "damn", "dick", "dickhead",
        "dildo", "dyke", "fag", "faggot", "fuck", "fucked", "fucker", "fucking", "fucks", "goddamn",
        "handjob", "hooker", "jizz", "kike", "kys", "lesbo", "nazi", "nigger",
        "nigga", "penis", "piss", "porn", "prick", "pussy", "rape", "rapist", "retard", "scrotum",
        "shit", "shits", "shitty", "slut", "spic", "spick", "spunk", "tard", "tit", "tits", "titties",
        "tranny", "twat", "wank", "wanker", "wetback", "whore", "whores", "wtf",
    ]
}
