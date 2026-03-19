import Foundation

/// Sold event in the chat timeline. Used for ChatItem.sold and SoldConfirmationCardView.
struct OrderInfo: Identifiable, Hashable, Codable {
    let id: String
    let orderId: String
    let price: Double
    let buyerUsername: String
    let sellerUsername: String
    let createdAt: Date

    /// Build from conversation order + offer context (buyer/seller from offer).
    static func from(conversationOrder: ConversationOrder, buyerUsername: String?, sellerUsername: String?) -> OrderInfo {
        OrderInfo(
            id: "sold-\(conversationOrder.id)",
            orderId: conversationOrder.id,
            price: conversationOrder.total,
            buyerUsername: buyerUsername ?? "",
            sellerUsername: sellerUsername ?? "",
            createdAt: conversationOrder.createdAt ?? Date()
        )
    }
}
