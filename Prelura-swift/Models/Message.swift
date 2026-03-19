import Foundation

struct Message: Identifiable {
    let id: UUID
    /// Backend message ID (for mark-as-read API).
    let backendId: Int?
    let senderUsername: String
    let content: String
    let preview: String
    let timestamp: Date
    let type: String
    let orderID: String?
    let thumbnailURL: String?
    
    init(
        id: UUID = UUID(),
        backendId: Int? = nil,
        senderUsername: String,
        content: String,
        timestamp: Date = Date(),
        type: String = "order_issue",
        orderID: String? = nil,
        thumbnailURL: String? = nil
    ) {
        self.id = id
        self.backendId = backendId
        self.senderUsername = senderUsername
        self.content = content
        self.preview = Self.makeListPreview(from: content)
        self.timestamp = timestamp
        self.type = type
        self.orderID = orderID
        self.thumbnailURL = thumbnailURL
    }
    
    /// One-line preview for inbox/lists; never surface raw JSON for structured message types.
    private static func makeListPreview(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
            switch type {
            case "order_issue": return "You reported an issue"
            case "order": return "Order update"
            case "offer": return "Offer"
            case "sold_confirmation": return "Order confirmed"
            default: break
            }
        }
        return String(content.prefix(50)) + "..."
    }

    var formattedTimestamp: String {
        let now = Date()
        let interval = timestamp.timeIntervalSince(now)
        if interval > -60 {
            return "Just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let str = formatter.localizedString(for: timestamp, relativeTo: now)
        if str.hasPrefix("in ") {
            return "Just now"
        }
        return str
    }

    /// True when content is offer payload (JSON type "offer" or backend sending Python-style e.g. {'offer_id': 323}).
    var isOfferContent: Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if json["type"] as? String == "offer" { return true }
            if json["offer_id"] != nil { return true }
        }
        if trimmed.contains("offer_id") { return true }
        return false
    }

    /// Parsed offer id and price from message content (for building offer history from messages). Returns nil if not offer content or unparseable.
    /// Supports offer_id / offerId and offerPrice / offer_price so all offer messages show in history.
    var parsedOfferDetails: (offerId: String, offerPrice: Double)? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let hasOffer = json["type"] as? String == "offer" || json["offer_id"] != nil || json["offerId"] != nil
        guard hasOffer else { return nil }
        let offerId: String?
        if let id = json["offer_id"] as? Int { offerId = String(id) }
        else if let id = json["offer_id"] as? String { offerId = id }
        else if let id = json["offerId"] as? Int { offerId = String(id) }
        else if let id = json["offerId"] as? String { offerId = id }
        else { offerId = nil }
        guard let id = offerId else { return nil }
        var offerPrice: Double = 0
        if let p = json["offerPrice"] as? Double { offerPrice = p }
        else if let p = json["offer_price"] as? Double { offerPrice = p }
        else if let n = json["offerPrice"] as? NSNumber { offerPrice = n.doubleValue }
        else if let n = json["offer_price"] as? NSNumber { offerPrice = n.doubleValue }
        return (id, offerPrice)
    }

    /// Human-readable text for bubbles: show "You reported an issue" / "Order update" / "Offer sent"|"New offer" for JSON or offer payload, else plain content.
    /// Pass isFromCurrentUser so we show "Offer sent" for sender and "New offer" for recipient.
    func displayContentForBubble(isFromCurrentUser: Bool) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let type = json["type"] as? String {
            switch type {
            case "order_issue": return "You reported an issue"
            case "order": return "Order update"
            case "offer": return isFromCurrentUser ? "Offer sent" : "New offer"
            case "sold_confirmation": return "Order confirmed"
            default: break
            }
        }
        if isOfferContent {
            return isFromCurrentUser ? "Offer sent" : "New offer"
        }
        return content
    }

    /// Human-readable text for list preview; does not need sender context.
    var displayContent: String {
        displayContentForBubble(isFromCurrentUser: false)
    }

    /// True when backend sent itemType "sold_confirmation" or content is JSON with type "sold_confirmation" (show as "Order confirmed" bubble; sale UI is OrderConfirmationCardView).
    var isSoldConfirmation: Bool {
        if type == "sold_confirmation" { return true }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = json["type"] as? String else { return false }
        return t == "sold_confirmation"
    }

    var isOrderIssue: Bool {
        if type == "order_issue" { return true }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = json["type"] as? String else { return false }
        return t == "order_issue"
    }

    /// Parse order issue payload persisted in chat message text.
    /// Backend payload keys observed: order_id, issue_id, public_id, issue_type.
    var parsedOrderIssueDetails: (orderId: String?, issueId: Int?, publicId: String?, issueType: String?)? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["type"] as? String) == "order_issue" || type == "order_issue" else { return nil }

        let orderId: String? = {
            if let n = json["order_id"] as? Int { return String(n) }
            if let s = json["order_id"] as? String { return s }
            if let n = json["orderId"] as? Int { return String(n) }
            if let s = json["orderId"] as? String { return s }
            return nil
        }()
        let issueId: Int? = {
            if let n = json["issue_id"] as? Int { return n }
            if let s = json["issue_id"] as? String { return Int(s) }
            if let n = json["issueId"] as? Int { return n }
            if let s = json["issueId"] as? String { return Int(s) }
            return nil
        }()
        let publicId: String? = {
            if let s = json["public_id"] as? String { return s }
            if let s = json["publicId"] as? String { return s }
            return nil
        }()
        let issueType: String? = {
            if let s = json["issue_type"] as? String { return s }
            if let s = json["issueType"] as? String { return s }
            return nil
        }()
        return (orderId, issueId, publicId, issueType)
    }
}

