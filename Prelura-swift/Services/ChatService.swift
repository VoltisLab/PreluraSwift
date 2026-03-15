import Foundation
import Combine

@MainActor
class ChatService: ObservableObject {
    private var client: GraphQLClient
    
    init(client: GraphQLClient? = nil) {
        self.client = client ?? GraphQLClient()
        // Try to load auth token from UserDefaults
        if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            self.client.setAuthToken(token)
        }
    }
    
    func updateAuthToken(_ token: String?) {
        client.setAuthToken(token)
    }
    
    /// Conversations list. Includes offer when present (for offer card in chat).
    func getConversations() async throws -> [Conversation] {
        let query = """
        query Conversations {
          conversations {
            id
            recipient {
              id
              username
              displayName
              profilePictureUrl
            }
            lastMessage {
              id
              text
              createdAt
              sender { username }
            }
            unreadMessagesCount
            offer {
              id
              status
              offerPrice
              buyer { username profilePictureUrl }
              products { id name seller { username profilePictureUrl } }
            }
          }
        }
        """
        
        let response: ConversationsResponse = try await client.execute(
            query: query,
            operationName: "Conversations",
            responseType: ConversationsResponse.self
        )
        
        return response.conversations?.compactMap { conv in
            guard let idString = Conversation.idString(from: conv.id) else { return nil }
            let recipientIdString: String
            if let recipientId = conv.recipient?.id {
                if let intValue = recipientId.value as? Int { recipientIdString = String(intValue) }
                else if let stringValue = recipientId.value as? String { recipientIdString = stringValue }
                else { recipientIdString = String(describing: recipientId.value) }
            } else {
                recipientIdString = ""
            }
            let offer: OfferInfo? = conv.offer.flatMap { Conversation.offerInfo(from: $0) }
            return Conversation(
                id: idString,
                recipient: User(
                    id: UUID(uuidString: recipientIdString) ?? UUID(),
                    username: conv.recipient?.username ?? "",
                    displayName: conv.recipient?.displayName ?? "",
                    avatarURL: conv.recipient?.profilePictureUrl
                ),
                lastMessage: conv.lastMessage?.text,
                lastMessageTime: parseDate(conv.lastMessage?.createdAt),
                unreadCount: conv.unreadMessagesCount ?? 0,
                offer: offer
            )
        } ?? []
    }
    
    func getMessages(conversationId: String, pageNumber: Int = 1, pageCount: Int = 50) async throws -> [Message] {
        // Backend returns conversation(id:) as [MessageType] directly, not { id, messages }.
        let query = """
        query Conversation($id: ID!, $pageNumber: Int, $pageCount: Int) {
          conversation(id: $id, pageNumber: $pageNumber, pageCount: $pageCount) {
            id
            text
            createdAt
            sender {
              id
              username
              profilePictureUrl
            }
            isItem
            itemId
          }
        }
        """
        
        let variables: [String: Any] = [
            "id": conversationId,
            "pageNumber": pageNumber,
            "pageCount": pageCount
        ]
        
        let response: ConversationMessagesResponse = try await client.execute(
            query: query,
            variables: variables,
            responseType: ConversationMessagesResponse.self
        )
        
        guard let messages = response.conversation else {
            return []
        }
        
        let list: [Message] = messages.compactMap { msg in
            // Backend id (Int) for mark-as-read
            let backendIdInt: Int?
            if let anyCodable = msg.id {
                if let intValue = anyCodable.value as? Int {
                    backendIdInt = intValue
                } else if let stringValue = anyCodable.value as? String, let i = Int(stringValue) {
                    backendIdInt = i
                } else {
                    backendIdInt = nil
                }
            } else {
                backendIdInt = nil
            }
            let idString: String
            if let anyCodable = msg.id {
                if let intValue = anyCodable.value as? Int {
                    idString = String(intValue)
                } else if let stringValue = anyCodable.value as? String {
                    idString = stringValue
                } else {
                    idString = String(describing: anyCodable.value)
                }
            } else {
                return nil
            }
            
            guard let text = msg.text,
                  let senderUsername = msg.sender?.username else {
                return nil
            }
            
            return Message(
                id: UUID(uuidString: idString) ?? UUID(),
                backendId: backendIdInt,
                senderUsername: senderUsername,
                content: text,
                timestamp: parseDate(msg.createdAt) ?? Date(),
                type: msg.isItem == true ? "item" : "text",
                orderID: msg.itemId.map { String($0) },
                thumbnailURL: nil
            )
        }
        return list.sorted { $0.timestamp < $1.timestamp }
    }
    
    func createChat(recipient: String) async throws -> Conversation {
        let mutation = """
        mutation CreateChat($recipient: String!) {
          createChat(recipient: $recipient) {
            chat {
              id
              recipient {
                id
                username
                displayName
                profilePictureUrl
              }
            }
          }
        }
        """
        
        let variables: [String: Any] = ["recipient": recipient]
        
        let response: CreateChatResponse = try await client.execute(
            query: mutation,
            variables: variables,
            responseType: CreateChatResponse.self
        )
        
        guard let chat = response.createChat?.chat else {
            throw ChatError.invalidResponse
        }
        let idString: String
        if let anyId = chat.id {
            if let intValue = anyId.value as? Int {
                idString = String(intValue)
            } else if let stringValue = anyId.value as? String {
                idString = stringValue
            } else {
                idString = String(describing: anyId.value)
            }
        } else {
            throw ChatError.invalidResponse
        }
        // Extract recipient id
        let recipientIdString: String
        if let recipientId = chat.recipient?.id {
            if let intValue = recipientId.value as? Int {
                recipientIdString = String(intValue)
            } else if let stringValue = recipientId.value as? String {
                recipientIdString = stringValue
            } else {
                recipientIdString = String(describing: recipientId.value)
            }
        } else {
            recipientIdString = ""
        }
        
        return Conversation(
            id: idString,
            recipient: User(
                id: UUID(uuidString: recipientIdString) ?? UUID(),
                username: chat.recipient?.username ?? "",
                displayName: chat.recipient?.displayName ?? "",
                avatarURL: chat.recipient?.profilePictureUrl
            ),
            lastMessage: nil,
            lastMessageTime: nil,
            unreadCount: 0
        )
    }
    
    /// Send a message (GraphQL fallback when WebSocket is unavailable).
    /// conversationId: backend expects Int; we accept String and pass Int when possible.
    func sendMessage(conversationId: String, message: String, messageUuid: String?) async throws -> Bool {
        let convIdInt = Int(conversationId) ?? 0
        let mutation = """
        mutation SendMessage($conversationId: Int!, $message: String!, $messageUuid: String) {
          sendMessage(conversationId: $conversationId, message: $message, messageUuid: $messageUuid) {
            success
            messageId
          }
        }
        """
        var variables: [String: Any] = ["conversationId": convIdInt, "message": message]
        if let uuid = messageUuid { variables["messageUuid"] = uuid }
        let response: SendMessageResponse = try await client.execute(
            query: mutation,
            variables: variables,
            responseType: SendMessageResponse.self
        )
        return response.sendMessage?.success ?? false
    }
    
    /// Mark messages as read. Matches Flutter readMessages(ids). Call when opening a conversation.
    func readMessages(messageIds: [Int]) async throws -> Bool {
        guard !messageIds.isEmpty else { return true }
        let mutation = """
        mutation UpdateReadMessages($messageIds: [Int]!) {
          updateReadMessages(messageIds: $messageIds) {
            success
          }
        }
        """
        let variables: [String: Any] = ["messageIds": messageIds]
        struct Payload: Decodable { let updateReadMessages: UpdateReadResult? }
        struct UpdateReadResult: Decodable { let success: Bool? }
        let response: Payload = try await client.execute(query: mutation, variables: variables, responseType: Payload.self)
        return response.updateReadMessages?.success ?? false
    }
    
    /// Create a sold-confirmation message in the order's conversation. Matches Flutter createSoldConfirmationMessage(orderId). Call after seller marks order/item as sold.
    func createSoldConfirmationMessage(orderId: Int) async throws -> (success: Bool, conversationId: Int?) {
        let mutation = """
        mutation CreateSoldConfirmationMessage($orderId: Int!) {
          createSoldConfirmationMessage(orderId: $orderId) {
            success
            messageId
            conversationId
          }
        }
        """
        let variables: [String: Any] = ["orderId": orderId]
        struct Payload: Decodable {
            let createSoldConfirmationMessage: Result?
            struct Result: Decodable {
                let success: Bool?
                let messageId: Int?
                let conversationId: Int?
            }
        }
        let response: Payload = try await client.execute(query: mutation, variables: variables, responseType: Payload.self)
        let result = response.createSoldConfirmationMessage
        return (result?.success ?? false, result?.conversationId)
    }
    
    /// Delete a single message. Matches Flutter deleteMessage(messageId). Use message.backendId.
    func deleteMessage(messageId: Int) async throws {
        let mutation = """
        mutation DeleteMessage($messageId: Int!) {
          deleteMessage(messageId: $messageId) {
            message
          }
        }
        """
        let variables: [String: Any] = ["messageId": messageId]
        struct Payload: Decodable { let deleteMessage: Result?; struct Result: Decodable { let message: String? } }
        _ = try await client.execute(query: mutation, variables: variables, responseType: Payload.self)
    }
    
    /// Delete a conversation. Matches Flutter deleteConversation(conversationId).
    func deleteConversation(conversationId: Int) async throws {
        let mutation = """
        mutation DeleteConversation($conversationId: Int!) {
          deleteConversation(conversationId: $conversationId) {
            message
          }
        }
        """
        let variables: [String: Any] = ["conversationId": conversationId]
        struct Payload: Decodable { let deleteConversation: Result?; struct Result: Decodable { let message: String? } }
        _ = try await client.execute(query: mutation, variables: variables, responseType: Payload.self)
    }
    
    /// Delete all conversations (admin/self-service). Matches Flutter deleteAllConversations.
    func deleteAllConversations() async throws -> (success: Bool, message: String?, deletedConversationsCount: Int?, deletedOrdersCount: Int?) {
        let mutation = """
        mutation DeleteAllConversations {
          deleteAllConversations {
            success
            message
            deletedConversationsCount
            deletedOrdersCount
          }
        }
        """
        struct Payload: Decodable {
            let deleteAllConversations: Result?
            struct Result: Decodable {
                let success: Bool?
                let message: String?
                let deletedConversationsCount: Int?
                let deletedOrdersCount: Int?
            }
        }
        let response: Payload = try await client.execute(query: mutation, variables: [:], responseType: Payload.self)
        let result = response.deleteAllConversations
        return (result?.success ?? false, result?.message, result?.deletedConversationsCount, result?.deletedOrdersCount)
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}

