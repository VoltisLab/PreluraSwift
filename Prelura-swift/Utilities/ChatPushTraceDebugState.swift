import Combine
import Foundation

/// Debug-only: tracks chat WebSocket presence for DM troubleshooting.
@MainActor
final class ChatPushTraceDebugState: ObservableObject {
    static let shared = ChatPushTraceDebugState()

    @Published private(set) var activeConversationId: String?
    @Published private(set) var socketConnected: Bool
    @Published private(set) var lastConnectAt: Date?
    @Published private(set) var lastDisconnectAt: Date?
    @Published private(set) var lastDisconnectReason: String?

    private init() {
        activeConversationId = nil
        socketConnected = false
        lastConnectAt = nil
        lastDisconnectAt = nil
        lastDisconnectReason = nil
    }

    func markSocketConnected(conversationId: String) {
        guard conversationId != "0" else { return }
        activeConversationId = conversationId
        socketConnected = true
        lastConnectAt = Date()
        NotificationDebugLog.append(
            source: "chat_push",
            message: "WebSocket OPEN conv=\(conversationId)",
            isError: false
        )
    }

    func markSocketDisconnected(conversationId: String, reason: String) {
        lastDisconnectAt = Date()
        lastDisconnectReason = reason
        activeConversationId = nil
        socketConnected = false
        NotificationDebugLog.append(
            source: "chat_push",
            message: "WebSocket CLOSED conv=\(conversationId) — \(reason)",
            isError: false
        )
    }
}
