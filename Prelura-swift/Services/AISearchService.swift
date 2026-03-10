import Foundation
import UIKit

/// Result of parsing a search query for colours, categories, and free text.
/// Used to build API search/filters and to show "closest to" hints.
struct ParsedSearch {
    /// Search string to send to the API (includes colour/category terms for backend to match).
    var searchText: String
    /// Resolved parent category if detected from query (e.g. "Women", "Men").
    var categoryOverride: String?
    /// Colour names we inferred (from app colours or aliases); for hint only if we mapped aliases.
    var appliedColourNames: [String]
    /// When we mapped an alias (e.g. "camo" → "Green"), show this message.
    var closestMatchHint: String?
}

/// Lightweight "learning" search: parses natural language for colours and categories,
/// supports typos (fuzzy match) and maps common colour names to app colours.
/// Backend is not modified; we only produce a search string and optional category.
final class AISearchService {
    
    // MARK: - App vocabulary (same as Sell flow)
    
    static let appColours: [String] = [
        "Black", "White", "Red", "Blue", "Green", "Yellow", "Pink", "Purple",
        "Orange", "Brown", "Grey", "Beige", "Navy", "Maroon", "Teal"
    ]
    
    /// Parent categories (feed filter)
    static let parentCategories: [String] = ["All", "Women", "Men", "Kids", "Toddlers", "Boys", "Girls"]
    
    /// Subcategories (from Category model) for keyword matching
    static let subCategories: [String] = [
        "Clothing", "Clothes", "Shoes", "Footwear", "Accessories", "Electronics",
        "Home", "Beauty", "Books", "Sports"
    ]
    
    /// Map common colour names / aliases to our app colour names.
    /// Expand this over time to "train" the search.
    static let colourAliases: [String: String] = [
        // Greens
        "camo": "Green", "camouflage": "Green", "olive": "Green", "forest": "Green",
        "mint": "Green", "sage": "Green", "lime": "Green", "emerald": "Green",
        "dark green": "Green", "light green": "Green", "army": "Green",
        // Reds / wine
        "wine": "Maroon", "burgundy": "Maroon", "burgundy red": "Maroon",
        "claret": "Maroon", "bordeaux": "Maroon",
        "crimson": "Red", "scarlet": "Red", "dark red": "Maroon", "cherry": "Red",
        // Blues
        "navy": "Navy", "navy blue": "Navy", "midnight": "Navy", "royal blue": "Blue",
        "sky blue": "Blue", "light blue": "Blue", "dark blue": "Navy",
        // Neutrals / browns
        "tan": "Beige", "sand": "Beige", "cream": "Beige", "ivory": "White",
        "charcoal": "Grey", "silver": "Grey", "gray": "Grey", "slate": "Grey",
        "taupe": "Brown", "khaki": "Beige", "mocha": "Brown", "chocolate": "Brown",
        // Pinks / purples
        "magenta": "Pink", "rose": "Pink", "blush": "Pink", "lavender": "Purple",
        "violet": "Purple", "plum": "Purple", "mauve": "Purple",
        // Yellows / oranges
        "gold": "Yellow", "mustard": "Yellow", "amber": "Orange", "coral": "Orange",
        "peach": "Orange", "terracotta": "Orange", "rust": "Orange"
    ]
    
    /// Max Levenshtein distance to consider a typo match (e.g. "gren" → "Green")
    private let maxTypoDistance = 2
    
    /// Minimum length of word to apply fuzzy match (avoid matching "a", "in", etc.)
    private let minLengthForFuzzy = 3
    
    // MARK: - Parse query
    
    /// Parses the raw query: extracts colours (with alias mapping and fuzzy match),
    /// category keywords, and builds a search string. Sets closestMatchHint when an alias was used.
    func parse(query: String) -> ParsedSearch {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ParsedSearch(searchText: "", categoryOverride: nil, appliedColourNames: [], closestMatchHint: nil)
        }
        
        let words = trimmed
            .lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        
        var appliedColours: [String] = []
        var appliedCategory: String? = nil
        var remainingWords: [String] = []
        var usedAlias: (requested: String, mapped: String)? = nil
        
