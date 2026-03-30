import Foundation

/// Event pushed when backend creates/updates an offer (Django Channels). When backend sends NEW_OFFER / UPDATE_OFFER, use this to update UI without refetch.
struct OfferSocketEvent {
    let type: String  // "NEW_OFFER" | "UPDATE_OFFER"
    let conversationId: String?
    let offer: OfferInfo?
    let offerId: String?
    let status: String?
    /// Explicit sender for offer events when backend provides it.
    let senderUsername: String?
}

/// Typing event pushed by backend while peer is composing a message.
struct TypingSocketEvent {
    let conversationId: String?
    let isTyping: Bool
    let senderUsername: String?
}

/// Order-related event pushed by backend (e.g. order_status_event, sold confirmation linkage).
struct OrderSocketEvent {
    let type: String
    let conversationId: String?
}

/// Relayed chat message reaction from another participant (`message_reaction` on the socket).
struct MessageReactionSocketEvent {
    let messageId: Int
    /// Nil or empty means reaction removed for that user.
    let emoji: String?
    let username: String
}

/// WebSocket client for chat: connect to backend ws, send messages, receive new messages and events.
/// Uses same host as GraphQL (Constants.chatWebSocketBaseURL) so messages send/save to the same backend.
final class ChatWebSocketService: NSObject, @unchecked Sendable {
    private let conversationId: String
    private let token: String
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Error>?
    private let baseURL = Constants.chatWebSocketBaseURL

    /// Called on main actor when a new chat message is received. If server echoes our send, messageUuid is the client UUID we sent.
    var onNewMessage: (@MainActor (Message, String?) -> Void)?
    /// Called when backend pushes NEW_OFFER or UPDATE_OFFER (enables instant offer updates without refetch).
    var onOfferEvent: (@MainActor (OfferSocketEvent) -> Void)?
    /// Called when backend pushes typing events.
    var onTypingEvent: (@MainActor (TypingSocketEvent) -> Void)?
    /// Called when backend pushes order-related events.
    var onOrderEvent: (@MainActor (OrderSocketEvent) -> Void)?
    /// Called when connection state changes (e.g. for UI indicator).
    var onConnectionStateChanged: (@MainActor (Bool) -> Void)?
    /// Another participant updated a message reaction (server type `message_reaction`).
    var onMessageReaction: (@MainActor (MessageReactionSocketEvent) -> Void)?

    init(conversationId: String, token: String) {
        self.conversationId = conversationId
        self.token = token
    }

    func connect() {
        guard let url = URL(string: baseURL + conversationId + "/") else { return }
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        task = session.webSocketTask(with: request)
        task?.resume()
        receiveTask = Task {
            await receiveLoop()
        }
        Task { @MainActor in
            onConnectionStateChanged?(true)
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        Task { @MainActor in
            onConnectionStateChanged?(false)
        }
    }

    /// Send a text message. Payload: {"message": text, "message_uuid": uuid}
    func send(message: String, messageUUID: String) {
        let payload: [String: Any] = ["message": message, "message_uuid": messageUUID]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(string)) { [weak self] error in
            if let e = error {
                print("ChatWebSocket send error: \(e)")
            }
        }
    }

    /// Send typing state to backend, when supported by chat socket.
    /// Payload follows existing backend convention: {"is_typing": true/false}
    func sendTyping(isTyping: Bool) {
        // Send multiple commonly-used keys so backend variants can understand typing updates.
        let payload: [String: Any] = [
            "type": "typing",
            "is_typing": isTyping,
            "isTyping": isTyping,
            "conversation_id": conversationId,
            "conversationId": conversationId
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(string)) { error in
            if let e = error {
                print("ChatWebSocket typing send error: \(e)")
            }
        }
    }

