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
        self.preview = content.prefix(50) + "..."
        self.timestamp = timestamp
        self.type = type
        self.orderID = orderID
        self.thumbnailURL = thumbnailURL
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

    /// Human-readable text for bubbles: show "Order issue" / "Order update" / "Offer sent"|"New offer" for JSON or offer payload, else plain content.
    /// Pass isFromCurrentUser so we show "Offer sent" for sender and "New offer" for recipient.
    func displayContentForBubble(isFromCurrentUser: Bool) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let type = json["type"] as? String {
            switch type {
            case "order_issue": return "Order issue"
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