struct Conversation: Hashable {
    let id: String
    let recipient: User
    let lastMessage: String?
    let lastMessageTime: Date?
    let unreadCount: Int
    let offer: OfferInfo?

    init(id: String, recipient: User, lastMessage: String?, lastMessageTime: Date?, unreadCount: Int, offer: OfferInfo? = nil) {
        self.id = id
        self.recipient = recipient
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
        self.offer = offer
    }

    static func idString(from anyCodable: AnyCodable?) -> String? {
        guard let ac = anyCodable else { return nil }
        if let i = ac.value as? Int { return String(i) }
        if let s = ac.value as? String { return s }
        return String(describing: ac.value)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.id == rhs.id }

    static func offerInfo(from data: OfferData) -> OfferInfo? {
        let idStr = idString(from: data.id) ?? ""
        let price: Double = data.offerPrice?.value ?? 0
        let buyer: OfferInfo.OfferUser? = data.buyer.map { OfferInfo.OfferUser(username: $0.username, profilePictureUrl: $0.profilePictureUrl) }
        let products: [OfferInfo.OfferProduct]? = data.products?.map { p in
            OfferInfo.OfferProduct(
                id: idString(from: p.id),
                name: p.name,
                seller: p.seller.map { OfferInfo.OfferUser(username: $0.username, profilePictureUrl: $0.profilePictureUrl) }
            )
        }
        return OfferInfo(id: idStr, status: data.status, offerPrice: price, buyer: buyer, products: products)
    }
}

