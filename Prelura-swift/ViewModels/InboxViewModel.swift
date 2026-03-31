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
            // Counter-offers must not create duplicate chats: backend may return two conversations for same recipient+product; keep one per (recipient, product set) with latest activity.
            list = Self.deduplicateConversations(list)
            if let preview = preview, let idx = list.firstIndex(where: { $0.id == preview.id }) {
                let c = list[idx]
                let apiTime = c.lastMessageTime ?? .distantPast
                // Prefer the newer of API vs local (leaving chat) so the row updates immediately and isn’t stuck on an older offer row.
                if preview.date >= apiTime {
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
            Self.sortConversationsInPlace(&list)
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
        Self.sortConversationsInPlace(&conversations)
    }

    /// Insert a conversation at the top (e.g. newly created before API returns it).
    func prependConversation(_ conv: Conversation) {
        var list = conversations
        if list.contains(where: { $0.id == conv.id }) { return }
        list.insert(conv, at: 0)
        Self.sortConversationsInPlace(&list)
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

    /// Deduplicate so counter-offers don't show as a second chat. For offer conversations: same recipient + same offer product set = one conversation (keep latest by lastMessageTime). Non-offer conversations are left as-is.
    private static func deduplicateConversations(_ list: [Conversation]) -> [Conversation] {
        func key(_ c: Conversation) -> String {
            if let productIds = c.offer?.products?.compactMap(\.id), !productIds.isEmpty {
                return "offer|\(c.recipient.username)|\(productIds.sorted().joined(separator: ","))"
            }
            return "conv|\(c.id)"
        }
        var byKey: [String: Conversation] = [:]
        for c in list {
            let k = key(c)
            let existing = byKey[k]
            let cTime = c.lastMessageTime ?? .distantPast
            let existingTime = existing?.lastMessageTime ?? .distantPast
            if existing == nil {
                byKey[k] = c
            } else if cTime > existingTime {
                byKey[k] = c
            } else if cTime == existingTime, let ex = existing {
                // Same activity time: pick deterministically so list order doesn’t flip when API order changes.
                if c.id < ex.id { byKey[k] = c }
            }
        }
        return Array(byKey.values)
    }

    /// Newest first; tie-break by `id` so rows with identical `lastMessageTime` (e.g. same minute) don’t reorder between refreshes.
    private static func sortConversationsInPlace(_ list: inout [Conversation]) {
        list.sort { a, b in
            let ta = a.lastMessageTime ?? .distantPast
            let tb = b.lastMessageTime ?? .distantPast
            if ta != tb { return ta > tb }
            return a.id < b.id
        }
    }
}
