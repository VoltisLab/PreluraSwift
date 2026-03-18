import SwiftUI

/// Inbox filter from Messages 3-dot menu.
private enum InboxFilter: String, CaseIterable {
    case all = "All"
    case unread = "Unread"
    case read = "Read"
    case archived = "Archive"
}

struct ChatListView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var tabCoordinator: TabCoordinator
    @Binding var path: [AppRoute]
    @StateObject private var chatService: ChatService
    @State private var conversations: [Conversation] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var scrollPosition: String? = "inbox_top"
    /// Inbox filter from 3-dot menu: all, unread, read, archived.
    @State private var inboxFilter: InboxFilter = .all

    init(tabCoordinator: TabCoordinator, path: Binding<[AppRoute]>) {
        self.tabCoordinator = tabCoordinator
        _path = path
        _chatService = StateObject(wrappedValue: ChatService())
    }
    
    var body: some View {
        Group {
            if authService.isGuestMode {
                GuestSignInPromptView()
                    .navigationTitle(L10n.string("Messages"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            } else if isLoading && conversations.isEmpty {
                InboxShimmerView()
                    .navigationBarHidden(true)
            } else if conversations.isEmpty && !isLoading {
                ZStack(alignment: .bottom) {
                    VStack(spacing: Theme.Spacing.lg) {
                        Image(systemName: errorMessage != nil ? "exclamationmark.triangle" : "message")
                            .font(.system(size: 60))
                            .foregroundColor(errorMessage != nil ? Theme.primaryColor : Theme.Colors.secondaryText)
                        Text(errorMessage != nil ? "Couldn't load conversations" : "No conversations yet")
                            .font(Theme.Typography.title3)
                            .foregroundColor(Theme.Colors.primaryText)
                            .multilineTextAlignment(.center)
                        if let error = errorMessage, !error.isEmpty {
                            Text(error)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
                    .padding(.bottom, errorMessage != nil ? 100 : 0)

                    if errorMessage != nil {
                        PrimaryButtonBar {
                            PrimaryGlassButton("Retry", action: {
                                errorMessage = nil
                                loadConversations()
                            })
                        }
                    }
                }
                .navigationTitle(L10n.string("Messages"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            } else {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        DiscoverSearchField(
                            text: $searchText,
                            placeholder: L10n.string("Search conversations"),
                            topPadding: Theme.Spacing.xs
                        )

                        List {
                            ForEach(Array(filteredConversations.enumerated()), id: \.element.id) { index, conversation in
                                Button(action: { path.append(AppRoute.conversation(conversation)) }) {
                                    ChatRowView(conversation: conversation, currentUsername: authService.username)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(index == 0 ? "inbox_top" : conversation.id)
                                .listRowBackground(Theme.Colors.background)
                                .listRowInsets(EdgeInsets(top: 8, leading: Theme.Spacing.md, bottom: 8, trailing: Theme.Spacing.md))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive, action: { deleteConversation(conversation) }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .navigationLinkIndicatorVisibility(.hidden)
                        .scrollPosition(id: $scrollPosition, anchor: .top)
                        .onAppear {
                            tabCoordinator.reportAtTop(tab: 3, isAtTop: filteredConversations.isEmpty || scrollPosition == "inbox_top")
                            tabCoordinator.registerScrollToTop(tab: 3) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("inbox_top", anchor: .top)
                                }
                            }
                            tabCoordinator.registerRefresh(tab: 3) {
                                Task { await loadConversationsAsync() }
                            }
                        }
                    }
                    .background(Theme.Colors.background)
                    .navigationTitle(L10n.string("Messages"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Theme.Colors.background, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button(L10n.string("All")) { inboxFilter = .all }
                                Button(L10n.string("Archive")) { inboxFilter = .archived }
                                Button(L10n.string("Unread")) { inboxFilter = .unread }
                                Button(L10n.string("Read")) { inboxFilter = .read }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                        }
                    }
                    .refreshable {
                        await loadConversationsAsync()
                    }
                }
                .onChange(of: scrollPosition) { _, new in
                    tabCoordinator.reportAtTop(tab: 3, isAtTop: new == "inbox_top")
                }
                .onChange(of: filteredConversations.isEmpty) { _, isEmpty in
                    if isEmpty { tabCoordinator.reportAtTop(tab: 3, isAtTop: true) }
                }
            }
        }
        .onAppear {
            tabCoordinator.reportAtTop(tab: 3, isAtTop: true)
            tabCoordinator.registerScrollToTop(tab: 3) { }
            tabCoordinator.registerRefresh(tab: 3) {
                Task { await loadConversationsAsync() }
            }
            if path.isEmpty, let preview = tabCoordinator.lastMessagePreviewForConversation,
               let idx = conversations.firstIndex(where: { $0.id == preview.id }) {
                let c = conversations[idx]
                conversations[idx] = Conversation(
                    id: c.id,
                    recipient: c.recipient,
                    lastMessage: preview.text,
                    lastMessageTime: preview.date,
                    unreadCount: c.unreadCount,
                    offer: c.offer,
                    order: c.order
                )
                tabCoordinator.lastMessagePreviewForConversation = nil
            }
            if let conv = tabCoordinator.pendingOpenConversation {
                tabCoordinator.pendingOpenConversation = nil
                DispatchQueue.main.async { path = [.conversation(conv)] }
            }
            guard !authService.isGuestMode else { return }
            if let token = authService.authToken {
                chatService.updateAuthToken(token)
            }
            if conversations.isEmpty && !isLoading {
                loadConversations()
            }
        }
        .onChange(of: path.count) { oldCount, newCount in
            if oldCount > 0, newCount == 0, !authService.isGuestMode {
                if let preview = tabCoordinator.lastMessagePreviewForConversation,
                   let idx = conversations.firstIndex(where: { $0.id == preview.id }) {
                    let c = conversations[idx]
                    conversations[idx] = Conversation(
                        id: c.id,
                        recipient: c.recipient,
                        lastMessage: preview.text,
                        lastMessageTime: preview.date,
                        unreadCount: c.unreadCount,
                        offer: c.offer,
                        order: c.order
                    )
                    tabCoordinator.lastMessagePreviewForConversation = nil
                }
                Task { await loadConversationsAsync() }
            }
        }
        .onChange(of: tabCoordinator.pendingOpenConversation) { _, pending in
            guard let conv = pending else { return }
            tabCoordinator.pendingOpenConversation = nil
            Task {
                await loadConversationsAsync()
                await MainActor.run {
                    // If the conversation we're opening isn't in the refetched list (e.g. newly created by createChat, backend cache), add it so it appears when user backs out.
                    if !conversations.contains(where: { $0.id == conv.id }) {
                        var list = conversations
                        let inserted = Conversation(
                            id: conv.id,
                            recipient: conv.recipient,
                            lastMessage: conv.lastMessage,
                            lastMessageTime: conv.lastMessageTime ?? Date(),
                            unreadCount: conv.unreadCount,
                            offer: conv.offer,
                            order: conv.order
                        )
                        list.insert(inserted, at: 0)
                        list.sort { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }
                        conversations = list
                    }
                    path = [.conversation(conv)]
                }
            }
        }
        .onChange(of: authService.authToken) { oldValue, newToken in
            chatService.updateAuthToken(newToken)
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        guard let convId = Int(conversation.id) else { return }
        Task {
            do {
                try await chatService.deleteConversation(conversationId: convId)
                await MainActor.run {
                    conversations.removeAll { $0.id == conversation.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private var filteredConversations: [Conversation] {
        var list = conversations
        switch inboxFilter {
        case .all: break
        case .unread: list = list.filter { $0.unreadCount > 0 }
        case .read: list = list.filter { $0.unreadCount == 0 }
        case .archived: list = [] // No backend archive yet; show empty
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return list }
        return list.filter {
            $0.recipient.username.lowercased().contains(query)
                || ($0.recipient.displayName.isEmpty ? false : $0.recipient.displayName.lowercased().contains(query))
                || ($0.lastMessage?.lowercased().contains(query) ?? false)
        }
    }

    private func loadConversations() {
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadConversationsAsync()
        }
    }
    
    private func loadConversationsAsync() async {
        let hadConversations = !conversations.isEmpty
        isLoading = true
        if !hadConversations { conversations = [] }
        do {
            // Ensure token is up to date
            if let token = authService.authToken {
                chatService.updateAuthToken(token)
            }
            
            let convs = try await chatService.getConversations()
            await MainActor.run {
                var list = convs
                // Keep any conversation from current list that isn't in API response (e.g. newly created after order, not yet returned by backend/cache) so it stays visible when user backs out.
                let apiIds = Set(list.map(\.id))
                for existing in self.conversations where !apiIds.contains(existing.id) {
                    list.append(existing)
                }
                // When we just left a chat with "Order confirmed", don't overwrite that row with stale API
                // data (older lastMessageTime). Update the row's preview only; do NOT re-sort the list so
                // the conversation that has the order (first by last_modified from API) stays at the top.
                if let preview = self.tabCoordinator.lastMessagePreviewForConversation,
                   let idx = list.firstIndex(where: { $0.id == preview.id }) {
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
                    self.tabCoordinator.lastMessagePreviewForConversation = nil
                }
                // Always show latest first: sort by last message/order time (backend order_by is last_modified which can differ).
                list.sort { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }
                self.conversations = list
                self.errorMessage = nil
                self.isLoading = false
                print("✅ Loaded \(list.count) conversations")
            }
        } catch {
            let isCancelled = (error as? URLError)?.code == .cancelled
                || error.localizedDescription.lowercased().contains("cancelled")
            await MainActor.run {
                self.isLoading = false
                if isCancelled {
                    // Don't show error for pull-to-refresh or task cancellation; keep existing list
                    if hadConversations { self.errorMessage = nil }
                    else { self.errorMessage = nil; self.conversations = [] }
                } else {
                    self.errorMessage = error.localizedDescription
                    self.conversations = hadConversations ? self.conversations : []
                }
                if !isCancelled { print("❌ Error loading conversations: \(error.localizedDescription)") }
            }
        }
    }
}


struct ChatRowView: View {
    let conversation: Conversation
    var currentUsername: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            if let avatarURL = conversation.recipient.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Theme.primaryColor)
                        .overlay(
                            Text(String(conversation.recipient.username.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.primaryColor)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(conversation.recipient.username.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(conversation.recipient.displayName.isEmpty ? conversation.recipient.username : conversation.recipient.displayName)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let time = conversation.lastMessageTime {
                        Text(formatTime(time))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                
                if let preview = ChatRowView.previewText(for: conversation.lastMessage, conversation: conversation, currentUsername: currentUsername) {
                    Text(preview)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
            
            // Unread badge
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.primaryColor)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.xs)
    }
    
    private func formatTime(_ date: Date) -> String {
        let now = Date()
        if now.timeIntervalSince(date) < 60 {
            return L10n.string("Just now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// Human-readable preview for list. When current user sent the offer, show "You sent an offer". When there's an order, show order summary.
    static func previewText(for raw: String?, conversation: Conversation, currentUsername: String?) -> String? {
        guard let raw = raw, !raw.isEmpty else {
            if conversation.offer != nil, conversation.offer?.buyer?.username == currentUsername {
                return "You sent an offer"
            }
            if let order = conversation.order {
                return String(format: "Order • £%.2f", order.total)
            }
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("offer_id") || (trimmed.hasPrefix("{") && (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) as? [String: Any])?["offer_id"] != nil) {
            return conversation.offer?.buyer?.username == currentUsername ? "You sent an offer" : "Offer"
        }
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return raw.count > 60 ? String(raw.prefix(57)) + "..." : raw
        }
        switch type {
        case "order_issue": return "Order issue"
        case "order": return "Order update"
        case "offer": return conversation.offer?.buyer?.username == currentUsername ? "You sent an offer" : "New offer"
        case "sold_confirmation": return "Order confirmed"
        default: return raw.count > 60 ? String(raw.prefix(57)) + "..." : raw
        }
    }
}

#Preview {
    ChatListView(tabCoordinator: TabCoordinator(), path: .constant([]))
        .preferredColorScheme(.dark)
}