        for word in words {
            // 1) Check colour alias first (multi-word: "dark green", "navy blue" handled via joined later)
            if let mapped = Self.colourAliases[word] {
                appliedColours.append(mapped)
                if usedAlias == nil { usedAlias = (word, mapped) }
                continue
            }
            
            // 2) Exact match on app colour (case-insensitive)
            if let match = Self.appColours.first(where: { $0.lowercased() == word }) {
                appliedColours.append(match)
                remainingWords.append(word)
                continue
            }
            
            // 3) Fuzzy match on app colour (typos)
            if word.count >= minLengthForFuzzy,
               let match = fuzzyMatchColour(word: word) {
                appliedColours.append(match)
                remainingWords.append(word)
                continue
            }
            
            // 4) Parent category
            if let cat = Self.parentCategories.first(where: { $0.lowercased() == word && $0.lowercased() != "all" }) {
                appliedCategory = cat
                remainingWords.append(word)
                continue
            }
            
            // 5) Subcategory
            if Self.subCategories.contains(where: { $0.lowercased() == word }) {
                remainingWords.append(word)
                continue
            }
            
            remainingWords.append(word)
        }
        
        // Build search string: remaining words + colour names (so backend can match in title/description)
        var searchParts = remainingWords
        for c in appliedColours where !searchParts.contains(c.lowercased()) {
            searchParts.append(c)
        }
        let searchText = searchParts.joined(separator: " ")
        
        // Hint when we mapped an alias
        let hint: String?
        if let (req, mapped) = usedAlias, !appliedColours.isEmpty {
            hint = "Showing results closest to \"\(req)\" (\(mapped))"
        } else {
            hint = nil
        }
        
        return ParsedSearch(
            searchText: searchText,
            categoryOverride: appliedCategory,
            appliedColourNames: appliedColours,
            closestMatchHint: hint
        )
    }
    
    /// Fuzzy match a single word against app colours and aliases.
    private func fuzzyMatchColour(word: String) -> String? {
        var best: (colour: String, distance: Int)?
        
        for appColour in Self.appColours {
            let d = Self.levenshtein(word, appColour.lowercased())
            if d <= maxTypoDistance, best == nil || d < best!.distance {
                best = (appColour, d)
            }
        }
        for (alias, appColour) in Self.colourAliases {
            let d = Self.levenshtein(word, alias)
            if d <= maxTypoDistance, best == nil || d < best!.distance {
                best = (appColour, d)
            }
        }
        return best?.colour
    }
    
    /// Levenshtein distance between two strings.
    private static func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        var d = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(d[i-1][j] + 1, d[i][j-1] + 1, d[i-1][j-1] + cost)
            }
        }
        return d[a.count][b.count]
    }
    
    /// Map a colour name (from our app list) to a simple RGB for distance comparison (e.g. for image colour).
    static func rgb(forColourName name: String) -> (r: Double, g: Double, b: Double)? {
        switch name.lowercased() {
        case "black": return (0, 0, 0)
        case "white": return (1, 1, 1)
        case "red": return (1, 0, 0)
        case "blue": return (0, 0, 1)
        case "green": return (0, 0.5, 0)
        case "yellow": return (1, 1, 0)
        case "pink": return (1, 0.75, 0.8)
        case "purple": return (0.5, 0, 0.5)
        case "orange": return (1, 0.5, 0)
        case "brown": return (0.6, 0.4, 0.2)
        case "grey", "gray": return (0.5, 0.5, 0.5)
        case "beige": return (0.96, 0.96, 0.86)
        case "navy": return (0, 0, 0.5)
        case "maroon": return (0.5, 0, 0)
        case "teal": return (0, 0.5, 0.5)
        default: return nil
        }
    }
    
    /// Find the closest app colour name for a given RGB (0–1). Used for image colour detection.
    static func nearestColourName(r: Double, g: Double, b: Double) -> String {
        var best: (name: String, dist: Double) = (Self.appColours[0], .infinity)
        for name in appColours {
            guard let rgb = rgb(forColourName: name) else { continue }
            let dr = r - rgb.r, dg = g - rgb.g, db = b - rgb.b
            let d = dr*dr + dg*dg + db*db
            if d < best.dist { best = (name, d) }
        }
        return best.name
    }
}
