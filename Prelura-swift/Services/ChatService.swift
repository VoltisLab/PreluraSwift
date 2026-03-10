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
    
    /// Conversations list. Matches Flutter/backend: MessageType uses `text` (not `content`).
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
              sender {
                username
              }
            }
            unreadMessagesCount
          }
        }
        """
        
        let response: ConversationsResponse = try await client.execute(
            query: query,
            operationName: "Conversations",
            responseType: ConversationsResponse.self
        )
        
        return response.conversations?.compactMap { conv in
            // Convert id to string
            let idString: String
            if let anyCodable = conv.id {
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
            
            // Extract recipient id
            let recipientIdString: String
            if let recipientId = conv.recipient?.id {
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
                    username: conv.recipient?.username ?? "",
                    displayName: conv.recipient?.displayName ?? "",
                    avatarURL: conv.recipient?.profilePictureUrl
                ),
                lastMessage: conv.lastMessage?.text,
                lastMessageTime: parseDate(conv.lastMessage?.createdAt),
                unreadCount: conv.unreadMessagesCount ?? 0
            )
        } ?? []
    }
    
    func getMessages(conversationId: String, pageNumber: Int = 1, pageCount: Int = 50) async throws -> [Message] {
        let query = """
        query Conversation($id: ID!, $pageNumber: Int, $pageCount: Int) {
          conversation(id: $id, pageNumber: $pageNumber, pageCount: $pageCount) {
            id
            messages {
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
        }
        """
        
        let variables: [String: Any] = [
            "id": conversationId,
            "pageNumber": pageNumber,
            "pageCount": pageCount
        ]
        
        let response: ConversationResponse = try await client.execute(
            query: query,
            variables: variables,
            responseType: ConversationResponse.self
        )
        
        guard let messages = response.conversation?.messages else {
            return []
        }
        
        return messages.compactMap { msg in
            // Convert id to string
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
                senderUsername: senderUsername,
                content: text,
                timestamp: parseDate(msg.createdAt) ?? Date(),
                type: msg.isItem == true ? "item" : "text",
                orderID: msg.itemId.map { String($0) },
                thumbnailURL: nil
            )
        }
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
                avatarUrl
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
        
        guard let chat = response.createChat?.chat,
              let id = chat.id else {
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
            id: id,
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

    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}

struct Conversation: Hashable {
    let id: String
    let recipient: User
    let lastMessage: String?
    let lastMessageTime: Date?
    let unreadCount: Int

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.id == rhs.id }
}

struct ConversationsResponse: Decodable {
    let conversations: [ConversationData]?
}

struct ConversationData: Decodable {
    let id: AnyCodable?
    let recipient: UserData?
    let lastMessage: MessageData?
    let unreadMessagesCount: Int?
}

struct ConversationResponse: Decodable {
    let conversation: ConversationDetailData?
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
    let id: String?
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
