import SwiftUI

/// Resolves conversation with seller (existing or new) then shows ChatDetailView. Used when tapping message icon on product detail.
/// When opened from product detail, pass `item` so the chat shows the product at the top (Flutter behavior).
struct ChatWithSellerView: View {
    let seller: User
    /// When non-nil, chat shows this product at the top (e.g. when starting conversation from product detail).
    var item: Item? = nil
    let authService: AuthService?
    @State private var resolvedConversation: Conversation?
    @State private var isLoading = true
    @StateObject private var chatService = ChatService()

    var body: some View {
        Group {
            if let conv = resolvedConversation {
                ChatDetailView(conversation: conv, item: item)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
            } else {
                ChatDetailView(conversation: Conversation(id: "0", recipient: seller, lastMessage: nil, lastMessageTime: nil, unreadCount: 0), item: item)
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
            let existing = convs.first { $0.recipient.username == seller.username }
            if let conv = existing {
                await MainActor.run {
                    resolvedConversation = conv
                    isLoading = false
                }
                return
            }
            let newConv = try await chatService.createChat(recipient: seller.username)
            await MainActor.run {
                resolvedConversation = newConv
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
    /// When non-nil, show this product at the top of the chat (Flutter: productId → ProductCard at top).
    var item: Item? = nil
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatService = ChatService()
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @FocusState private var isMessageFieldFocused: Bool
    @State private var isLoading: Bool = false
    @State private var webSocket: ChatWebSocketService?
    /// UUID string for optimistic message so we can replace it when server echoes message_uuid.
    @State private var pendingMessageUUID: String?

    private var recipientTitle: String {
        conversation.recipient.displayName.isEmpty ? conversation.recipient.username : conversation.recipient.displayName
    }

    private var messageInputBar: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            TextField("Type a message...", text: $newMessage)
                .textFieldStyle(.plain)
                .focused($isMessageFieldFocused)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(minHeight: 44)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(isMessageFieldFocused ? Theme.primaryColor : Theme.Colors.glassBorder, lineWidth: isMessageFieldFocused ? 2 : 1)
                )
                .foregroundColor(Theme.Colors.primaryText)
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.Colors.secondaryText : Theme.primaryColor)
            }
            .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let item = item {
                        ChatProductCardView(item: item)
                            .padding(.bottom, Theme.Spacing.xs)
                        Rectangle()
                            .fill(Theme.Colors.glassBorder)
                            .frame(height: 0.5)
                            .padding(.vertical, Theme.Spacing.xs)
                    }
                    ForEach(messages) { message in
                        if message.isSoldConfirmation {
                            SoldConfirmationBannerView(
                                message: message,
                                isSeller: message.senderUsername != authService.username,
                                conversationId: conversation.id
                            )
                            .id(message.id)
                        } else {
                            MessageBubbleView(message: message, isCurrentUser: message.senderUsername == authService.username)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                messageInputBar
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(recipientTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: OrderHelpView(orderId: nil, conversationId: conversation.id)) {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            loadMessages()
            connectWebSocket()
        }
        .onDisappear {
            webSocket?.disconnect()
            webSocket = nil
        }
    }

    private func connectWebSocket() {
        guard conversation.id != "0",
              let token = authService.authToken, !token.isEmpty else { return }
        let ws = ChatWebSocketService(conversationId: conversation.id, token: token)
        ws.onNewMessage = { [self] msg, echoMessageUuid in
            if let pending = pendingMessageUUID, echoMessageUuid == pending,
               let idx = messages.firstIndex(where: { $0.id.uuidString == pending }) {
                messages[idx] = msg
                pendingMessageUUID = nil
                return
            }
            if messages.contains(where: { $0.id == msg.id }) { return }
            messages.append(msg)
        }
        webSocket = ws
        ws.connect()
    }

    private func loadMessages() {
        guard conversation.id != "0" else {
            messages = []
            return
        }
        isLoading = true
        Task {
            do {
                let msgs = try await chatService.getMessages(conversationId: conversation.id)
                await MainActor.run {
                    self.messages = msgs
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.messages = []
                    self.isLoading = false
                }
            }
        }
    }

    private func sendMessage() {
        let text = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newMessage = ""
        let messageUUID = UUID().uuidString
        let optimistic = Message(
            id: UUID(uuidString: messageUUID) ?? UUID(),
            senderUsername: authService.username ?? "You",
            content: text,
            type: "text"
        )
        messages.append(optimistic)
        pendingMessageUUID = messageUUID
        if let ws = webSocket {
            ws.send(message: text, messageUUID: messageUUID)
        } else {
            Task {
                do {
                    _ = try await chatService.sendMessage(conversationId: conversation.id, message: text, messageUuid: messageUUID)
                    await MainActor.run {
                        if let idx = messages.firstIndex(where: { $0.id.uuidString == messageUUID }) {
                            pendingMessageUUID = nil
                        }
                        loadMessages()
                    }
                } catch {
                    await MainActor.run {
                        messages.removeAll { $0.id.uuidString == messageUUID }
                        pendingMessageUUID = nil
                    }
                }
            }
        }
    }
}

/// Product card shown at top of chat when conversation was started from product detail (Flutter ProductCard).
struct ChatProductCardView: View {
    let item: Item

    var body: some View {
        NavigationLink(destination: ItemDetailView(item: item)) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Group {
                    if let urlString = item.imageURLs.first, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                Rectangle()
                                    .fill(Theme.Colors.secondaryBackground)
                                    .overlay(Image(systemName: "photo").foregroundColor(Theme.Colors.secondaryText))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Theme.Colors.secondaryBackground)
                            .overlay(Image(systemName: "photo").foregroundColor(Theme.Colors.secondaryText))
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(item.formattedPrice)
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

/// Banner for sold_confirmation messages (matches Flutter SoldConfirmationBanner).
struct SoldConfirmationBannerView: View {
    let message: Message
    let isSeller: Bool
    var conversationId: String = ""

    private var displayText: String {
        guard let data = message.soldConfirmationData else {
            return message.displayContent
        }
        let price = data.productPrice ?? data.buyerSubtotal ?? "0"
        return "SOLD! 💰\nYour item sold for £\(price)! 📦"
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(displayText)
                    .font(Theme.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if isSeller {
                    Button(action: { /* TODO: navigate to shipping confirmation */ }) {
                        Text("I've shipped the item")
                            .font(Theme.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .background(Theme.primaryColor)
                    .cornerRadius(24)
                }
                HStack {
                    Spacer(minLength: 0)
                    NavigationLink(destination: OrderHelpView(orderId: nil, conversationId: conversationId.isEmpty ? nil : conversationId)) {
                        Text("Report an issue")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.primaryColor)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
            Text(message.formattedTimestamp)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(.vertical, 2)
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool

    private var bubbleMaxWidth: CGFloat { UIScreen.main.bounds.width * 0.78 }

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
            if isCurrentUser { Spacer(minLength: Theme.Spacing.lg) }
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.displayContent)
                    .font(Theme.Typography.body)
                    .foregroundColor(isCurrentUser ? .white : Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        isCurrentUser
                            ? LinearGradient(
                                colors: [Theme.primaryColor, Theme.primaryColor.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Theme.Colors.secondaryBackground, Theme.Colors.secondaryBackground],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .cornerRadius(18)
                Text(message.formattedTimestamp)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: bubbleMaxWidth, alignment: isCurrentUser ? .trailing : .leading)
            if !isCurrentUser { Spacer(minLength: Theme.Spacing.lg) }
        }
        .padding(.vertical, 2)
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
