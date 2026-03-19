import Foundation
import SwiftUI
import Combine

@MainActor
class InboxViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let chatService = ChatService()

    init() {}

    func updateAuthToken(_ token: String?) {
        chatService.updateAuthToken(token)
    }

    /// Prefetch conversations in the background (e.g. from MainTabView.onAppear). Safe to call when already loading.
    func prefetch() {
        guard !isLoading, conversations.isEmpty else { return }
        Task { await loadConversationsAsync(preview: nil) }
    }

    /// Full refresh. Call from Inbox when user pulls to refresh or first appears with no data.
    func refresh() {
        Task { await loadConversationsAsync(preview: nil) }
    }

    /// Load conversations from API. Merges in existing conversations not in API response; applies optional preview for one conversation.
    func loadConversationsAsync(preview: (id: String, text: String, date: Date)?) async {
        let hadConversations = !conversations.isEmpty
        let existingToMerge = conversations
        isLoading = true
        if !hadConversations { conversations = [] }
        do {
            let convs = try await chatService.getConversations()
            var list = convs
            let apiIds = Set(list.map(\.id))
            for existing in existingToMerge where !apiIds.contains(existing.id) {
                list.append(existing)
            }
            if let preview = preview, let idx = list.firstIndex(where: { $0.id == preview.id }) {
                let c = list[idx]
                let apiTime = c.lastMessageTime ?? .distantPast
                if apiTime < preview.date {
                    list[idx] = Conversation(
                        id: c.id,
                        recipient: c.recipient,
                        lastMessage: preview.text,
                        lastMessageTime: preview.date,
                        unreadCount: c.unreadCount,
                        offer: c.offer,
                        order: c.order
                    )
                }
            }
            list.sort { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }
            conversations = list
            errorMessage = nil
            isLoading = false
        } catch {
            let isCancelled = (error as? URLError)?.code == .cancelled
                || error.localizedDescription.lowercased().contains("cancelled")
            isLoading = false
            if isCancelled {
                if hadConversations { errorMessage = nil }
                else { errorMessage = nil; conversations = [] }
            } else {
                errorMessage = error.localizedDescription
                if hadConversations { } else { conversations = [] }
            }
        }
    }

    /// Update one conversation's last message preview (e.g. after sending).
    func updatePreview(conversationId: String, text: String, date: Date) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let c = conversations[idx]
        conversations[idx] = Conversation(
            id: c.id,
            recipient: c.recipient,
            lastMessage: text,
            lastMessageTime: date,
            unreadCount: c.unreadCount,
            offer: c.offer,
            order: c.order
        )
    }

    /// Insert a conversation at the top (e.g. newly created before API returns it).
    func prependConversation(_ conv: Conversation) {
        var list = conversations
        if list.contains(where: { $0.id == conv.id }) { return }
        list.insert(conv, at: 0)
        list.sort { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }
        conversations = list
    }

    /// Remove a conversation from the list (e.g. after delete).
    func removeConversation(id: String) {
        conversations.removeAll { $0.id == id }
    }

    /// Delete conversation on backend and remove from list.
    func deleteConversation(conversationId: Int) async {
        do {
            try await chatService.deleteConversation(conversationId: conversationId)
            removeConversation(id: String(conversationId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
