import Foundation

/// Fetches the publisher HTML for a story URL and extracts the longest plausible article body (JSON-LD, `<article>`, common CMS wrappers).
enum ArticleFullTextLoader {
    private static let maxDownloadBytes = 2_800_000

    private static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 28
        c.timeoutIntervalForResource = 40
        c.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FCBHome/1.0 Mobile/15E148",
            "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-GB,en;q=0.9,es;q=0.8",
        ]
        return URLSession(configuration: c)
    }()

    private static let cache = NSCache<NSURL, NSString>()

    /// Best-effort full article as plain text (fetches the publisher page, not the RSS snippet).
    static func loadPlainArticle(linkURL: URL) async throws -> String {
        let fetchURL = normalizedArticleURL(linkURL)
        guard let scheme = fetchURL.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            throw ArticleLoadError.badStatus
        }
        let cacheKey = cacheKeyURL(fetchURL)
        if let hit = cache.object(forKey: cacheKey) {
            return hit as String
        }
        var request = URLRequest(url: fetchURL)
        request.cachePolicy = .returnCacheDataElseLoad
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw ArticleLoadError.badStatus
        }
        let capped: Data = data.count > maxDownloadBytes ? data.prefix(maxDownloadBytes) : data
        guard let html = String(data: capped, encoding: .utf8)
            ?? String(data: capped, encoding: .isoLatin1) else {
            throw ArticleLoadError.encoding
        }
        let fragment = extractBestHTMLFragment(from: html) ?? html
        var plain = HTMLTextExtractor.plainText(from: fragment, limit: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if plain.count < 400 {
            let wholePage = HTMLTextExtractor.plainText(from: html, limit: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if wholePage.count > plain.count {
                plain = wholePage
            }
        }
        if plain.count < 120 {
            throw ArticleLoadError.extractionTooShort
        }
        cache.setObject(plain as NSString, forKey: cacheKey)
        return plain
    }

    private static func normalizedArticleURL(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == "http", var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        parts.scheme = "https"
        return parts.url ?? url
    }

    private static func cacheKeyURL(_ url: URL) -> NSURL {
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url as NSURL }
        c.fragment = nil
        var items = c.queryItems ?? []
        let strip = Set(["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term", "at_medium", "at_campaign"])
        items.removeAll { strip.contains($0.name.lowercased()) }
        c.queryItems = items.isEmpty ? nil : items
        return (c.url ?? url) as NSURL
    }

    enum ArticleLoadError: Error {
        case badStatus
        case encoding
        case extractionTooShort
    }

    // MARK: - Extraction

    private static func extractBestHTMLFragment(from html: String) -> String? {
        var candidates: [String] = []
        candidates.append(contentsOf: jsonLDArticleHTML(from: html))
        let scan = html.count > 1_500_000 ? String(html.prefix(1_500_000)) : html
        if let a = extractSingleTagBlock(html: scan, open: "<article", close: "</article>") {
            candidates.append(a)
        }
        if let m = extractSingleTagBlock(html: scan, open: "<main", close: "</main>") {
            candidates.append(m)
        }
        for pattern in mainContentRegexes() {
            if let m = firstRegexCapture(scan, pattern: pattern), m.count > 200 {
                candidates.append(m)
            }
        }
        let best = candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .max(by: { $0.count < $1.count })
        return best
    }

    private static func mainContentRegexes() -> [String] {
        // Common WordPress / newspaper / sports CMS wrappers (case-insensitive dotall).
        let classNeedles = [
            "entry-content", "post-content", "article-content", "article__content", "article__body",
            "story-body", "single__content", "m-detail__body", "post__content", "content__body",
            "c-article__body", "field-body", "wysiwyg", "td-post-content", "mvp-post-content",
        ]
        return classNeedles.map { needle in
            "(?is)<(?:div|section)[^>]+class=\"[^\"]*\(needle)[^\"]*\"[^>]*>([\\s\\S]*?)</(?:div|section)>"
        }
    }

    private static func firstRegexCapture(_ string: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = re.firstMatch(in: string, options: [], range: range), match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: string) else { return nil }
        return String(string[r])
    }

    private static func extractSingleTagBlock(html: String, open: String, close: String) -> String? {
        guard let openRange = html.range(of: open, options: .caseInsensitive) else { return nil }
        let afterOpen = html[openRange.upperBound...]
        guard let gt = afterOpen.firstIndex(of: ">") else { return nil }
        let innerStart = html.index(after: gt)
        guard let closeRange = html.range(of: close, options: .caseInsensitive, range: innerStart ..< html.endIndex) else {
            return nil
        }
        return String(html[innerStart ..< closeRange.lowerBound])
    }

    private static func jsonLDArticleHTML(from html: String) -> [String] {
        guard let re = try? NSRegularExpression(
            pattern: #"(?is)<script[^>]+type=["']application/ld\+json["'][^>]*>(.*?)</script>"#,
            options: []
        ) else { return [] }
        let full = NSRange(html.startIndex..., in: html)
        var out: [String] = []
        re.enumerateMatches(in: html, options: [], range: full) { result, _, _ in
            guard let result, result.numberOfRanges > 1,
                  let r = Range(result.range(at: 1), in: html) else { return }
            let raw = String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = raw.data(using: .utf8) else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) else { return }
            var bodies: [String] = []
            collectArticleBodies(json, into: &bodies)
            out.append(contentsOf: bodies)
        }
        return out
    }

    private static func collectArticleBodies(_ json: Any, into out: inout [String]) {
        switch json {
        case let dict as [String: Any]:
            if let s = dict["articleBody"] as? String {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.count > 80 { out.append(t) }
            } else if let parts = dict["articleBody"] as? [String] {
                let joined = parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if joined.count > 80 { out.append(joined) }
            }
            if let s = dict["text"] as? String {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.count > 400 { out.append(t) }
            }
            if let g = dict["@graph"] as? [Any] {
                for x in g { collectArticleBodies(x, into: &out) }
            }
            for (_, v) in dict where v is [Any] || v is [String: Any] {
                collectArticleBodies(v, into: &out)
            }
        case let arr as [Any]:
            for x in arr { collectArticleBodies(x, into: &out) }
        default:
            break
        }
    }
}
