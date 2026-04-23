import Foundation

/// Curated RSS endpoints (HTTPS). Tiers follow your editorial model; adjust as you add a club worker.
enum RSSFeedCatalog {
    static let all: [RSSFeedSource] = [
        RSSFeedSource(
            id: "md-barca",
            feedURL: URL(string: "https://www.mundodeportivo.com/rss/futbol/fc-barcelona.xml")!,
            displayName: "Mundo Deportivo",
            tier: .journalism
        ),
        RSSFeedSource(
            id: "marca-barca",
            feedURL: URL(string: "https://www.marca.com/rss/futbol/barcelona.xml")!,
            displayName: "Marca",
            tier: .journalism
        ),
        RSSFeedSource(
            id: "barca-universal",
            feedURL: URL(string: "https://barcauniversal.com/feed/")!,
            displayName: "Barca Universal",
            tier: .journalism
        ),
        RSSFeedSource(
            id: "football-espana",
            feedURL: URL(string: "https://www.football-espana.net/feed")!,
            displayName: "Football España",
            tier: .journalism
        ),
        RSSFeedSource(
            id: "bbc-football",
            feedURL: URL(string: "https://feeds.bbci.co.uk/sport/football/rss.xml")!,
            displayName: "BBC Sport",
            tier: .journalism
        ),
        RSSFeedSource(
            id: "espn-soccer",
            feedURL: URL(string: "https://www.espn.co.uk/espn/rss/soccer/news")!,
            displayName: "ESPN Soccer",
            tier: .journalism
        ),
    ]
}

struct RSSFeedSource: Identifiable, Hashable, Sendable {
    let id: String
    let feedURL: URL
    let displayName: String
    let tier: SourceTier
}
