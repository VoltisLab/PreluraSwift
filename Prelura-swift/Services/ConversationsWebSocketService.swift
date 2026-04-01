import Foundation

/// Subscribes to Django `ws/conversations/` so the inbox can refresh when the server broadcasts `update_conversation`
/// (new messages, and other flows that ping the `conversations` channel). Per-room `ws/chat/<id>/` only runs while a thread is open.
final class ConversationsWebSocketService: NSObject, @unchecked Sendable, URLSessionWebSocketDelegate {
    private let token: String
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var receiveTask: Task<Void, Error>?
    private var didManualClose = false
    private(set) var isConnected: Bool = false

    /// Server sent `update_conversation` after `update_conversations` fan-out — refetch GraphQL list for full offer/order rows.
    var onShouldRefreshConversationsList: (@MainActor () -> Void)?

    init(token: String) {
        self.token = token
    }

    func connect() {
        guard let url = URL(string: Constants.conversationsWebSocketURL) else { return }
        didManualClose = false
        isConnected = false
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        task = session.webSocketTask(with: request)
        task?.resume()
        receiveTask = Task { await receiveLoop() }
    }

    func disconnect() {
        didManualClose = true
        isConnected = false
        receiveTask?.cancel()
        receiveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func receiveLoop() async {
        guard let task else { return }
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
                    print("ConversationsWebSocket receive error: \(error)")
                }
                break
            }
        }
    }

    private func handleReceivedString(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        let t = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Backend: ConversationsConsumer.update_conversations → send_json type update_conversation
        if t == "update_conversation" {
            await MainActor.run {
                onShouldRefreshConversationsList?()
            }
        }
        // typing_status: list could show indicators later; no list refetch.
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            isConnected = true
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            if !didManualClose {
                isConnected = false
            }
        }
    }
}
