import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var chatService: ChatService
    @State private var conversations: [Conversation] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    init() {
        // Initialize ChatService - it will load token from UserDefaults
        _chatService = StateObject(wrappedValue: ChatService())
    }
    
    var body: some View {
        Group {
            if isLoading && conversations.isEmpty {
                InboxShimmerView()
                    .navigationTitle("Messages")
                    .navigationBarTitleDisplayMode(.inline)
            } else if conversations.isEmpty && !isLoading {
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
                    if errorMessage != nil {
                        PrimaryGlassButton("Retry", action: {
                            errorMessage = nil
                            loadConversations()
                        })
                        .frame(maxWidth: 200)
                        .padding(.top, Theme.Spacing.sm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.background)
                .navigationTitle("Messages")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                VStack(spacing: 0) {
                    DiscoverSearchField(
                        text: $searchText,
                        placeholder: "Search conversations",
                        topPadding: Theme.Spacing.xs
                    )
                    .padding(.trailing, Theme.Spacing.sm)

                    List {
                        ForEach(filteredConversations, id: \.id) { conversation in
                            NavigationLink(value: AppRoute.conversation(conversation)) {
                                ChatRowView(conversation: conversation)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                .background(Theme.Colors.background)
                .navigationTitle("Messages")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable {
                    await loadConversationsAsync()
                }
            }
        }
        .onAppear {
            // Update token before loading
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
                    Text(lastMessage)
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
}

#Preview {
    ChatListView()
        .preferredColorScheme(.dark)
}
