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
    @State private var displayedConversation: Conversation
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @FocusState private var isMessageFieldFocused: Bool
    @State private var isLoading: Bool = false
    @State private var webSocket: ChatWebSocketService?
    @State private var pendingMessageUUID: String?
    @State private var showCounterOfferSheet = false
    @State private var isRespondingToOffer = false
    @State private var offerError: String?
    @State private var showPayNowCover = false
    @State private var payNowProducts: [Item] = []
    @State private var payNowTotalPrice: Double = 0

    private let productService = ProductService()

    init(conversation: Conversation, item: Item? = nil) {
        self.conversation = conversation
        self.item = item
        _displayedConversation = State(initialValue: conversation)
    }

    private var recipientTitle: String {
        !displayedConversation.recipient.displayName.isEmpty ? displayedConversation.recipient.displayName : displayedConversation.recipient.username
    }

    /// Messages to show: in offer conversations hide raw offer payload bubbles (offer card represents the offer).
    private var displayedMessages: [Message] {
        guard displayedConversation.offer != nil else { return messages }
        return messages.filter { !$0.isOfferContent }
    }

    private var isSeller: Bool {
        guard let offer = displayedConversation.offer, let sellerUsername = offer.products?.first?.seller?.username else { return false }
        return authService.username == sellerUsername
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

    /// True when this message is from the other user and is the first in a run (show avatar). Also show avatar after a sold-confirmation banner.
    private func showAvatarForMessage(at index: Int) -> Bool {
        let list = displayedMessages
        guard index < list.count else { return false }
        let msg = list[index]
        let isOther = msg.senderUsername != authService.username
        guard isOther else { return false }
        if index == 0 { return true }
        let prev = list[index - 1]
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
            if let offer = displayedConversation.offer {
                OfferCardView(
                    offer: offer,
                    currentUsername: authService.username,
                    isSeller: isSeller,
                    isResponding: isRespondingToOffer,
                    errorMessage: offerError,
                    onAccept: { await handleRespondToOffer(action: "ACCEPT") },
                    onDecline: { await handleRespondToOffer(action: "REJECT") },
                    onSendNewOffer: { showCounterOfferSheet = true },
                    onPayNow: { presentPayNow() }
                )
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
                        ForEach(Array(displayedMessages.enumerated()), id: \.element.id) { index, message in
                            if message.isSoldConfirmation {
                                SoldConfirmationBannerView(
                                    message: message,
                                    isSeller: message.senderUsername != authService.username,
                                    conversationId: displayedConversation.id
                                )
                                .id(message.id)
                            } else {
                                let isCurrentUser = message.senderUsername == authService.username
                                let showAvatar = showAvatarForMessage(at: index)
                                MessageBubbleView(
                                    message: message,
                                    isCurrentUser: isCurrentUser,
                                    showAvatar: showAvatar,
                                    avatarURL: showAvatar ? displayedConversation.recipient.avatarURL : nil,
                                    recipientUsername: displayedConversation.recipient.username
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
                .onChange(of: displayedMessages.count) { _, _ in
                    if let lastMessage = displayedMessages.last {
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
                NavigationLink(destination: UserProfileView(seller: displayedConversation.recipient, authService: authService)) {
                    HStack(spacing: Theme.Spacing.sm) {
                        chatTitleAvatar(url: displayedConversation.recipient.avatarURL, username: displayedConversation.recipient.username)
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
                NavigationLink(destination: OrderHelpView(orderId: nil, conversationId: displayedConversation.id)) {
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
        .sheet(isPresented: $showCounterOfferSheet) {
            CounterOfferSheet(
                offer: displayedConversation.offer!,
                onSubmit: { newPrice in
                    showCounterOfferSheet = false
                    Task { await handleRespondToOffer(action: "COUNTER", offerPrice: newPrice) }
                },
                onCancel: { showCounterOfferSheet = false }
            )
        }
        .fullScreenCover(isPresented: $showPayNowCover) {
            NavigationView {
                PaymentView(products: payNowProducts, totalPrice: payNowTotalPrice, customOffer: true)
                    .environmentObject(authService)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") { showPayNowCover = false }
                        }
                    }
            }
        }
        .onAppear {
            loadMessages()
            connectWebSocket()
        }
        .onDisappear {
            webSocket?.disconnect()
            webSocket = nil
        }
    }

    private func handleRespondToOffer(action: String, offerPrice: Double? = nil) async {
        guard let offer = displayedConversation.offer, let offerId = offer.offerIdInt else { return }
        await MainActor.run {
            isRespondingToOffer = true
            offerError = nil
        }
        do {
            try await productService.respondToOffer(action: action, offerId: offerId, offerPrice: offerPrice)
            let convs = try await chatService.getConversations()
            await MainActor.run {
                if let updated = convs.first(where: { $0.id == displayedConversation.id }) {
                    displayedConversation = updated
                }
                isRespondingToOffer = false
                offerError = nil
            }
        } catch {
            await MainActor.run {
                isRespondingToOffer = false
                offerError = error.localizedDescription
            }
        }
    }

    private func presentPayNow() {
        guard let offer = displayedConversation.offer else { return }
        let productIds = offer.products?.compactMap { p -> Int? in
            guard let id = p.id else { return nil }
            return Int(id)
        } ?? []
        guard !productIds.isEmpty else { return }
        Task {
            do {
                var items: [Item] = []
                for id in productIds {
                    if let product = try await productService.getProduct(id: id) {
                        items.append(product)
                    }
                }
                guard !items.isEmpty else {
                    await MainActor.run { offerError = "Could not load product" }
                    return
                }
                let offerPrice = offer.offerPrice
                await MainActor.run {
                    // Present PaymentView via navigation: we need a way to push. Use fullScreenCover with a wrapper that holds PaymentView.
                    // ChatDetailView is inside NavigationStack; we can use .fullScreenCover and present PaymentView there.
                    showPayNowCover = true
                    payNowProducts = items
                    payNowTotalPrice = offerPrice
                }
            } catch {
                await MainActor.run { offerError = error.localizedDescription }
            }
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
        guard displayedConversation.id != "0",
              let token = authService.authToken, !token.isEmpty else { return }
        let ws = ChatWebSocketService(conversationId: displayedConversation.id, token: token)
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
        guard displayedConversation.id != "0" else {
            messages = []
            return
        }
        isLoading = true
        Task {
            do {
                let msgs = try await chatService.getMessages(conversationId: displayedConversation.id)
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
                    _ = try await chatService.sendMessage(conversationId: displayedConversation.id, message: text, messageUuid: messageUUID)
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

// MARK: - Offer card (Flutter OfferFirstCard)

/// Offer card at top of chat when conversation has an offer. Shows offer line, status, and actions: Accept/Decline/Send new offer (seller, pending), Pay now (buyer, accepted), Send new offer (rejected).
struct OfferCardView: View {
    let offer: OfferInfo
    let currentUsername: String?
    let isSeller: Bool
    let isResponding: Bool
    let errorMessage: String?
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    let onSendNewOffer: () -> Void
    let onPayNow: () -> Void

    private var offerLine: String {
        let priceStr = String(format: "£%.2f", offer.offerPrice)
        let isBuyer = offer.buyer?.username == currentUsername
        if isBuyer {
            return "You offered \(priceStr)"
        }
        return "\(offer.buyer?.username ?? "They") offered \(priceStr)"
    }

    private var statusText: String {
        switch (offer.status ?? "").uppercased() {
        case "PENDING": return "Pending"
        case "ACCEPTED": return "Accepted"
        case "REJECTED", "CANCELLED": return "Declined"
        default: return offer.status ?? "Pending"
        }
    }

    private var statusColor: Color {
        switch (offer.status ?? "").uppercased() {
        case "PENDING": return Theme.Colors.secondaryText
        case "ACCEPTED": return .green
        case "REJECTED", "CANCELLED": return .red
        default: return Theme.Colors.secondaryText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(offerLine)
                .font(Theme.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.primaryText)
            Text(statusText)
                .font(Theme.Typography.subheadline)
                .foregroundColor(statusColor)

            if let err = errorMessage, !err.isEmpty {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.red)
            }

            if isSeller && offer.isPending {
                HStack(spacing: Theme.Spacing.sm) {
                    Button(action: { Task { await onAccept() } }) {
                        Text("Accept")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(22)
                    }
                    .disabled(isResponding)
                    Button(action: { Task { await onDecline() } }) {
                        Text("Decline")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            .foregroundColor(Theme.Colors.primaryText)
                            .cornerRadius(22)
                    }
                    .disabled(isResponding)
                    Button(action: onSendNewOffer) {
                        Text("Send new offer")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            .foregroundColor(Theme.Colors.primaryText)
                            .cornerRadius(22)
                    }
                    .disabled(isResponding)
                }
            } else if !isSeller && offer.isAccepted {
                Button(action: onPayNow) {
                    Text("Pay now")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(22)
                }
            } else if offer.isRejected {
                Button(action: onSendNewOffer) {
                    Text("Send new offer")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primaryColor, lineWidth: 1))
                        .foregroundColor(Theme.primaryColor)
                        .cornerRadius(22)
                }
            }

            if isResponding {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
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
    }
}

/// Sheet to enter counter-offer price and submit (respondToOffer COUNTER).
struct CounterOfferSheet: View {
    let offer: OfferInfo
    let onSubmit: (Double) -> Void
    let onCancel: () -> Void

    @State private var priceText = ""
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

    private var priceValue: Double? {
        let cleaned = priceText.replacingOccurrences(of: "£", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private var canSubmit: Bool {
        guard let v = priceValue, v > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Send a new offer")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                TextField("Offer amount (£)", text: $priceText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                HStack(spacing: Theme.Spacing.sm) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Spacer()
                    Button("Send offer") {
                        guard let v = priceValue, canSubmit else { return }
                        isSubmitting = true
                        onSubmit(v)
                        isSubmitting = false
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .foregroundColor(Theme.primaryColor)
                }
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
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
