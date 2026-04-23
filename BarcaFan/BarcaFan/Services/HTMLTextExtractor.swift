import Foundation

/// RSS / article HTML → plain text (shared by feed parsing and full-page article load).
enum HTMLTextExtractor {
    /// Strips tags, decodes entities, collapses whitespace. When `limit` is nil, returns the full string.
    nonisolated static func plainText(from html: String, limit: Int?) -> String {
        var text = RSSFeedParser.stripCDATAWrappers(html)
        text = text
            .replacingOccurrences(of: "(?s)<script.*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?s)<style.*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?s)<noscript.*?</noscript>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?s)<svg.*?</svg>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = decodeHTMLEntities(text)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\\s*(Leer más|Read more)\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let limit, text.count > limit else { return text }
        let idx = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    nonisolated private static func decodeHTMLEntities(_ string: String) -> String {
        var text = string
        let named: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&lt;", "<"), ("&gt;", ">"),
            ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"), ("&lsquo;", "\u{2018}"), ("&rsquo;", "\u{2019}"),
            ("&hellip;", "…"), ("&mdash;", "-"), ("&ndash;", "-"), ("&bull;", "•"),
        ]
        for (k, v) in named { text = text.replacingOccurrences(of: k, with: v) }
        return decodeNumericHTMLEntities(text)
    }

    nonisolated private static func decodeNumericHTMLEntities(_ string: String) -> String {
        var out = ""
        var i = string.startIndex
        while i < string.endIndex {
            if string[i] == "&", string.index(after: i) < string.endIndex, string[string.index(after: i)] == "#" {
                var j = string.index(i, offsetBy: 2)
                var radix = 10
                if j < string.endIndex, string[j] == "x" || string[j] == "X" {
                    radix = 16
                    j = string.index(after: j)
                }
                let digitsStart = j
                while j < string.endIndex, string[j] != ";" {
                    let ch = string[j]
                    if radix == 16 {
                        guard ch.isHexDigit else { break }
                    } else {
                        guard ch.isNumber else { break }
                    }
                    j = string.index(after: j)
                }
                if j < string.endIndex, string[j] == ";", digitsStart < j {
                    let numStr = String(string[digitsStart..<j])
                    if let value = UInt32(numStr, radix: radix), let scalar = UnicodeScalar(value) {
                        out.append(String(Character(scalar)))
                        i = string.index(after: j)
                        continue
                    }
                }
            }
            out.append(string[i])
            i = string.index(after: i)
        }
        return out
    }
}