extension Message {
    static let sampleMessages: [Message] = [
        Message(
            senderUsername: "shinor",
            content: #"{"type": "order_issue", "order_id": "is123456"}"#,
            timestamp: Date().addingTimeInterval(-6 * 24 * 60 * 60),
            thumbnailURL: "https://picsum.photos/seed/miniskirt1/200/200"
        ),
        Message(
            senderUsername: "shinor",
            content: #"{"type": "order_issue", "order_id": "is123457"}"#,
            timestamp: Date().addingTimeInterval(-8 * 24 * 60 * 60),
            thumbnailURL: "https://picsum.photos/seed/halter1/200/200"
        ),
        Message(
            senderUsername: "shinor",
            content: #"{"type": "order_issue", "order_id": "is123458"}"#,
            timestamp: Date().addingTimeInterval(-9 * 24 * 60 * 60),
            thumbnailURL: "https://picsum.photos/seed/sequin1/200/200"
        ),
        Message(
            senderUsername: "shinor",
            content: #"{"type": "order_issue", "order_id": "is123459"}"#,
            timestamp: Date().addingTimeInterval(-12 * 24 * 60 * 60),
            thumbnailURL: "https://picsum.photos/seed/skirt2/200/200"
        ),
        Message(
            senderUsername: "shinor",
            content: #"{"type": "order_issue", "order_id": "is123460"}"#,
            timestamp: Date().addingTimeInterval(-46 * 24 * 60 * 60),
            thumbnailURL: "https://picsum.photos/seed/leopard1/200/200"
        ),
        Message(
            senderUsername: "shinor",
            content: #"{"type": "order_issue", "order_id": "is123461"}"#,
            timestamp: Date().addingTimeInterval(-48 * 24 * 60 * 60),
            thumbnailURL: "https://picsum.photos/seed/stripe1/200/200"
        ),
        Message(
            senderUsername: "shinor",
            content: #"{"type": "order_issue", "order_id": "is123462"}"#,
            timestamp: Date().addingTimeInterval(-48 * 24 * 60 * 60),
            thumbnailURL: "https://picsum.photos/seed/strapless1/200/200"
        )
    ]
}
