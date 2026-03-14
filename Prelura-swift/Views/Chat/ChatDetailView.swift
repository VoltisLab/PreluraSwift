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

    /// True when this message is from the other user and is the first in a run (show avatar). Also show avatar after a sold-confirmation banner so "Order issue" etc. have the avatar.
    private func showAvatarForMessage(at index: Int) -> Bool {
        let msg = messages[index]
        let isOther = msg.senderUsername != authService.username
        guard isOther else { return false }
        if index == 0 { return true }
        let prev = messages[index - 1]
        if prev.isSoldConfirmation { return true }
        return prev.senderUsername == authService.username
    }

    private static let chatAvatarSize: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            if let item = item {
                ChatProductCardView(item: item)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.background)
                Rectangle()
                    .fill(Theme.Colors.glassBorder)
                    .frame(height: 0.5)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            if message.isSoldConfirmation {
                                SoldConfirmationBannerView(
                                    message: message,
                                    isSeller: message.senderUsername != authService.username,
                                    conversationId: conversation.id
                                )
                                .id(message.id)
                            } else {
                                let isCurrentUser = message.senderUsername == authService.username
                                let showAvatar = showAvatarForMessage(at: index)
                                MessageBubbleView(
                                    message: message,
                                    isCurrentUser: isCurrentUser,
                                    showAvatar: showAvatar,
                                    avatarURL: showAvatar ? conversation.recipient.avatarURL : nil,
                                    recipientUsername: conversation.recipient.username
                                )
                                .id(message.id)
                                .contextMenu {
                                    if message.senderUsername == authService.username, let backendId = message.backendId {
                                        Button(role: .destructive, action: { deleteMessage(message) }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavigationLink(destination: UserProfileView(seller: conversation.recipient, authService: authService)) {
                    HStack(spacing: Theme.Spacing.sm) {
                        chatTitleAvatar(url: conversation.recipient.avatarURL, username: conversation.recipient.username)
                        Text(recipientTitle)
                            .font(.headline)
                            .foregroundColor(Theme.Colors.primaryText)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: OrderHelpView(orderId: nil, conversationId: conversation.id)) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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

    private func chatTitleAvatar(url: String?, username: String) -> some View {
        Group {
            if let u = url, !u.isEmpty, let parsed = URL(string: u) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        chatAvatarPlaceholder(username: username)
                    case .empty:
                        chatAvatarPlaceholder(username: username)
                    @unknown default:
                        chatAvatarPlaceholder(username: username)
                    }
                }
            } else {
                chatAvatarPlaceholder(username: username)
            }
        }
        .frame(width: Self.chatAvatarSize, height: Self.chatAvatarSize)
        .clipShape(Circle())
    }

    private func chatAvatarPlaceholder(username: String) -> some View {
        Circle()
            .fill(Theme.Colors.secondaryBackground)
            .overlay(
                Text(String((username.isEmpty ? "?" : username).prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText)
            )
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
                messages.sort { $0.timestamp < $1.timestamp }
                return
            }
            if messages.contains(where: { $0.id == msg.id }) { return }
            messages.append(msg)
            messages.sort { $0.timestamp < $1.timestamp }
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
                // Mark as read: messages from the other party (IDs we have from backend)
                let idsToMarkRead = msgs
                    .filter { $0.senderUsername != authService.username }
                    .compactMap(\.backendId)
                if !idsToMarkRead.isEmpty {
                    _ = try? await chatService.readMessages(messageIds: idsToMarkRead)
                }
            } catch {
                await MainActor.run {
                    self.messages = []
                    self.isLoading = false
                }
            }
        }
    }

    private func deleteMessage(_ message: Message) {
        guard let backendId = message.backendId else { return }
        Task {
            do {
                try await chatService.deleteMessage(messageId: backendId)
                await MainActor.run {
                    messages.removeAll { $0.id == message.id }
                }
            } catch {
                // Best-effort; could show an alert
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
    /// When true and not current user, show avatar to the left of the bubble (first in group).
    var showAvatar: Bool = false
    var avatarURL: String? = nil
    var recipientUsername: String = ""

    private var bubbleMaxWidth: CGFloat { UIScreen.main.bounds.width * 0.78 }
    private static let messageAvatarSize: CGFloat = 28
    /// Vertical offset so the avatar is centered with a single-line bubble. This position is kept for multi-line bubbles (avatar does not re-center).
    private static let avatarTopOffsetForSingleLineCenter: CGFloat = 4

    private var messageAvatarView: some View {
        Group {
            if let u = avatarURL, !u.isEmpty, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: messageAvatarPlaceholder
                    }
                }
            } else {
                messageAvatarPlaceholder
            }
        }
        .frame(width: Self.messageAvatarSize, height: Self.messageAvatarSize)
        .clipShape(Circle())
    }

    private var messageAvatarPlaceholder: some View {
        Circle()
            .fill(Theme.Colors.tertiaryBackground)
            .overlay(
                Text(String((recipientUsername.isEmpty ? "?" : recipientUsername).prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText)
            )
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            if isCurrentUser { Spacer(minLength: Theme.Spacing.lg) }
            if !isCurrentUser {
                Group {
                    if showAvatar {
                        messageAvatarView
                            .offset(y: Self.avatarTopOffsetForSingleLineCenter)
                    } else {
                        Color.clear
                            .frame(width: Self.messageAvatarSize, height: Self.messageAvatarSize)
                    }
                }
            }
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.displayContentForBubble(isFromCurrentUser: isCurrentUser))
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