    /// Notify room of reaction change; server broadcasts `message_reaction` to all participants.
    func sendMessageReaction(messageId: Int, emoji: String?) {
        var payload: [String: Any] = [
            "type": "message_reaction",
            "message_id": messageId,
            "conversation_id": conversationId,
        ]
        if let e = emoji, !e.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["emoji"] = e
        } else {
            payload["remove"] = true
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(string)) { error in
            if let e = error {
                print("ChatWebSocket reaction send error: \(e)")
            }
        }
    }

    private func receiveLoop() async {
        guard let task = task else { return }
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    await handleReceivedString(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleReceivedString(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if (error as NSError).code != NSURLErrorCancelled {
                    print("ChatWebSocket receive error: \(error)")
                }
                break
            }
        }
    }

    /// JSON may send conversation id as String or Int.
    private static func jsonString(_ value: Any?) -> String? {
        switch value {
        case let s as String:
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        case let i as Int:
            return String(i)
        case let n as NSNumber:
            return n.stringValue
        default:
            return nil
        }
    }

    /// JSON may use Bool, 0/1, or NSNumber from mixed encoders.
    private static func coerceTypingFlag(_ value: Any?) -> Bool? {
        switch value {
        case let b as Bool:
            return b
        case let i as Int:
            return i != 0
        case let n as NSNumber:
            return n.boolValue
        case let s as String:
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if t == "true" || t == "1" || t == "yes" { return true }
            if t == "false" || t == "0" || t == "no" { return false }
            return nil
        default:
            return nil
        }
    }

    private func handleReceivedString(_ text: String) async {
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return }
        let type = json["type"] as? String
        if type == "order_issue_created" || type == "order_status_event" {
            let convId = (json["conversationId"] as? String) ?? (json["conversation_id"] as? String)
            await MainActor.run {
                onOrderEvent?(OrderSocketEvent(type: type ?? "", conversationId: convId))
            }
            return
        }
        if type == "message_reaction" {
            let mid = (json["message_id"] as? Int)
                ?? (json["messageId"] as? Int)
                ?? ((json["message_id"] as? String).flatMap { Int($0) })
                ?? ((json["messageId"] as? String).flatMap { Int($0) })
            let rawEmoji = (json["emoji"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let emoji = rawEmoji.isEmpty ? nil : rawEmoji
            let username = ((json["username"] as? String) ?? (json["sender"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let mid {
                let ev = MessageReactionSocketEvent(messageId: mid, emoji: emoji, username: username)
                await MainActor.run {
                    onMessageReaction?(ev)
                }
            }
            return
        }
        // Typing: server broadcasts `type: typing_status` + `sender`; clients may send `typing` / `typing_status` + is_typing / isTyping.
        // Do not treat real chat frames (`chat_message`) as typing even if a stray key appears.
        if type != "chat_message",
           type == "typing_status" || type == "typing"
           || json["is_typing"] != nil || json["isTyping"] != nil {
            let convId = Self.jsonString(json["conversationId"])
                ?? Self.jsonString(json["conversation_id"])
            let isTyping = Self.coerceTypingFlag(json["is_typing"]) ?? Self.coerceTypingFlag(json["isTyping"]) ?? true
            let senderUsername = (json["senderUsername"] as? String)
                ?? (json["sender_username"] as? String)
                ?? (json["senderName"] as? String)
                ?? (json["sender_name"] as? String)
                ?? (json["sender"] as? String)
                ?? (json["username"] as? String)
            await MainActor.run {
                onTypingEvent?(TypingSocketEvent(conversationId: convId, isTyping: isTyping, senderUsername: senderUsername))
            }
            return
        }
        // Django backend sends offer_status_event with nested `offer` + sender_username (see prelura-app offer_utils).
        if type == "offer_status_event" {
            let convId = (json["conversationId"] as? String) ?? (json["conversation_id"] as? String)
            let offerJson = json["offer"] as? [String: Any]
            // Prefer top-level; fall back to nested offer (backend now sends senderUsername in both).
            let senderUsername = (json["senderUsername"] as? String)
                ?? (json["sender_username"] as? String)
                ?? (json["senderName"] as? String)
                ?? (json["sender_name"] as? String)
                ?? (offerJson?["senderUsername"] as? String)
                ?? (offerJson?["sender_username"] as? String)
            let offerId = (json["offerId"] as? String) ?? (json["offer_id"] as? String) ?? (json["offer_id"] as? Int).map { String($0) }
            let status = json["status"] as? String
            if offerJson != nil {
                let offer = parseOfferFromSocket(offerJson)
                await MainActor.run {
                    onOfferEvent?(OfferSocketEvent(type: "NEW_OFFER", conversationId: convId, offer: offer, offerId: offerId, status: status, senderUsername: senderUsername))
                }
            } else {
                await MainActor.run {
                    onOfferEvent?(OfferSocketEvent(type: "UPDATE_OFFER", conversationId: convId, offer: nil, offerId: offerId, status: status, senderUsername: senderUsername))
                }
            }
            return
        }
        // Offer events: optional explicit NEW_OFFER / UPDATE_OFFER (same payload shape).
        if type == "NEW_OFFER" || type == "UPDATE_OFFER" {
            let convId = (json["conversationId"] as? String) ?? (json["conversation_id"] as? String)
            let offerJson = json["offer"] as? [String: Any]
            let offer = parseOfferFromSocket(offerJson)
            let offerId = (json["offerId"] as? String) ?? (json["offer_id"] as? String) ?? (json["offerId"] as? Int).map { String($0) }
            let status = json["status"] as? String
            // Only explicit top-level sender fields — never infer from offer.buyer (buyer is stable; counters would mis-attribute).
            let senderUsername = (json["senderUsername"] as? String)
                ?? (json["sender_username"] as? String)
                ?? (json["senderName"] as? String)
                ?? (json["sender_name"] as? String)
            await MainActor.run {
                onOfferEvent?(OfferSocketEvent(type: type ?? "", conversationId: convId, offer: offer, offerId: offerId, status: status, senderUsername: senderUsername))
            }
            return
        }
        // New message: parse and notify on main actor (messageUuid when server confirms our send).
        guard let msg = parseWebSocketMessage(json) else { return }
        let echoUuid = (json["message_uuid"] as? String) ?? (json["messageUuid"] as? String)
        await MainActor.run {
            onNewMessage?(msg, echoUuid)  // echoUuid = message_uuid when server confirms our send
        }
    }

    /// Parse server message JSON to Message (Flutter MessageModel.fromSocket: id, text, senderName/sender_name, createdAt, isItem, itemId).
    private func parseWebSocketMessage(_ json: [String: Any]) -> Message? {
        guard let text = json["text"] as? String else { return nil }
        let senderName = (json["senderName"] as? String) ?? (json["sender_name"] as? String) ?? ""
        let idStr = (json["id"] as? Int).map { String($0) } ?? (json["id"] as? String) ?? UUID().uuidString
        let uuid = UUID(uuidString: idStr) ?? UUID()
        let createdAt: Date = {
            let s = (json["createdAt"] as? String) ?? (json["created_at"] as? String)
            guard let s = s else { return Date() }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = formatter.date(from: s) { return d }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: s) ?? Date()
        }()
        let isItem = (json["isItem"] as? Bool) ?? (json["is_item"] as? Bool) ?? false
        let itemType = (json["itemType"] as? String) ?? (json["item_type"] as? String)
        let itemId = (json["itemId"] as? Int).map { String($0) } ?? (json["item_id"] as? Int).map { String($0) }
        let messageType: String = (itemType?.isEmpty == false) ? itemType! : (isItem ? "item" : "text")
        let read = (json["read"] as? Bool) ?? false
        return Message(
            id: uuid,
            backendId: (json["id"] as? Int) ?? (json["id"] as? String).flatMap { Int($0) },
            senderUsername: senderName,
            content: text,
            timestamp: createdAt,
            type: messageType,
            orderID: itemId,
            thumbnailURL: nil,
            read: read
        )
    }

    /// Parse offer payload from NEW_OFFER socket event. Backend may send id, offerPrice, status, createdAt (timestamp).
    private func parseOfferFromSocket(_ offerJson: [String: Any]?) -> OfferInfo? {
        guard let o = offerJson else { return nil }
        let id = (o["id"] as? Int).map { String($0) } ?? (o["id"] as? String) ?? UUID().uuidString
        let status = o["status"] as? String ?? "PENDING"
        let price: Double = {
            if let d = o["offerPrice"] as? Double { return d }
            if let n = o["offerPrice"] as? NSNumber { return n.doubleValue }
            if let d = o["offer_price"] as? Double { return d }
            return 0
        }()
        let createdAt: Date? = {
            if let ts = o["createdAt"] as? TimeInterval { return Date(timeIntervalSince1970: ts) }
            if let ts = o["created_at"] as? Double { return Date(timeIntervalSince1970: ts) }
            if let n = o["createdAt"] as? NSNumber { return Date(timeIntervalSince1970: n.doubleValue) }
            return nil
        }()
        // Backend sends senderUsername/sender_username in nested offer for counter attribution; prefer over buyer (buyer stays original purchaser).
        let senderFromOffer = (o["senderUsername"] as? String) ?? (o["sender_username"] as? String)
        let rawBuyerAccount = parseOfferUser(o["buyer"] as? [String: Any])
        let financialBuyerUsername: String? = {
            let t = rawBuyerAccount?.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? nil : t
        }()
        let buyer: OfferInfo.OfferUser? = {
            if let s = senderFromOffer, !s.trimmingCharacters(in: .whitespaces).isEmpty {
                return OfferInfo.OfferUser(username: s, profilePictureUrl: rawBuyerAccount?.profilePictureUrl)
            }
            return rawBuyerAccount
        }()
        let products = (o["products"] as? [[String: Any]])?.compactMap { parseOfferProduct($0) }
        let updatedBy = (o["updatedBy"] as? String) ?? (o["updated_by"] as? String)
        return OfferInfo(id: id, backendId: id, status: status, offerPrice: price, buyer: buyer, products: products, createdAt: createdAt ?? Date(), sentByCurrentUser: false, financialBuyerUsername: financialBuyerUsername, updatedByUsername: updatedBy)
    }

    private func parseOfferUser(_ j: [String: Any]?) -> OfferInfo.OfferUser? {
        guard let j = j else { return nil }
        return OfferInfo.OfferUser(
            username: j["username"] as? String,
            profilePictureUrl: j["profilePictureUrl"] as? String ?? j["profile_picture_url"] as? String
        )
    }

    private func parseOfferProduct(_ j: [String: Any]) -> OfferInfo.OfferProduct? {
        let id = (j["id"] as? Int).map { String($0) } ?? j["id"] as? String
        return OfferInfo.OfferProduct(
            id: id,
            name: j["name"] as? String,
            seller: parseOfferUser(j["seller"] as? [String: Any])
        )
    }
}
