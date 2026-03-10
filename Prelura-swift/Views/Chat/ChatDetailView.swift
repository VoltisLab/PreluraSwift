import SwiftUI

/// Resolves conversation with seller (existing or new) then shows ChatDetailView. Used when tapping message icon on product detail.
struct ChatWithSellerView: View {
    let seller: User
    let authService: AuthService?
    @State private var resolvedConversation: Conversation?
    @State private var isLoading = true
    @StateObject private var chatService = ChatService()

    var body: some View {
        Group {
            if let conv = resolvedConversation {
                ChatDetailView(conversation: conv)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
            } else {
                ChatDetailView(conversation: Conversation(id: "0", recipient: seller, lastMessage: nil, lastMessageTime: nil, unreadCount: 0))
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if let token = authService?.authToken {
                chatService.updateAuthToken(token)
            }
            Task {
                await resolveConversation()
            }
        }
    }

    private func resolveConversation() async {
        do {
            let convs = try await chatService.getConversations()
            await MainActor.run {
                let existing = convs.first { $0.recipient.username == seller.username }
                resolvedConversation = existing ?? Conversation(id: "0", recipient: seller, lastMessage: nil, lastMessageTime: nil, unreadCount: 0)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                resolvedConversation = Conversation(id: "0", recipient: seller, lastMessage: nil, lastMessageTime: nil, unreadCount: 0)
                isLoading = false
            }
        }
    }
}

struct ChatDetailView: View {
    let conversation: Conversation
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatService = ChatService()
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var isLoading: Bool = false

    private var recipientTitle: String {
        conversation.recipient.displayName.isEmpty ? conversation.recipient.username : conversation.recipient.displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header (same position as all app bar icons/back buttons)
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Theme.primaryColor)
                        .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text(recipientTitle)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                NavigationLink(destination: OrderHelpView(orderId: nil, conversationId: conversation.id)) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.primaryColor)
                        .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.AppBar.horizontalPadding)
            .padding(.vertical, Theme.AppBar.verticalPadding)
            .background(Theme.Colors.background)

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message, isCurrentUser: message.senderUsername == authService.username)
                                .id(message.id)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Type a message...", text: $newMessage)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(20)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.primaryColor)
                }
                .disabled(newMessage.isEmpty || isLoading)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.background)
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            loadMessages()
        }
    }
    
    private func loadMessages() {
        isLoading = true
        
        Task {
            do {
                let msgs = try await chatService.getMessages(conversationId: conversation.id)
                self.messages = msgs
                self.isLoading = false
            } catch {
                self.isLoading = false
                // Fallback to sample messages
                self.messages = Message.sampleMessages
            }
        }
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        
        // For now, just add locally
        // In a real implementation, you'd send via GraphQL mutation
        let message = Message(
            senderUsername: authService.username ?? "You",
            content: newMessage
        )
        messages.append(message)
        newMessage = ""
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                Text(message.content)
                    .font(Theme.Typography.body)
                    .foregroundColor(isCurrentUser ? .white : Theme.Colors.primaryText)
                    .padding(Theme.Spacing.md)
                    .background(
                        isCurrentUser ?
                        LinearGradient(
                            colors: [Theme.primaryColor, Theme.primaryColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Theme.Colors.secondaryBackground, Theme.Colors.secondaryBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                
                Text(message.formattedTimestamp)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isCurrentUser ? .trailing : .leading)
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationView {
        ChatDetailView(conversation: Conversation(
            id: "1",
            recipient: User.sampleUser,
            lastMessage: "Hello!",
            lastMessageTime: Date(),
            unreadCount: 0
        ))
    }
    .preferredColorScheme(.dark)
}
