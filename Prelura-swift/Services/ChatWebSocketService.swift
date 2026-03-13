import Foundation

/// WebSocket client for chat: connect to backend ws, send messages, receive new messages and events.
/// Matches Flutter: wss://prelura.com/ws/chat/{conversationId}/ with Token auth; send {"message", "message_uuid"}; receive new_message events.
final class ChatWebSocketService: NSObject, @unchecked Sendable {
    private let conversationId: String
    private let token: String
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Error>?
    private let baseURL = "wss://prelura.com/ws/chat/"

    /// Called on main actor when a new chat message is received. If server echoes our send, messageUuid is the client UUID we sent.
    var onNewMessage: (@MainActor (Message, String?) -> Void)?
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
        if type == "offer_status_event" || type == "order_issue_created" || type == "order_status_event" {
            return
        }
        if json["is_typing"] != nil {
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
        let itemId = (json["itemId"] as? Int).map { String($0) } ?? (json["item_id"] as? Int).map { String($0) }
        return Message(
            id: uuid,
            senderUsername: senderName,
            content: text,
            timestamp: createdAt,
            type: isItem ? "item" : "text",
            orderID: itemId,
            thumbnailURL: nil
        )
    }
}