struct ConversationsResponse: Decodable {
    let conversations: [ConversationData]?
}

struct ConversationData: Decodable {
    let id: AnyCodable?
    let recipient: UserData?
    let lastMessage: MessageData?
    let unreadMessagesCount: Int?
    let offer: OfferData?
}

struct OfferData: Decodable {
    let id: AnyCodable?
    let status: String?
    fileprivate let offerPrice: DoubleOrDecimal?
    let buyer: OfferUserData?
    let products: [OfferProductData]?
    struct OfferUserData: Decodable {
        let username: String?
        let profilePictureUrl: String?
    }
    struct OfferProductData: Decodable {
        let id: AnyCodable?
        let name: String?
        let seller: OfferUserData?
    }
}

fileprivate enum DoubleOrDecimal: Decodable {
    case double(Double)
    case decimal(Decimal)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let dec = try? c.decode(Decimal.self) { self = .decimal(dec); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Expected Double or Decimal")
    }
    var value: Double {
        switch self {
        case .double(let d): return d
        case .decimal(let d): return NSDecimalNumber(decimal: d).doubleValue
        }
    }
}

struct ConversationResponse: Decodable {
    let conversation: ConversationDetailData?
}

/// Response when conversation(id:) returns [MessageType] directly (not wrapped in { id, messages }).
struct ConversationMessagesResponse: Decodable {
    let conversation: [MessageData]?
}

struct ConversationDetailData: Decodable {
    let id: String?
    let messages: [MessageData]?
}

struct MessageData: Decodable {
    let id: AnyCodable?
    let text: String?
    let createdAt: String?
    let sender: UserData?
    let isItem: Bool?
    let itemId: Int?
}

struct UserData: Decodable {
    let id: AnyCodable?
    let username: String?
    let displayName: String?
    let profilePictureUrl: String?
}

struct CreateChatResponse: Decodable {
    let createChat: CreateChatData?
}

struct CreateChatData: Decodable {
    let chat: ChatData?
}

struct ChatData: Decodable {
    let id: AnyCodable?
    let recipient: UserData?
}

struct SendMessageResponse: Decodable {
    let sendMessage: SendMessagePayload?
}

struct SendMessagePayload: Decodable {
    let success: Bool?
    let messageId: Int?
}

// AnyCodable is defined in UserService.swift - reuse it

enum ChatError: Error, LocalizedError {
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
