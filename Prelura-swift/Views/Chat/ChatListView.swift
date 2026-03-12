import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var tabCoordinator: TabCoordinator
    @StateObject private var chatService: ChatService
    @State private var conversations: [Conversation] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var scrollPosition: String? = "inbox_top"

    init(tabCoordinator: TabCoordinator) {
        self.tabCoordinator = tabCoordinator
        _chatService = StateObject(wrappedValue: ChatService())
    }
    
    var body: some View {
        Group {
            if isLoading && conversations.isEmpty {
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
                                NavigationLink(value: AppRoute.conversation(conversation)) {
                                    ChatRowView(conversation: conversation)
                                }
                                .id(index == 0 ? "inbox_top" : conversation.id)
                                .listRowBackground(Theme.Colors.background)
                                .listRowInsets(EdgeInsets(top: 8, leading: Theme.Spacing.md, bottom: 8, trailing: Theme.Spacing.md))
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
            if let token = authService.authToken {
                chatService.updateAuthToken(token)
            }
            loadConversations()
        }
        .onChange(of: authService.authToken) { oldValue, newToken in
            chatService.updateAuthToken(newToken)
        }
    }
    
    private var filteredConversations: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return conversations }
        return conversations.filter {
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
        isLoading = true
        conversations = []
        do {
            // Ensure token is up to date
            if let token = authService.authToken {
                chatService.updateAuthToken(token)
            }
            
            let convs = try await chatService.getConversations()
            await MainActor.run {
                self.conversations = convs
                self.errorMessage = nil
                self.isLoading = false
                print("✅ Loaded \(convs.count) conversations")
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                self.conversations = []
                print("❌ Error loading conversations: \(error.localizedDescription)")
            }
        }
    }
}


struct ChatRowView: View {
    let conversation: Conversation
    
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
                
                if let lastMessage = conversation.lastMessage {
                    Text(ChatRowView.previewText(for: lastMessage))
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
        .padding(.vertical, Theme.Spacing.xs)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Human-readable preview for list: parses order_issue/order/offer JSON or returns plain text.
    static func previewText(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return raw.count > 60 ? String(raw.prefix(57)) + "..." : raw
        }
        switch type {
        case "order_issue": return "Order issue"
        case "order": return "Order update"
        case "offer": return "New offer"
        case "sold_confirmation": return "Sold confirmation"
        default: return raw.count > 60 ? String(raw.prefix(57)) + "..." : raw
        }
    }
}

#Preview {
    ChatListView(tabCoordinator: TabCoordinator())
        .preferredColorScheme(.dark)
}
