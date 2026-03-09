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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
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
