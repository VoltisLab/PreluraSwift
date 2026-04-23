import Foundation

private let mrssNamespace = "http://search.yahoo.com/mrss/"
private let contentModuleNamespace = "http://purl.org/rss/1.0/modules/content/"

/// Minimal RSS 2.0 + `media:*` + `enclosure` parsing for news cards.
enum RSSFeedParser {
    nonisolated static func parse(data: Data, source: RSSFeedSource) -> [RSSParsedItem] {
        let delegate = RSSParserDelegate(source: source)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        guard parser.parse() else { return delegate.items }
        return delegate.items
    }

    /// Removes `<![CDATA[` / `]]>` wrappers that can leak into `description` / `content:encoded` text.
    nonisolated static func stripCDATAWrappers(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        var previous = ""
        while previous != s {
            previous = s
            s = s.replacingOccurrences(of: "<![CDATA[", with: "", options: .caseInsensitive)
            s = s.replacingOccurrences(of: "]]>", with: "")
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }
}

struct RSSParsedItem: Sendable {
    let title: String
    let summaryHTML: String
    let linkString: String
    let guidString: String?
    let pubDate: Date?
    let imageURL: URL?
    let source: RSSFeedSource
}

private final class RSSParserDelegate: NSObject, XMLParserDelegate {
    let source: RSSFeedSource
    private(set) var items: [RSSParsedItem] = []

    private var inItem = false
    private var currentElement: String?
    private var textBuffer = ""

    private var title = ""
    private var link = ""
    private var guid = ""
    private var descriptionHTML = ""
    private var contentEncodedHTML = ""
    private var pubDateString = ""
    private var imageURL: URL?

    init(source: RSSFeedSource) {
        self.source = source
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let tag = qName ?? elementName
        textBuffer = ""

        if tag == "item" {
            resetItem()
            inItem = true
            return
        }
        guard inItem else { return }
        currentElement = tag

        if tag == "enclosure" {
            if let urlStr = attributeDict["url"] {
                let type = attributeDict["type"]?.lowercased() ?? ""
                if type.hasPrefix("image") || urlStr.lowercased().contains(".jpg") || urlStr.lowercased().contains(".jpeg") || urlStr.lowercased().contains(".webp") || urlStr.lowercased().contains(".png") {
                    if imageURL == nil { imageURL = URL(string: urlStr) }
                }
            }
            return
        }

        let q = qName ?? elementName
        if namespaceURI == mrssNamespace || q.hasPrefix("media:") {
            switch elementName {
            case "content":
                if let urlStr = attributeDict["url"] {
                    let type = attributeDict["type"]?.lowercased() ?? ""
                    let medium = attributeDict["medium"]?.lowercased() ?? ""
                    if medium == "image" || type.hasPrefix("image") {
                        if imageURL == nil { imageURL = URL(string: urlStr) }
                    }
                }
            case "thumbnail":
                if let urlStr = attributeDict["url"], !urlStr.isEmpty, imageURL == nil {
                    imageURL = URL(string: urlStr)
                }
            default:
                break
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        textBuffer.append(string)
    }

    /// RSS often wraps `description` / `content:encoded` in CDATA; this delivers the inner bytes without `]]>` delimiters.
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem else { return }
        if let chunk = String(data: CDATABlock, encoding: .utf8) {
            textBuffer.append(chunk)
        } else if let chunk = String(data: CDATABlock, encoding: .isoLatin1) {
            textBuffer.append(chunk)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let tag = qName ?? elementName
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        textBuffer = ""

        if tag == "item" {
            flushItem()
            inItem = false
            return
        }
        guard inItem else { return }

        switch tag {
        case "title":
            if !text.isEmpty { title = text }
        case "link":
            if !text.isEmpty { link = text }
        case "guid":
            if !text.isEmpty { guid = text }
        case "description":
            if !text.isEmpty { descriptionHTML = text }
        case "content:encoded":
            if !text.isEmpty { contentEncodedHTML = text }
        case "encoded":
            if namespaceURI == contentModuleNamespace, !text.isEmpty { contentEncodedHTML = text }
        case "pubDate":
            if !text.isEmpty { pubDateString = text }
        default:
            break
        }
        currentElement = nil
    }

    private func resetItem() {
        title = ""
        link = ""
        guid = ""
        descriptionHTML = ""
        contentEncodedHTML = ""
        pubDateString = ""
        imageURL = nil
    }

    private func flushItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let linkCandidate = trimmedLink.isEmpty ? (guid.trimmingCharacters(in: .whitespacesAndNewlines)) : trimmedLink
        guard !linkCandidate.isEmpty else { return }

        let desc = RSSFeedParser.stripCDATAWrappers(descriptionHTML)
        let encoded = RSSFeedParser.stripCDATAWrappers(contentEncodedHTML)
        let richHTML: String = {
            if encoded.count >= desc.count, !encoded.isEmpty { return encoded }
            return desc
        }()

        var resolvedImage = imageURL
        if resolvedImage == nil {
            resolvedImage = HTMLImageExtractor.firstImageURL(in: richHTML)
                ?? HTMLImageExtractor.firstImageURL(in: desc)
        }

        let parsedGuid = guid.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = RSSParsedItem(
            title: trimmedTitle,
            summaryHTML: richHTML,
            linkString: linkCandidate,
            guidString: parsedGuid.isEmpty ? nil : parsedGuid,
            pubDate: RSSDateParsing.date(from: pubDateString),
            imageURL: resolvedImage,
            source: source
        )
        items.append(item)
    }
}

private enum RSSDateParsing {
    private static let formatters: [DateFormatter] = {
        let patterns = [
            "EEE, dd MMM yyyy HH:mm:ss ZZZZZ",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss ZZZZZ",
            "EEE MMM dd HH:mm:ss zzz yyyy",
        ]
        return patterns.map { pattern in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = pattern
            return f
        }
    }()

    static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        for f in formatters {
            if let d = f.date(from: trimmed) { return d }
        }
        return ISO8601DateFormatter().date(from: trimmed)
    }
}

private enum HTMLImageExtractor {
    nonisolated static func firstImageURL(in html: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: #"<img[^>]+src=["']([^"'>\s]+)["']"#, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range), match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: html) else { return nil }
        let raw = String(html[swiftRange])
        let decoded = raw
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#038;", with: "&")
        return URL(string: decoded)
    }
}
