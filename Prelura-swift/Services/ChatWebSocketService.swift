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
    /// Called when connection state changes (e.g. for UI indicator).
    var onConnectionStateChanged: (@MainActor (Bool) -> Void)?

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

    private func handleReceivedString(_ text: String) async {
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return }
        let type = json["type"] as? String
        if type == "order_issue_created" || type == "order_status_event" {
            return
        }
        if json["is_typing"] != nil {
            return
        }
        // Django backend sends offer_status_event with nested `offer` + sender_username (see prelura-app offer_utils).
        if type == "offer_status_event" {
            let convId = (json["conversationId"] as? String) ?? (json["conversation_id"] as? String)
            let senderUsername = (json["senderUsername"] as? String)
                ?? (json["sender_username"] as? String)
                ?? (json["senderName"] as? String)
                ?? (json["sender_name"] as? String)
            let offerJson = json["offer"] as? [String: Any]
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
        return Message(
            id: uuid,
            senderUsername: senderName,
            content: text,
            timestamp: createdAt,
            type: messageType,
            orderID: itemId,
            thumbnailURL: nil
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
        let buyer = parseOfferUser(o["buyer"] as? [String: Any])
        let products = (o["products"] as? [[String: Any]])?.compactMap { parseOfferProduct($0) }
        return OfferInfo(id: id, backendId: id, status: status, offerPrice: price, buyer: buyer, products: products, createdAt: createdAt ?? Date(), sentByCurrentUser: false) // temporary placeholder (DO NOT TRUST THIS)
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
