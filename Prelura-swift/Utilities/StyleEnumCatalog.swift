import Foundation

/// Backend `StyleEnum` values and normalization (shared by sell form, product mapping, and detail display).
enum StyleEnumCatalog {
    static let rawValues: [String] = [
        "WORKWEAR", "WORKOUT", "CASUAL", "PARTY_DRESS", "PARTY_OUTFIT", "FORMAL_WEAR", "EVENING_WEAR",
        "WEDDING_GUEST", "LOUNGEWEAR", "VACATION_RESORT_WEAR", "FESTIVAL_WEAR", "ACTIVEWEAR", "NIGHTWEAR",
        "VINTAGE", "Y2K", "BOHO", "MINIMALIST", "GRUNGE", "CHIC", "STREETWEAR", "PREPPY", "RETRO",
        "COTTAGECORE", "GLAM", "SUMMER_STYLES", "WINTER_ESSENTIALS", "SPRING_FLORALS", "AUTUMN_LAYERS",
        "RAINY_DAY_WEAR", "DENIM_JEANS", "DRESSES_GOWNS", "JACKETS_COATS", "KNITWEAR_SWEATERS",
        "SKIRTS_SHORTS", "SUITS_BLAZERS", "TOPS_BLOUSES", "SHOES_FOOTWEAR", "TRAVEL_FRIENDLY",
        "MATERNITY_WEAR", "ATHLEISURE", "ECO_FRIENDLY", "FESTIVAL_READY", "DATE_NIGHT", "ETHNIC_WEAR",
        "OFFICE_PARTY_OUTFIT", "COCKTAIL_ATTIRE", "PROM_DRESSES", "MUSIC_CONCERT_WEAR", "OVERSIZED",
        "SLIM_FIT", "RELAXED_FIT", "CHRISTMAS", "SCHOOL_UNIFORMS"
    ]

    static func displayName(for rawValue: String) -> String {
        let lower = rawValue.replacingOccurrences(of: "_", with: " ").lowercased()
        guard !lower.isEmpty else { return rawValue }
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    /// Maps stored / API / human strings to canonical enum raw, or nil.
    static func resolvedRaw(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if rawValues.contains(t) { return t }
        let upperUnderscore = t.uppercased().replacingOccurrences(of: " ", with: "_")
        if rawValues.contains(upperUnderscore) { return upperUnderscore }
        for raw in rawValues {
            if raw.caseInsensitiveCompare(t) == .orderedSame { return raw }
            if displayName(for: raw).caseInsensitiveCompare(t) == .orderedSame { return raw }
        }
        return nil
    }

    /// Dedupes by canonical raw, preserves order. `maxCount` limits how many are kept (nil = keep all).
    static func normalizedUnique(_ values: [String], maxCount: Int? = nil) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for v in values {
            guard let raw = resolvedRaw(v), !seen.contains(raw) else { continue }
            seen.insert(raw)
            out.append(raw)
            if let m = maxCount, out.count >= m { break }
        }
        return out
    }
}
