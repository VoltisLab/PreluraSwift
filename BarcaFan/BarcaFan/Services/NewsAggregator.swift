import Foundation

enum NewsAggregator {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 45
        config.httpAdditionalHeaders = [
            "User-Agent": "FCBHome/1.0 (iOS RSS)",
            "Accept": "application/rss+xml, application/xml, text/xml, */*",
        ]
        return URLSession(configuration: config)
    }()

    /// Fetches all configured feeds in parallel, merges, dedupes by canonical link, sorts newest first.
    static func fetchStories(sources: [RSSFeedSource] = RSSFeedCatalog.all) async -> [NewsStory] {
        await withTaskGroup(of: [NewsStory].self) { group in
            for source in sources {
                group.addTask {
                    await fetchFeed(source)
                }
            }
            var combined: [NewsStory] = []
            for await batch in group {
                combined.append(contentsOf: batch)
            }
            return dedupeAndSort(combined)
        }
    }

    private static func fetchFeed(_ source: RSSFeedSource) async -> [NewsStory] {
        do {
            let (data, response) = try await session.data(from: source.feedURL)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return []
            }
            let items = RSSFeedParser.parse(data: data, source: source)
            return items.compactMap { mapToStory($0) }
        } catch {
            return []
        }
    }

    private static func mapToStory(_ item: RSSParsedItem) -> NewsStory? {
        guard let linkURL = URL(string: item.linkString) else { return nil }
        let id = canonicalStoryID(guid: item.guidString, link: linkURL)
        let fullPlain = HTMLTextExtractor.plainText(from: item.summaryHTML, limit: nil)
        let summary: String = {
            guard fullPlain.count > 320 else { return fullPlain }
            let idx = fullPlain.index(fullPlain.startIndex, offsetBy: 320)
            return String(fullPlain[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }()
        return NewsStory(
            id: id,
            title: item.title.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary,
            fullPlainText: fullPlain,
            sourceName: item.source.displayName,
            tier: item.source.tier,
            publishedAt: item.pubDate ?? .now,
            crossReferenceConfirmed: false,
            imageURL: item.imageURL,
            linkURL: linkURL
        )
    }

    private static func canonicalStoryID(guid: String?, link: URL) -> String {
        if let g = guid?.trimmingCharacters(in: .whitespacesAndNewlines), !g.isEmpty {
            return g
        }
        if let normalized = normalizeURL(link) {
            return normalized
        }
        return link.absoluteString
    }

    private static func normalizeURL(_ url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.fragment = nil
        var items = components.queryItems ?? []
        let stripKeys: Set<String> = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term", "at_medium", "at_campaign"]
        items.removeAll { stripKeys.contains($0.name.lowercased()) }
        components.queryItems = items.isEmpty ? nil : items
        return components.url?.absoluteString.lowercased()
    }

    private static func dedupeAndSort(_ stories: [NewsStory]) -> [NewsStory] {
        var seen: Set<String> = []
        var unique: [NewsStory] = []
        for s in stories.sorted(by: { $0.publishedAt > $1.publishedAt }) {
            let key = normalizeURL(s.linkURL) ?? s.id.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            unique.append(s)
        }
        return unique
    }
}
