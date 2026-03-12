import Foundation

struct Message: Identifiable {
    let id: UUID
    let senderUsername: String
    let content: String
    let preview: String
    let timestamp: Date
    let type: String
    let orderID: String?
    let thumbnailURL: String?
    
    init(
        id: UUID = UUID(),
        senderUsername: String,
        content: String,
        timestamp: Date = Date(),
        type: String = "order_issue",
        orderID: String? = nil,
        thumbnailURL: String? = nil
    ) {
        self.id = id
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

    /// Human-readable text for bubbles: show "Order issue" / "Order update" / "New offer" for JSON, else plain content.
    var displayContent: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return content
        }
        switch type {
        case "order_issue": return "Order issue"
        case "order": return "Order update"
        case "offer": return "New offer"
        default: return content
        }
    }

    /// True when content is JSON with type "sold_confirmation" (show banner instead of bubble).
    var isSoldConfirmation: Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return false }
        return type == "sold_confirmation"
    }

    /// Parsed sold_confirmation payload for banner (product_price, buyer_subtotal, etc.).
    struct SoldConfirmationData {
        let orderId: Int?
        let productName: String?
        let productPrice: String?
        let buyerSubtotal: String?
        let shippingDeadline: String?
        let shippingFee: String?
    }

    var soldConfirmationData: SoldConfirmationData? {
        guard isSoldConfirmation else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let orderId = json["order_id"] as? Int ?? (json["order_id"] as? String).flatMap(Int.init)
        return SoldConfirmationData(
            orderId: orderId,
            productName: json["product_name"] as? String,
            productPrice: json["product_price"] as? String,
            buyerSubtotal: json["buyer_subtotal"] as? String,
            shippingDeadline: json["shipping_deadline"] as? String,
            shippingFee: json["shipping_fee"] as? String
        )
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
