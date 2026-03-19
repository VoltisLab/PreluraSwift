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

/// One item in the chat timeline: message, offer card, or sold event. Sorted by time.
enum ChatItem: Hashable {
    case message(UUID)
    case offer(String)
    case sold(OrderInfo)

    var id: String {
        switch self {
        case .message(let m): return "msg-\(m.uuidString)"
        case .offer(let o): return "offer-\(o)"
        case .sold(let o): return "sold-\(o.id)"
        }
    }

    var isOffer: Bool {
        if case .offer = self { return true }
        return false
    }
    var isSold: Bool {
        if case .sold = self { return true }
        return false
    }
}

struct ChatDetailView: View {
    let conversation: Conversation
    /// When non-nil, show this product at the top of the chat (Flutter: productId → ProductCard at top).
    var item: Item? = nil
    @EnvironmentObject var authService: AuthService
    @Environment(\.optionalTabCoordinator) private var tabCoordinator
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatService = ChatService()
    @State private var displayedConversation: Conversation
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @FocusState private var isMessageFieldFocused: Bool
    @State private var isLoading: Bool = false
    @State private var webSocket: ChatWebSocketService?
    /// Whether the remote participant is currently typing.
    @State private var isOtherUserTyping = false
    /// Last username reported by typing event.
    @State private var typingUsername: String?
    /// Keep typing indicator alive briefly after last event.
    @State private var typingResetTask: Task<Void, Never>?
    /// Debounce outgoing typing notifications.
    @State private var typingSendTask: Task<Void, Never>?
    @State private var didSendTypingStart = false
    @State private var pendingMessageUUID: String?
    @State private var showCounterOfferSheet = false
    /// The specific offer card the user tapped to open the counter sheet.
    @State private var counterTargetOffer: OfferInfo?
    @State private var isRespondingToOffer = false
    @State private var offerError: String?
    @State private var offerModalSubmitting = false
    @State private var showReportUserSheet = false
    private struct PayNowPayload: Identifiable {
        let id = UUID()
        let products: [Item]
        let totalPrice: Double
    }
    @State private var payNowPayload: PayNowPayload?
    /// Fetched product for offer-conversation header (thumbnail + price bar). Cached by product id so we don't refetch.
    @State private var offerProductItem: Item?
    private static var offerProductCache: [Int: Item] = [:]
    /// Fetched product for order-conversation header (sale confirmation bar); enables tap-to-open product. Cached by product id.
    @State private var orderProductItem: Item?
    private static var orderProductCache: [Int: Item] = [:]
    /// Single source of truth for offer cards. UI = source of truth; server used only to seed on load or confirm after send.
    @State private var offers: [OfferInfo] = []
    /// Synthetic "accepted snapshot" suffix used to duplicate an accepted card so it never turns red/declined later.
    private static let acceptedSnapshotBackendIdSuffix = "-accepted-snapshot"
    /// After `getConversationById` completes for this open; until then we avoid seeding from a single inbox `offer` (prevents one-card → full-history flash).
    @State private var hasFinishedInitialConversationFetch = false
    /// Shown when we’re waiting on server `offerHistory` and have no local cache.
    @State private var isLoadingOfferHistory = false
    /// Trigger to force a "scroll to bottom" once when opening a chat.
    @State private var scrollToBottomToken = UUID()
    /// Prevent repeated auto-scrolling while the user is reading older parts of the thread.
    @State private var hasAutoScrolledToBottomForThisChat = false

    private let productService = ProductService()

    /// Cache for re-open: restore offers when returning to chat (API only returns latest).
    private static var offerHistoryCache: [String: [OfferInfo]] = [:]
    private static let offerHistoryUserDefaultsPrefix = "offerHistory_"
    /// Order of items in the chat (message / offer / sold), sorted by date.
    @State private var timelineOrder: [ChatItem] = []
    private static var timelineOrderCache: [String: [ChatItem]] = [:]

    /// Cache key per conversation and current user so switching accounts doesn't show wrong sender.
    private func offerCacheKey(convId: String) -> String {
        "\(convId)_\(authService.username ?? "")"
    }

    private static func persistOfferHistory(key: String, offers: [OfferInfo]) {
        guard let data = try? JSONEncoder().encode(offers) else { return }
        UserDefaults.standard.set(data, forKey: offerHistoryUserDefaultsPrefix + key)
    }

    private static func loadOfferHistory(key: String) -> [OfferInfo]? {
        guard let data = UserDefaults.standard.data(forKey: offerHistoryUserDefaultsPrefix + key),
              let offers = try? JSONDecoder().decode([OfferInfo].self, from: data) else { return nil }
        return offers
    }

    private func hasLocalOfferHistoryCache(convId: String) -> Bool {
        let key = offerCacheKey(convId: convId)
        if let c = Self.offerHistoryCache[key], !c.isEmpty { return true }
        if let p = Self.loadOfferHistory(key: key), !p.isEmpty { return true }
        return false
    }

    /// Reset fetch gate + loader when opening or switching chats (placeholder id `"0"` skips deferral).
    private func refreshOfferHistoryLoadingFlagsForCurrentConversation() {
        let convId = displayedConversation.id
        if convId == "0" {
            hasFinishedInitialConversationFetch = true
            isLoadingOfferHistory = false
            return
        }
        hasFinishedInitialConversationFetch = false
        isLoadingOfferHistory =
            displayedConversation.offer != nil
            && displayedConversation.offerHistory == nil
            && !hasLocalOfferHistoryCache(convId: convId)
    }

    init(conversation: Conversation, item: Item? = nil) {
        self.conversation = conversation
        self.item = item
        _displayedConversation = State(initialValue: conversation)
    }

    private var recipientTitle: String {
        displayedConversation.recipient.username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Messages to show: in offer conversations hide raw offer payload bubbles (offer card represents the offer).
    /// Hide sold_confirmation message bubbles (order is shown by OrderConfirmationCardView banner only).
    private var displayedMessages: [Message] {
        var list = messages.filter { !$0.isSoldConfirmation }
        if displayedConversation.offer != nil {
            list = list.filter { !$0.isOfferContent }
        }
        return list
    }

    private var isSeller: Bool {
        isCurrentUser(username: displayedConversation.offer?.products?.first?.seller?.username)
    }

    private var messageInputBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if isOtherUserTyping {
                HStack(spacing: Theme.Spacing.xs) {
                    TypingDotsView()
                    Text("\((typingUsername?.isEmpty == false ? typingUsername! : displayedConversation.recipient.username)) is typing")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .transition(.opacity)
            }
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
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
    }

    // Payment sheet is presented via `fullScreenCover(item:)` for atomic payload updates.

    /// True when this message is from the other user and is the first in a run (show avatar). Also show avatar after a sold-confirmation banner.
    private func showAvatarForMessage(at index: Int) -> Bool {
        let list = displayedMessages
        guard index < list.count else { return false }
        let msg = list[index]
        let isOther = !isCurrentUser(username: msg.senderUsername)
        guard isOther else { return false }
        if index == 0 { return true }
        let prev = list[index - 1]
        if prev.isSoldConfirmation { return true }
        return isCurrentUser(username: prev.senderUsername)
    }

    /// Show timestamp only on the last message of a group (same sender, within 60 seconds) to avoid "Just now" on every bubble.
    private func showTimestampForMessage(at index: Int) -> Bool {
        let list = displayedMessages
        guard index < list.count else { return true }
        if index == list.count - 1 { return true }
        let msg = list[index]
        let next = list[index + 1]
        if next.senderUsername != msg.senderUsername { return true }
        if next.timestamp.timeIntervalSince(msg.timestamp) > 60 { return true }
        return false
    }

    /// True when the previous timeline entry is a message from the same sender within 60 seconds (same group) — use for tight spacing.
    private func isSameGroupAsPrevious(timelineIndex: Int, message: Message) -> Bool {
        guard timelineIndex > 0, timelineIndex - 1 < timelineOrder.count else { return false }
        guard case .message(let prevId) = timelineOrder[timelineIndex - 1],
              let prev = displayedMessages.first(where: { $0.id == prevId }) else { return false }
        guard prev.senderUsername == message.senderUsername else { return false }
        return message.timestamp.timeIntervalSince(prev.timestamp) <= 60
    }

    private static let chatAvatarSize: CGFloat = 32

    private var isSold: Bool {
        timelineOrder.contains { $0.isSold }
    }

    private func scrollToLatest(with proxy: ScrollViewProxy, animated: Bool) {
        guard !timelineOrder.isEmpty else { return }
        let last = timelineOrder[timelineOrder.count - 1]
        let action = {
            switch last {
            case .message(let id): proxy.scrollTo(id, anchor: .bottom)
            case .offer(let id): proxy.scrollTo(id, anchor: .bottom)
            case .sold(let order): proxy.scrollTo("sold_\(order.id)", anchor: .bottom)
            }
        }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } else {
            action()
        }
    }

    @ViewBuilder
    private func timelineRow(timelineIndex: Int, entry: ChatItem) -> some View {
        switch entry {
        case .message(let messageId):
            if let index = displayedMessages.firstIndex(where: { $0.id == messageId }),
               index < displayedMessages.count {
                let message = displayedMessages[index]
                let topPadding: CGFloat = timelineIndex == 0 ? 0 : (isSameGroupAsPrevious(timelineIndex: timelineIndex, message: message) ? Theme.Spacing.xs : Theme.Spacing.md)
                if message.isOrderIssue {
                    let issueCard = OrderIssueChatCardView(
                        message: message
                    )
                    .id(message.id)
                    if isCurrentUser(username: message.senderUsername) {
                        issueCard
                            .padding(.leading, Theme.Spacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, topPadding)
                    } else {
                        HStack(alignment: .top, spacing: 4) {
                            chatTitleAvatar(url: displayedConversation.recipient.avatarURL, username: displayedConversation.recipient.username)
                            issueCard
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, topPadding)
                    }
                } else {
                    let isCurrentUserMessage = isCurrentUser(username: message.senderUsername)
                    MessageBubbleView(
                        message: message,
                        isCurrentUser: isCurrentUserMessage,
                        showAvatar: showAvatarForMessage(at: index),
                        showTimestamp: showTimestampForMessage(at: index),
                        avatarURL: showAvatarForMessage(at: index) ? displayedConversation.recipient.avatarURL : nil,
                        recipientUsername: displayedConversation.recipient.username
                    )
                    .id(message.id)
                    .contextMenu {
                        if isCurrentUser(username: message.senderUsername), let _ = message.backendId {
                            Button(role: .destructive, action: { deleteMessage(message) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .padding(.top, topPadding)
                }
            }
        case .offer(let offerId):
            if let offer = offers.first(where: { $0.id == offerId }) {
                let isLatest = offer.id == offers.last?.id
                let prevIsOffer = (timelineIndex > 0 && timelineIndex - 1 < timelineOrder.count) && (timelineOrder[timelineIndex - 1].isOffer)
                let topPadding: CGFloat = timelineIndex == 0 ? 0 : (prevIsOffer ? 0 : Theme.Spacing.md)
                let isOfferFromOther = isOfferFromOtherUser(offer)
                let cardContent = OfferCardView(
                    offer: offer,
                    currentUsername: authService.username,
                    isSeller: isSeller,
                    isResponding: isLatest ? isRespondingToOffer : false,
                    errorMessage: isLatest ? offerError : nil,
                    onAccept: { await handleRespondToOffer(action: "ACCEPT", targetOffer: offer) },
                    onDecline: { await handleRespondToOffer(action: "REJECT", targetOffer: offer) },
                    onSendNewOffer: { counterTargetOffer = offer; showCounterOfferSheet = true },
                    onPayNow: { presentPayNow(for: offer) },
                    forceGreyedOut: !isLatest || isSold
                )
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.background)
                .id(offer.id)
                Group {
                    if isOfferFromOther {
                        HStack(alignment: .top, spacing: 4) {
                            chatTitleAvatar(url: displayedConversation.recipient.avatarURL, username: displayedConversation.recipient.username)
                            cardContent
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        cardContent
                            .padding(.leading, Theme.Spacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, topPadding)
            }
        case .sold(let orderInfo):
            let prevIsOfferOrSold = (timelineIndex > 0 && timelineIndex - 1 < timelineOrder.count) && (timelineOrder[timelineIndex - 1].isOffer || timelineOrder[timelineIndex - 1].isSold)
            let topPadding: CGFloat = timelineIndex == 0 ? 0 : (prevIsOfferOrSold ? 0 : Theme.Spacing.md)
            HStack(alignment: .top, spacing: 4) {
                chatTitleAvatar(
                    url: displayedConversation.recipient.avatarURL,
                    username: displayedConversation.recipient.username
                )
                .padding(.top, Theme.Spacing.md)
                SoldConfirmationCardView(
                    order: orderInfo,
                    currentUsername: authService.username,
                    conversationId: displayedConversation.id,
                    onOrderChanged: {
                        Task { await refetchConversationForOrder() }
                    }
                )
                    .id("sold_\(orderInfo.id)")
                    .padding(.vertical, Theme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topPadding)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if displayedConversation.order != nil {
                orderHeaderBar
                Rectangle()
                    .fill(Theme.Colors.glassBorder)
                    .frame(height: 0.5)
            } else if displayedConversation.offer != nil {
                offerProductHeaderBar
                Rectangle()
                    .fill(Theme.Colors.glassBorder)
                    .frame(height: 0.5)
            }
            if let item = item {
                ChatProductCardView(item: item)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.background)
                if !offers.isEmpty {
                    Rectangle()
                        .fill(Theme.Colors.glassBorder)
                        .frame(height: 0.5)
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if isLoadingOfferHistory {
                            HStack(spacing: Theme.Spacing.sm) {
                                Spacer(minLength: 0)
                                ProgressView()
                                Text("Loading")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, Theme.Spacing.lg)
                            .frame(maxWidth: .infinity)
                        }
                        ForEach(Array(timelineOrder.enumerated()), id: \.1) { timelineIndex, entry in
                            timelineRow(timelineIndex: timelineIndex, entry: entry)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    // Ensure chat opens at latest timeline entry, even when count-based onChange doesn't fire.
                    guard !hasAutoScrolledToBottomForThisChat else { return }
                    DispatchQueue.main.async {
                        scrollToLatest(with: proxy, animated: false)
                        hasAutoScrolledToBottomForThisChat = true
                    }
                }
                .onChange(of: timelineOrder.count) { _, newCount in
                    guard newCount > 0 else { return }
                    scrollToLatest(with: proxy, animated: true)
                }
                .onChange(of: hasFinishedInitialConversationFetch) { _, done in
                    guard done, !hasAutoScrolledToBottomForThisChat else { return }
                    DispatchQueue.main.async {
                        scrollToLatest(with: proxy, animated: false)
                        hasAutoScrolledToBottomForThisChat = true
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
                Menu {
                    Button("Archive") { }
                    Button("Report", role: .destructive) {
                        showReportUserSheet = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                        .contentShape(Rectangle())
                }
            }
        }
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showCounterOfferSheet) {
            OptionsSheet(
                title: L10n.string("Send a new offer"),
                onDismiss: { showCounterOfferSheet = false; counterTargetOffer = nil },
                detents: item != nil ? [.height(480)] : [.height(340)],
                useCustomCornerRadius: false
            ) {
                OfferModalContent(
                    item: item,
                    listingPrice: nil,
                    onSubmit: { newPrice in
                        showCounterOfferSheet = false
                        let target = counterTargetOffer
                        counterTargetOffer = nil
                        Task {
                            if target?.isRejected == true {
                                await handleCreateNewOffer(offerPrice: newPrice, targetOffer: target)
                            } else {
                                await handleRespondToOffer(action: "COUNTER", offerPrice: newPrice, targetOffer: target)
                            }
                        }
                    },
                    onDismiss: { showCounterOfferSheet = false },
                    isSubmitting: $offerModalSubmitting,
                    errorMessage: $offerError
                )
            }
        }
        .fullScreenCover(item: $payNowPayload) { payload in
            NavigationView {
                PaymentView(products: payload.products, totalPrice: payload.totalPrice, customOffer: true)
                    .environmentObject(authService)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") { payNowPayload = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $showReportUserSheet) {
            NavigationStack {
                ReportUserView(username: displayedConversation.recipient.username)
                    .environmentObject(authService)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showReportUserSheet = false }
                        }
                    }
            }
        }
        .onAppear {
            hasAutoScrolledToBottomForThisChat = false
            refreshOfferHistoryLoadingFlagsForCurrentConversation()
            connectWebSocket()
            fetchOfferProductIfNeeded()
            fetchOrderProductIfNeeded()
            loadOffers()
            loadConversationAndMessagesFromBackend()
        }
        .onChange(of: displayedConversation.offer?.id) { _, _ in
            fetchOfferProductIfNeeded()
        }
        .onChange(of: displayedConversation.order?.id) { _, _ in
            fetchOrderProductIfNeeded()
        }
        .onChange(of: displayedConversation.id) { _, _ in
            offers = []
            timelineOrder = []
            hasAutoScrolledToBottomForThisChat = false
            isOtherUserTyping = false
            typingUsername = nil
            refreshOfferHistoryLoadingFlagsForCurrentConversation()
            loadOffers()
            loadConversationAndMessagesFromBackend()
        }
        .onChange(of: newMessage) { _, newValue in
            sendTypingForComposerChange(newValue)
        }
        .onDisappear {
            if !offers.isEmpty {
                Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
                Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
            }
            if !timelineOrder.isEmpty {
                Self.timelineOrderCache[displayedConversation.id] = timelineOrder
            }
            if let last = messages.last, displayedConversation.id != "0", let tc = tabCoordinator {
                let previewText = last.isSoldConfirmation
                    ? (isCurrentUser(username: displayedConversation.offer?.products?.first?.seller?.username) ? "You made a sale 🎉" : "Order confirmed")
                    : (last.content.count > 60 ? String(last.content.prefix(57)) + "..." : last.content)
                tc.lastMessagePreviewForConversation = (displayedConversation.id, previewText, last.timestamp)
            }
            webSocket?.disconnect()
            webSocket = nil
            typingResetTask?.cancel()
            typingSendTask?.cancel()
            isOtherUserTyping = false
            typingUsername = nil
            didSendTypingStart = false
        }
    }

    /// After receiving sold_confirmation via WebSocket, refetch conversation so we get order from backend when it has been linked.
    private func refetchConversationForOrder() async {
        let convId = displayedConversation.id
        guard let conv = try? await chatService.getConversationById(conversationId: convId, currentUsername: authService.username) else { return }
        await MainActor.run {
            guard displayedConversation.id == convId, conv.order != nil else { return }
            displayedConversation = conv
            rebuildTimelineOrder()
        }
    }

    /// Load conversation (with order) and messages from backend. Order is only from API (single source of truth).
    private func loadConversationAndMessagesFromBackend() {
        guard displayedConversation.id != "0" else { return }
        let convId = displayedConversation.id
        isLoading = true
        Task {
            let updatedConv: Conversation? = try? await chatService.getConversationById(conversationId: convId, currentUsername: authService.username)
            let msgs: [Message] = (try? await chatService.getMessages(conversationId: convId)) ?? []
            await MainActor.run {
                guard displayedConversation.id == convId else { return }
                if let conv = updatedConv {
                    displayedConversation = conv
                    if let hist = conv.offerHistory, !hist.isEmpty {
                        let key = offerCacheKey(convId: convId)

                        // Make ACCEPTED immutable even after a full reload: server offerHistory may downgrade old accepted offers.
                        // Patch server entries whose backendId we previously saw as accepted (including synthetic snapshots),
                        // then keep synthetic snapshot cards only if the server doesn't include the base row.
                        let cached = (!self.offers.isEmpty)
                            ? self.offers
                            : (Self.offerHistoryCache[key] ?? Self.loadOfferHistory(key: key) ?? [])

                        let suffix = Self.acceptedSnapshotBackendIdSuffix
                        var acceptedBaseOffersByBackendId: [String: OfferInfo] = [:]
                        for o in cached {
                            guard let bid = o.backendId else { continue }
                            if bid.hasSuffix(suffix) {
                                let base = String(bid.dropLast(suffix.count))
                                if acceptedBaseOffersByBackendId[base] == nil {
                                    acceptedBaseOffersByBackendId[base] = o
                                }
                            } else if (o.status ?? "").uppercased() == "ACCEPTED" {
                                if acceptedBaseOffersByBackendId[bid] == nil {
                                    acceptedBaseOffersByBackendId[bid] = o
                                }
                            }
                        }

                        var combined = hist
                        for i in combined.indices {
                            guard let bid = combined[i].backendId else { continue }
                            guard let accepted = acceptedBaseOffersByBackendId[bid] else { continue }
                            combined[i] = OfferInfo(
                                id: combined[i].id,
                                backendId: combined[i].backendId,
                                status: "ACCEPTED",
                                offerPrice: accepted.offerPrice,
                                buyer: accepted.buyer,
                                products: accepted.products,
                                createdAt: accepted.createdAt ?? combined[i].createdAt,
                                sentByCurrentUser: accepted.sentByCurrentUser
                            )
                        }

                        let serverBackendIds = Set(combined.compactMap { $0.backendId })
                        let snapshotOffers = cached.filter { $0.backendId?.hasSuffix(suffix) == true }
                        for snap in snapshotOffers {
                            guard let bid = snap.backendId, bid.hasSuffix(suffix) else { continue }
                            let base = String(bid.dropLast(suffix.count))
                            guard !serverBackendIds.contains(base) else { continue }
                            guard !combined.contains(where: { $0.backendId == snap.backendId }) else { continue }
                            combined.append(snap)
                        }

                        self.offers = combined
                        Self.offerHistoryCache[key] = combined
                        Self.persistOfferHistory(key: key, offers: combined)
                    }
                }
                self.messages = msgs
                // Do not call loadOffers() here: it can race with the send-success block and overwrite the just-sent offer with stale server data. Offers are loaded on appear and when conversation id changes; loadOffers() also guards against overwriting a recently added offer.
                self.isLoading = false
                self.hasFinishedInitialConversationFetch = true
                self.isLoadingOfferHistory = false
                // `loadOffers()` often ran before messages existed — merge offer payloads from message history here so every past offer id appears as a card.
                self.mergeOffersFromMessages()
                if self.offers.isEmpty, self.displayedConversation.offer != nil {
                    self.loadOffers()
                } else {
                    self.rebuildTimelineOrder()
                }
            }
            if !msgs.isEmpty {
                let idsToMarkRead = msgs
                    .filter { !isCurrentUser(username: $0.senderUsername) }
                    .compactMap(\.backendId)
                if !idsToMarkRead.isEmpty {
                    _ = try? await chatService.readMessages(messageIds: idsToMarkRead)
                }
            }
        }
    }

    /// Restore offers from cache or seed from `conversation.offer`, then merge offer rows parsed from **message** JSON (`mergeOffersFromMessages`).
    /// When `conversation.offerHistory` is present (from `conversationById`), use it as the primary source of truth, then merge message-derived rows for any ids missing from the server list.
    /// Important: on first appear, `messages` is usually still empty — we call `mergeOffersFromMessages()` again after `getMessages` in `loadConversationAndMessagesFromBackend()` so full history isn’t dropped.
    /// When we have a "just added" offer (last offer created in the last 60s), do not overwrite with server/cache so the sent price stays visible.
    private func loadOffers() {
        let convId = displayedConversation.id
        let now = Date()
        let lastOfferIsFresh = offers.last.flatMap { last in
            (last.createdAt ?? .distantPast).distance(to: now) <= 60
        } ?? false
        if lastOfferIsFresh {
            rebuildTimelineOrder()
            return
        }
        let cacheKey = offerCacheKey(convId: convId)
        // Avoid showing a single inbox `offer` before `conversationById` returns full `offerHistory` (no memory/disk cache).
        if convId != "0",
           displayedConversation.offer != nil,
           displayedConversation.offerHistory == nil,
           !hasFinishedInitialConversationFetch,
           !hasLocalOfferHistoryCache(convId: convId) {
            offers = []
            rebuildTimelineOrder()
            return
        }
        if let hist = displayedConversation.offerHistory, !hist.isEmpty {
            let list = hist.map { o in
                OfferInfo(id: o.id, backendId: o.backendId, status: o.status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date(), sentByCurrentUser: o.sentByCurrentUser)
            }

            // Make ACCEPTED immutable even after a full reload: server offerHistory may downgrade old accepted offers.
            // We patch any server entry whose backendId we previously saw as accepted (including synthetic snapshots).
            let cached = Self.offerHistoryCache[cacheKey] ?? Self.loadOfferHistory(key: cacheKey) ?? []
            let suffix = Self.acceptedSnapshotBackendIdSuffix
            var acceptedBaseOffersByBackendId: [String: OfferInfo] = [:]
            for o in cached {
                guard let bid = o.backendId else { continue }
                if bid.hasSuffix(suffix) {
                    let base = String(bid.dropLast(suffix.count))
                    if acceptedBaseOffersByBackendId[base] == nil {
                        acceptedBaseOffersByBackendId[base] = o
                    }
                } else if (o.status ?? "").uppercased() == "ACCEPTED" {
                    if acceptedBaseOffersByBackendId[bid] == nil {
                        acceptedBaseOffersByBackendId[bid] = o
                    }
                }
            }

            var combined = list
            for i in combined.indices {
                guard let bid = combined[i].backendId else { continue }
                guard let accepted = acceptedBaseOffersByBackendId[bid] else { continue }
                combined[i] = OfferInfo(
                    id: combined[i].id,
                    backendId: combined[i].backendId,
                    status: "ACCEPTED",
                    offerPrice: accepted.offerPrice,
                    buyer: accepted.buyer,
                    products: accepted.products,
                    createdAt: accepted.createdAt ?? combined[i].createdAt,
                    sentByCurrentUser: accepted.sentByCurrentUser
                )
            }

            // If server didn't include the base offer row, keep the synthetic accepted snapshot so the green card still shows.
            let serverBackendIds = Set(combined.compactMap { $0.backendId })
            let snapshotOffers = cached.filter { $0.backendId?.hasSuffix(suffix) == true }
            for snap in snapshotOffers {
                guard let bid = snap.backendId, bid.hasSuffix(suffix) else { continue }
                let base = String(bid.dropLast(suffix.count))
                // Append only when the base accepted offer isn't present in server list.
                guard !serverBackendIds.contains(base) else { continue }
                guard !combined.contains(where: { $0.backendId == snap.backendId }) else { continue }
                combined.append(snap)
            }

            offers = combined
            Self.offerHistoryCache[cacheKey] = combined
            Self.persistOfferHistory(key: cacheKey, offers: combined)
            mergeOffersFromMessages()
            rebuildTimelineOrder()
            return
        }
        if Self.offerHistoryCache[cacheKey] == nil, let persisted = Self.loadOfferHistory(key: cacheKey), !persisted.isEmpty {
            Self.offerHistoryCache[cacheKey] = persisted.map { o in
                OfferInfo(id: o.id, backendId: o.backendId, status: o.status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date(), sentByCurrentUser: o.sentByCurrentUser)
            }
        }
        if let cached = Self.offerHistoryCache[cacheKey], !cached.isEmpty {
            var list = cached.map { o in OfferInfo(id: o.id, backendId: o.backendId, status: o.status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date(), sentByCurrentUser: o.sentByCurrentUser) }
            // If server has an offer that isn't our last cached offer (e.g. counter received), append it so it appears in the thread.
            if let serverOffer = displayedConversation.offer {
                let serverId = serverOffer.id
                // Match any row — not only `last`, or we duplicate when server id matches an older card in the list.
                let alreadyHave = list.contains { $0.backendId == serverId || $0.id == serverId }
                if !alreadyHave {
                    // Sender = opposite of last offer (turn-based); first offer fallback to lastMessageSenderUsername.
                    var fromMe = list.last.map { !$0.sentByCurrentUser } ?? isCurrentUser(username: displayedConversation.lastMessageSenderUsername)
                    var offerPrice = serverOffer.offerPrice
                    if let tc = tabCoordinator {
                        let pendingHere = tc.pendingOfferConversationId.map { $0 == displayedConversation.id } ?? true
                        if tc.pendingOfferJustSent, pendingHere {
                            fromMe = true
                            tc.pendingOfferJustSent = false
                            tc.pendingOfferConversationId = nil
                        }
                        if let sentPrice = tc.pendingOfferPrice, pendingHere {
                            offerPrice = sentPrice
                            tc.pendingOfferPrice = nil
                        }
                    }
                    let newOffer = OfferInfo(id: serverId, backendId: serverId, status: serverOffer.status ?? "PENDING", offerPrice: offerPrice, buyer: serverOffer.buyer, products: serverOffer.products, createdAt: serverOffer.createdAt ?? Date(), sentByCurrentUser: fromMe)
                    list.append(newOffer)
                    Self.offerHistoryCache[cacheKey] = list
                    Self.persistOfferHistory(key: cacheKey, offers: list)
                }
            }
            offers = list
        } else if let serverOffer = displayedConversation.offer {
            let sid = serverOffer.id
            // First offer in cache: use lastMessageSender only. Do NOT use offer.buyer — backend often keeps original buyer on counters (mislabels "You offered").
            var fromMe = isCurrentUser(username: displayedConversation.lastMessageSenderUsername)
            var status = serverOffer.status ?? "PENDING"
            var offerPrice = serverOffer.offerPrice
            if let tc = tabCoordinator {
                let pendingHere = tc.pendingOfferConversationId.map { $0 == displayedConversation.id } ?? true
                if tc.pendingOfferJustSent, pendingHere {
                    fromMe = true
                    let u = status.uppercased()
                    if u == "REJECTED" || u == "CANCELLED" { status = "PENDING" }
                    tc.pendingOfferJustSent = false
                    tc.pendingOfferConversationId = nil
                }
                if let sentPrice = tc.pendingOfferPrice, pendingHere {
                    offerPrice = sentPrice
                    tc.pendingOfferPrice = nil
                }
            }
            offers = [
                OfferInfo(id: sid, backendId: sid, status: status, offerPrice: offerPrice, buyer: serverOffer.buyer, products: serverOffer.products, createdAt: serverOffer.createdAt ?? Date(), sentByCurrentUser: fromMe)
            ]
        } else {
            offers = []
        }
        mergeOffersFromMessages()
        rebuildTimelineOrder()
    }

    /// Merge in offers derived from message history so intermediate offers (e.g. £750 then £780) all appear; superseded ones show with no buttons.
    private func mergeOffersFromMessages() {
        let convId = displayedConversation.id
        let cacheKey = offerCacheKey(convId: convId)
        var existingIds = Set(offers.compactMap { $0.backendId })
        let products = displayedConversation.offer?.products
        var added: [OfferInfo] = []
        for msg in messages.filter(\.isOfferContent) {
            guard let details = msg.parsedOfferDetails else { continue }
            let idStr = details.offerId
            guard !existingIds.contains(idStr) else { continue }
            let fromMe = isCurrentUser(username: msg.senderUsername)
            let buyer = OfferInfo.OfferUser(username: msg.senderUsername, profilePictureUrl: nil)
            let o = OfferInfo(
                id: msg.id.uuidString,
                backendId: idStr,
                status: "PENDING",
                offerPrice: details.offerPrice,
                buyer: buyer,
                products: products,
                createdAt: msg.timestamp,
                sentByCurrentUser: fromMe
            )
            added.append(o)
            existingIds.insert(idStr)
        }
        guard !added.isEmpty else { return }
        var list = offers + added
        list.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        offers = list
        Self.offerHistoryCache[cacheKey] = list
        Self.persistOfferHistory(key: cacheKey, offers: list)
    }

    /// Case-insensitive username comparison so "testuser" / "Testuser" from backend always count as current user.
    private func isCurrentUser(username: String?) -> Bool {
        let a = (username ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let b = (authService.username ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        return !a.isEmpty && a == b
    }

    /// Index of our in-flight offer row (nil backendId). Never use `offers.last` alone — that can be someone else's card.
    private func indexOfMyOptimisticOffer() -> Int? {
        offers.lastIndex(where: { $0.backendId == nil && $0.sentByCurrentUser })
    }

    private func isOfferFromOtherUser(_ offer: OfferInfo) -> Bool {
        !offer.sentByCurrentUser
    }

    /// Build timeline order by merging offers, messages, and sold event; sort by date.
    private func rebuildTimelineOrder() {
        let offerList = offers
        let msgs = displayedMessages
        var entries: [(Date, ChatItem)] = []
        for o in offerList {
            entries.append((o.createdAt ?? .distantPast, .offer(o.id)))
        }
        for m in msgs {
            entries.append((m.timestamp, .message(m.id)))
        }
        if let order = displayedConversation.order {
            // Derive buyer/seller for the "bought" banner.
            // `OfferInfo.buyer` is used for "who sent this offer" labeling and is not guaranteed to be the purchaser.
            // The only reliable seller identity we have here is the listing seller username from offer.products.first.seller.
            let seller = displayedConversation.offer?.products?.first?.seller?.username
            let current = authService.username ?? ""
            let recipientUsername = displayedConversation.recipient.username
            let buyer: String? = {
                guard let s = seller, !s.isEmpty, !current.isEmpty else { return nil }
                return s == current ? recipientUsername : current
            }()
            let orderInfo = OrderInfo.from(conversationOrder: order, buyerUsername: buyer, sellerUsername: seller)
            entries.append((orderInfo.createdAt, .sold(orderInfo)))
        }
        entries.sort { $0.0 < $1.0 }
        timelineOrder = entries.map(\.1)
    }

    /// Create a new offer (same products) when the current offer is declined — backend rejects COUNTER on cancelled offers.
    private func handleCreateNewOffer(offerPrice: Double, targetOffer: OfferInfo? = nil) async {
        guard let offer = targetOffer ?? displayedConversation.offer,
              let productIds = offer.products?.compactMap({ p in p.id.flatMap(Int.init) }),
              !productIds.isEmpty else {
            await MainActor.run { offerError = "Could not load product" }
            return
        }
        await MainActor.run {
            isRespondingToOffer = true
            offerError = nil
            let optimistic = OfferInfo(id: UUID().uuidString, backendId: nil, status: "PENDING", offerPrice: offerPrice, buyer: offer.buyer, products: offer.products, createdAt: Date(), sentByCurrentUser: true)
            offers = offers + [optimistic]
            rebuildTimelineOrder()
        }
        do {
            let (_, newConv) = try await productService.createOffer(offerPrice: offerPrice, productIds: productIds, message: nil)
            let convs = try await chatService.getConversations()
            await MainActor.run {
                if let updated = convs.first(where: { $0.id == displayedConversation.id }) {
                    displayedConversation = updated
                }
                let serverOfferFromCreate = (newConv?.id == displayedConversation.id ? newConv?.offer : nil)
                let rawStatus = serverOfferFromCreate?.status ?? "PENDING"
                let status: String = {
                    let u = rawStatus.uppercased()
                    if u == "REJECTED" || u == "CANCELLED" { return "PENDING" }
                    return rawStatus
                }()
                let newBackendId = serverOfferFromCreate?.id
                // WebSocket may have already appended this offer — only remove our duplicate placeholder, never other cards.
                if let bid = newBackendId, offers.contains(where: { $0.backendId == bid }) {
                    if let optIdx = indexOfMyOptimisticOffer() {
                        var next = offers
                        next.remove(at: optIdx)
                        offers = next
                    }
                    Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
                    Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
                    rebuildTimelineOrder()
                    isRespondingToOffer = false
                    offerError = nil
                    return
                }
                guard let optIdx = indexOfMyOptimisticOffer() else {
                    isRespondingToOffer = false
                    offerError = nil
                    return
                }
                let stableId = offers[optIdx].id
                let confirmed = OfferInfo(
                    id: stableId,
                    backendId: newBackendId,
                    status: status,
                    offerPrice: offerPrice,
                    buyer: serverOfferFromCreate?.buyer ?? offer.buyer,
                    products: serverOfferFromCreate?.products ?? offer.products,
                    createdAt: offers[optIdx].createdAt ?? Date(),
                    sentByCurrentUser: true
                )
                var nextOffers = offers
                nextOffers[optIdx] = confirmed
                offers = nextOffers
                Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
                Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
                rebuildTimelineOrder()
                isRespondingToOffer = false
                offerError = nil
            }
        } catch {
            await MainActor.run {
                if let optIdx = indexOfMyOptimisticOffer() {
                    var next = offers
                    next.remove(at: optIdx)
                    offers = next
                    rebuildTimelineOrder()
                }
                isRespondingToOffer = false
                offerError = error.localizedDescription
            }
        }
    }

    private func handleRespondToOffer(action: String, offerPrice: Double? = nil, targetOffer: OfferInfo? = nil) async {
        let effectiveOffer = targetOffer ?? displayedConversation.offer
        guard let offer = effectiveOffer, let offerId = offer.offerIdInt else { return }
        let isCounter = action == "COUNTER"
        let newPrice = offerPrice ?? offer.offerPrice
        if isCounter {
            await MainActor.run {
                let optimistic = OfferInfo(id: UUID().uuidString, backendId: nil, status: "PENDING", offerPrice: newPrice, buyer: offer.buyer, products: offer.products, createdAt: Date(), sentByCurrentUser: true)
                offers = offers + [optimistic]
                rebuildTimelineOrder()
            }
        }
        await MainActor.run {
            isRespondingToOffer = true
            offerError = nil
        }
        do {
            try await productService.respondToOffer(action: action, offerId: offerId, offerPrice: offerPrice)
            let convs = try await chatService.getConversations()
            await MainActor.run {
                guard let updated = convs.first(where: { $0.id == displayedConversation.id }) else {
                    isRespondingToOffer = false
                    offerError = nil
                    return
                }
                displayedConversation = updated
                if isCounter {
                    let serverOffer = updated.offer
                    let rawStatus = serverOffer?.status ?? "PENDING"
                    let status: String = (rawStatus.uppercased() == "REJECTED" || rawStatus.uppercased() == "CANCELLED") ? "PENDING" : rawStatus
                    let newBackendId = serverOffer?.id
                    let oldOfferIdStr = String(offerId)
                    // If server returns the *old* offer we countered (stale), we must not remove our optimistic row — that would collapse the new card into the old one. Only "remove optimistic" when the duplicate is the *new* offer (WS already added it).
                    let serverReturnedOldOfferId = newBackendId.map { $0 == oldOfferIdStr } ?? false
                    if let bid = newBackendId, !serverReturnedOldOfferId, offers.contains(where: { $0.backendId == bid }) {
                        if let optIdx = indexOfMyOptimisticOffer() {
                            var next = offers
                            next.remove(at: optIdx)
                            offers = next
                        }
                        Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
                        Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
                        rebuildTimelineOrder()
                        isRespondingToOffer = false
                        offerError = nil
                        return
                    }
                    guard let optIdx = indexOfMyOptimisticOffer() else {
                        isRespondingToOffer = false
                        offerError = nil
                        return
                    }
                    let stableId = offers[optIdx].id
                    // When server returned the old offer id, keep our card's backendId nil so we don't duplicate that id; WS will send the real new id later and we'll upgrade this row.
                    let confirmedBackendId = serverReturnedOldOfferId ? nil : newBackendId
                    let confirmed = OfferInfo(
                        id: stableId,
                        backendId: confirmedBackendId,
                        status: status,
                        offerPrice: newPrice,
                        buyer: serverOffer?.buyer ?? offer.buyer,
                        products: serverOffer?.products ?? offer.products,
                        createdAt: offers[optIdx].createdAt ?? Date(),
                        sentByCurrentUser: true
                    )
                    var nextOffers = offers
                    nextOffers[optIdx] = confirmed
                    offers = nextOffers
                    Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
                    Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
                    rebuildTimelineOrder()
                } else if action == "ACCEPT" || action == "REJECT", let serverOffer = updated.offer {
                    let targetId = String(offerId)
                    if let idx = offers.firstIndex(where: { $0.backendId == targetId || $0.id == targetId }) {
                        let last = offers[idx]

                        // IMPORTANT:
                        // `getConversations()` returns only the conversation's current offer as `updated.offer`,
                        // which may not match the offer card the user just tapped (targetId).
                        // So we MUST not blindly copy `serverOffer.status` onto the tapped card.
                        let serverOfferId = serverOffer.backendId ?? serverOffer.id
                        let serverMatchesTarget = serverOfferId == targetId

                        let existingUpper = (last.status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

                        let resolvedStatus: String = {
                            // Once green, always green (history).
                            if existingUpper == "ACCEPTED" { return "ACCEPTED" }

                            switch action {
                            case "ACCEPT":
                                return "ACCEPTED"
                            case "REJECT":
                                // Only trust server status when it matches the tapped offer id.
                                guard serverMatchesTarget else { return "REJECTED" }
                                let incomingUpper = (serverOffer.status ?? last.status ?? "REJECTED")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .uppercased()
                                return incomingUpper == "CANCELLED" ? "CANCELLED" : "REJECTED"
                            default:
                                return last.status ?? "PENDING"
                            }
                        }()

                        // Keep price/buyer/products stable unless the server matches the tapped offer id.
                        let offerPrice = serverMatchesTarget ? serverOffer.offerPrice : last.offerPrice
                        let buyer = serverMatchesTarget ? serverOffer.buyer : last.buyer
                        let products = serverMatchesTarget ? serverOffer.products : last.products

                        let updatedOffer = OfferInfo(
                            id: last.id,
                            backendId: last.backendId,
                            status: resolvedStatus,
                            offerPrice: offerPrice,
                            buyer: buyer,
                            products: products,
                            createdAt: last.createdAt ?? Date(),
                            sentByCurrentUser: last.sentByCurrentUser
                        )
                        var nextOffers = offers
                        nextOffers[idx] = updatedOffer
                        offers = nextOffers
                        Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
                        Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
                        rebuildTimelineOrder()
                    }
                }
                isRespondingToOffer = false
                offerError = nil
            }
        } catch {
            await MainActor.run {
                if isCounter, let optIdx = indexOfMyOptimisticOffer() {
                    var next = offers
                    next.remove(at: optIdx)
                    offers = next
                    rebuildTimelineOrder()
                }
                isRespondingToOffer = false
                offerError = error.localizedDescription
            }
        }
    }

    /// Opens checkout for the accepted-offer price. Uses the specific card’s products/price when present (offer thread), else falls back to the conversation’s current offer.
    private func presentPayNow(for cardOffer: OfferInfo) {
        let fallbackProducts = displayedConversation.offer?.products
        let productSource = (cardOffer.products?.isEmpty == false) ? cardOffer.products : fallbackProducts
        let productIds = productSource?.compactMap { p -> Int? in
            guard let id = p.id else { return nil }
            return Int(id)
        } ?? []
        guard !productIds.isEmpty else { return }
        let offerPrice = cardOffer.offerPrice
        Task {
            do {
                var items: [Item] = []
                for id in productIds {
                    guard let product = try await productService.getProduct(id: id) else {
                        throw NSError(
                            domain: "ChatDetailView",
                            code: 404,
                            userInfo: [NSLocalizedDescriptionKey: "Could not load product"]
                        )
                    }
                    items.append(product)
                }
                await MainActor.run {
                    payNowPayload = PayNowPayload(products: items, totalPrice: offerPrice)
                }
            } catch {
                await MainActor.run { offerError = error.localizedDescription }
            }
        }
    }

    /// Order header bar: shown in every chat that has an order. Loads the related product so the top bar
    /// shows thumbnail, name, price, status and is tappable to product. Fetched in onAppear and when order changes.
    /// Price rule: use the latest accepted offer price when available; fallback to order total.
    private var latestAcceptedOfferPriceForHeader: Double? {
        offers
            .filter { $0.isAccepted }
            .max(by: { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) })?
            .offerPrice
    }

    private var orderHeaderBar: some View {
        guard let order = displayedConversation.order else { return AnyView(EmptyView()) }
        let headerPrice = latestAcceptedOfferPriceForHeader ?? order.total
        let priceStr = String(format: "£%.2f", headerPrice)
        let bar = HStack(spacing: Theme.Spacing.md) {
            Group {
                if let urlString = orderProductItem?.imageURLs.first ?? order.firstProductImageUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: ImageShimmerPlaceholderFilled(cornerRadius: 8)
                        }
                    }
                } else {
                    ImageShimmerPlaceholderFilled(cornerRadius: 8)
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(width: 56, height: 56)
            .clipped()
            .cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(order.firstProductName ?? "Order")
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
                Text(priceStr)
                    .font(Theme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primaryColor)
                Text(orderStatusDisplay(order.status))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
        .contentShape(Rectangle())
        if let item = orderProductItem {
            return AnyView(
                NavigationLink(destination: ItemDetailView(item: item, authService: authService)) { bar }
                    .buttonStyle(.plain)
            )
        }
        return AnyView(bar)
    }

    private func orderStatusDisplay(_ status: String) -> String {
        switch status {
        case "CONFIRMED": return "Confirmed"
        case "SHIPPED": return "Shipped"
        case "DELIVERED": return "Completed"
        case "CANCELLED": return "Cancelled"
        case "REFUNDED": return "Refunded"
        default: return status
        }
    }

    private var offerProductHeaderBar: some View {
        let offer = displayedConversation.offer!
        let priceStr = String(format: "£%.2f", offer.offerPrice)
        let bar = HStack(spacing: Theme.Spacing.md) {
            Group {
                if let item = offerProductItem, let urlString = item.imageURLs.first, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: ImageShimmerPlaceholderFilled(cornerRadius: 8)
                        }
                    }
                } else {
                    ImageShimmerPlaceholderFilled(cornerRadius: 8)
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(width: 56, height: 56)
            .clipped()
            .cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(offerProductItem?.title ?? offer.products?.first?.name ?? "Product")
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
                Text(priceStr)
                    .font(Theme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primaryColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
        .contentShape(Rectangle())
        return Group {
            if let item = offerProductItem {
                NavigationLink(destination: ItemDetailView(item: item, authService: authService)) { bar }
                    .buttonStyle(.plain)
            } else {
                bar
            }
        }
    }

    private func fetchOfferProductIfNeeded() {
        guard let offer = displayedConversation.offer,
              let firstId = offer.products?.first?.id.flatMap({ Int($0) }) else {
            offerProductItem = nil
            return
        }
        if let cached = Self.offerProductCache[firstId] {
            offerProductItem = cached
            return
        }
        Task {
            if let product = try? await productService.getProduct(id: firstId) {
                await MainActor.run {
                    Self.offerProductCache[firstId] = product
                    offerProductItem = product
                }
            }
        }
    }

    private func fetchOrderProductIfNeeded() {
        guard let order = displayedConversation.order,
              let firstId = order.firstProductId.flatMap({ Int($0) }) else {
            orderProductItem = nil
            return
        }
        if let cached = Self.orderProductCache[firstId] {
            orderProductItem = cached
            return
        }
        Task {
            if let product = try? await productService.getProduct(id: firstId) {
                await MainActor.run {
                    Self.orderProductCache[firstId] = product
                    orderProductItem = product
                }
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

    /// When the backend reuses the same offer id for a counter (new price), keep the previous card and append the new one.
    private func demoteExistingOfferRowForReusedServerId(existingIndex: Int, incoming: OfferInfo, event: OfferSocketEvent) {
        let existing = offers[existingIndex]
        let demotedBackendId = "\(incoming.id)-hist-\(Int(existing.offerPrice * 100))-\(existing.id.replacingOccurrences(of: "-", with: "").prefix(8))"
        var next = offers
        next[existingIndex] = OfferInfo(
            id: existing.id,
            backendId: demotedBackendId,
            status: existing.status,
            offerPrice: existing.offerPrice,
            buyer: existing.buyer,
            products: existing.products,
            createdAt: existing.createdAt ?? Date(),
            sentByCurrentUser: existing.sentByCurrentUser
        )
        let senderNorm = event.senderUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitMine: Bool? = {
            guard let s = senderNorm, !s.isEmpty else { return nil }
            return isCurrentUser(username: s)
        }()
        // Receiving side: default to "from peer" when sender is missing (avoids wrong `!lastOffer.sentByCurrentUser` flip).
        let sentByMe = explicitMine ?? false
        let displayBuyer: OfferInfo.OfferUser?
        if let s = senderNorm, !s.isEmpty {
            displayBuyer = OfferInfo.OfferUser(username: s, profilePictureUrl: incoming.buyer?.profilePictureUrl)
        } else {
            displayBuyer = incoming.buyer
        }
        let newRow = OfferInfo(
            id: UUID().uuidString,
            backendId: incoming.id,
            status: incoming.status,
            offerPrice: incoming.offerPrice,
            buyer: displayBuyer,
            products: incoming.products ?? existing.products,
            createdAt: incoming.createdAt ?? Date(),
            sentByCurrentUser: sentByMe
        )
        next.append(newRow)
        offers = next
    }

    /// Handle NEW_OFFER / UPDATE_OFFER from WebSocket. When backend pushes these, update offers without refetch.
    private func handleOfferSocketEvent(_ event: OfferSocketEvent) {
        if let convId = event.conversationId, convId != displayedConversation.id { return }
        switch event.type {
        case "NEW_OFFER":
            guard let offer = event.offer else { break }
            let senderNorm = event.senderUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
            let explicitSenderIsMine: Bool? = {
                guard let s = senderNorm, !s.isEmpty else { return nil }
                return isCurrentUser(username: s)
            }()
            // Backend often keeps the same offer row id when someone counters — `contains(backendId)` would skip and we'd show one card. Split history instead.
            if let dupIdx = offers.firstIndex(where: { $0.backendId == offer.id }),
               abs(offers[dupIdx].offerPrice - offer.offerPrice) > 0.009 {
                demoteExistingOfferRowForReusedServerId(existingIndex: dupIdx, incoming: offer, event: event)
                Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
                Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
                rebuildTimelineOrder()
                break
            }
            // If we already have this offer id but didn't demote (e.g. same price), still correct the card's sender when backend sends it (fixes misattribution from cache/API).
            if let existingIdx = offers.firstIndex(where: { $0.backendId == offer.id }),
               let sender = senderNorm, !sender.isEmpty,
               !offers[existingIdx].sentByCurrentUser,
               offers[existingIdx].buyer?.username?.lowercased() != sender.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                let o = offers[existingIdx]
                let corrected = OfferInfo(
                    id: o.id,
                    backendId: o.backendId,
                    status: o.status,
                    offerPrice: o.offerPrice,
                    buyer: OfferInfo.OfferUser(username: sender, profilePictureUrl: o.buyer?.profilePictureUrl),
                    products: o.products,
                    createdAt: o.createdAt ?? Date(),
                    sentByCurrentUser: false
                )
                var next = offers
                next[existingIdx] = corrected
                offers = next
                Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
                Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
                rebuildTimelineOrder()
                break
            }
            // Never replace optimistic rows via WebSocket — only append (dedupe by server offer id).
            if !offers.contains(where: { $0.backendId == offer.id }) {
                let isMineForNew: Bool
                if let explicit = explicitSenderIsMine {
                    isMineForNew = explicit
                } else if let lastMsg = messages.reversed().first(where: { $0.isOfferContent }),
                          let details = lastMsg.parsedOfferDetails,
                          details.offerId == offer.id {
                    isMineForNew = isCurrentUser(username: lastMsg.senderUsername)
                } else {
                    // Do NOT infer from `offers.last` — when the peer counters twice in a row or messages lag, `!last.sentByCurrentUser` becomes true and we mis-label their offer as ours (and can hit the optimistic-upgrade path).
                    isMineForNew = false
                }
                #if DEBUG
                print("---- OFFER EVENT ----")
                print("senderUsername:", event.senderUsername ?? "nil")
                print("last message sender:", messages.last?.senderUsername ?? "nil")
                print("current user:", authService.username ?? "nil")
                print("isMineForNew:", isMineForNew)
                print("---------------------")
                #endif
                let sender = senderNorm
                let displayBuyer: OfferInfo.OfferUser?
                if let s = sender, !s.isEmpty {
                    displayBuyer = OfferInfo.OfferUser(username: s, profilePictureUrl: offer.buyer?.profilePictureUrl)
                } else {
                    displayBuyer = offer.buyer
                }
                // Only upgrade a nil-backend placeholder when we know this event is ours (explicit sender or inferred mine).
                if isMineForNew, explicitSenderIsMine != false, let optIdx = indexOfMyOptimisticOffer() {
                    let existing = offers[optIdx]
                    let upgraded = OfferInfo(
                        id: existing.id,
                        backendId: offer.id,
                        status: offer.status,
                        offerPrice: offer.offerPrice,
                        buyer: displayBuyer ?? existing.buyer,
                        products: offer.products ?? existing.products,
                        createdAt: offer.createdAt ?? existing.createdAt ?? Date(),
                        sentByCurrentUser: true
                    )
                    var nextOffers = offers
                    nextOffers[optIdx] = upgraded
                    offers = nextOffers
                    isRespondingToOffer = false
                    offerError = nil
                } else {
                    let newOffer = OfferInfo(
                        id: UUID().uuidString,
                        backendId: offer.id,
                        status: offer.status,
                        offerPrice: offer.offerPrice,
                        buyer: displayBuyer,
                        products: offer.products,
                        createdAt: offer.createdAt ?? Date(),
                        sentByCurrentUser: isMineForNew
                    )
                    offers.append(newOffer)
                    if isMineForNew {
                        isRespondingToOffer = false
                        offerError = nil
                    }
                }
            }
            Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
            Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
            rebuildTimelineOrder()
        case "UPDATE_OFFER":
            guard let offerId = event.offerId ?? event.offer?.id, let status = event.status,
                  let idx = offers.firstIndex(where: { $0.id == offerId || $0.backendId == offerId || $0.id.hasPrefix(offerId + "-") }) else { break }
            let o = offers[idx]
            let normalizedIncomingStatus = status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let existingUpper = (o.status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let incomingUpper = normalizedIncomingStatus
            // Make ACCEPTED immutable for history: once a card is green, it must never flip to declined/red.
            let resolvedStatus: String =
                (existingUpper == "ACCEPTED" && (incomingUpper == "REJECTED" || incomingUpper == "CANCELLED"))
                ? "ACCEPTED"
                : normalizedIncomingStatus

            var nextOffers = offers
            nextOffers[idx] = OfferInfo(
                id: o.id,
                backendId: o.backendId,
                status: resolvedStatus,
                offerPrice: o.offerPrice,
                buyer: o.buyer,
                products: o.products,
                createdAt: o.createdAt ?? Date(),
                sentByCurrentUser: o.sentByCurrentUser
            )
            offers = nextOffers
            Self.offerHistoryCache[offerCacheKey(convId: displayedConversation.id)] = offers
            Self.persistOfferHistory(key: offerCacheKey(convId: displayedConversation.id), offers: offers)
            rebuildTimelineOrder()
        default:
            break
        }
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
                if msg.isOfferContent {
                    mergeOffersFromMessages()
                    rebuildTimelineOrder()
                }
                return
            }
            if messages.contains(where: { $0.id == msg.id }) { return }
            messages.append(msg)
            messages.sort { $0.timestamp < $1.timestamp }
            if msg.isOfferContent {
                mergeOffersFromMessages()
                rebuildTimelineOrder()
            }
        }
        ws.onOfferEvent = { [self] event in
            handleOfferSocketEvent(event)
        }
        ws.onOrderEvent = { [self] event in
            _ = event
        }
        ws.onTypingEvent = { [self] event in
            if let convId = event.conversationId, convId != displayedConversation.id { return }
            // Ignore our own typing echoes.
            if isCurrentUser(username: event.senderUsername) { return }
            typingUsername = event.senderUsername
            if event.isTyping {
                isOtherUserTyping = true
                typingResetTask?.cancel()
                typingResetTask = Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run { isOtherUserTyping = false }
                }
            } else {
                isOtherUserTyping = false
                typingResetTask?.cancel()
            }
        }
        webSocket = ws
        ws.connect()
    }

    private func sendTypingForComposerChange(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        typingSendTask?.cancel()
        if trimmed.isEmpty {
            if didSendTypingStart {
                webSocket?.sendTyping(isTyping: false)
                didSendTypingStart = false
            }
            return
        }
        // Debounced typing-start so we don't spam socket on every keypress.
        typingSendTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run {
                if !didSendTypingStart {
                    webSocket?.sendTyping(isTyping: true)
                    didSendTypingStart = true
                }
            }
        }
    }

    private func loadMessages() {
        guard displayedConversation.id != "0" else {
            messages = []
            return
        }
        let convId = displayedConversation.id
        isLoading = true
        Task {
            do {
                let msgs = try await chatService.getMessages(conversationId: convId)
                await MainActor.run {
                    guard displayedConversation.id == convId else { return }
                    self.messages = msgs
                    self.isLoading = false
                    self.mergeOffersFromMessages()
                    self.rebuildTimelineOrder()
                }
                // Mark as read: messages from the other party (IDs we have from backend)
                let idsToMarkRead = msgs
                    .filter { !isCurrentUser(username: $0.senderUsername) }
                    .compactMap(\.backendId)
                if !idsToMarkRead.isEmpty {
                    _ = try? await chatService.readMessages(messageIds: idsToMarkRead)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    // Don't wipe messages on error when we already have messages for this conversation (avoids empty chat on re-enter)
                    if displayedConversation.id != convId || messages.isEmpty {
                        self.messages = []
                    }
                    self.rebuildTimelineOrder()
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
        guard !text.isEmpty, displayedConversation.id != "0" else { return }
        newMessage = ""
        if didSendTypingStart {
            webSocket?.sendTyping(isTyping: false)
            didSendTypingStart = false
        }
        let messageUUID = UUID().uuidString
        let optimistic = Message(
            id: UUID(uuidString: messageUUID) ?? UUID(),
            senderUsername: authService.username ?? "You",
            content: text,
            type: "text"
        )
        messages.append(optimistic)
        timelineOrder.append(.message(optimistic.id))
        pendingMessageUUID = messageUUID
        if let ws = webSocket {
            ws.send(message: text, messageUUID: messageUUID)
        }
        Task {
            do {
                _ = try await chatService.sendMessage(conversationId: displayedConversation.id, message: text, messageUuid: messageUUID)
                await MainActor.run {
                    pendingMessageUUID = nil
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

// MARK: - Offer card (Flutter OfferFirstCard)

/// Offer card at top of chat when conversation has an offer. Shows offer line, status, and actions: Accept/Decline/Send new offer (seller, pending), Pay (buyer when accepted — whoever sent the offer), Send new offer (rejected).
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
    /// When true, this card was superseded by a newer offer; show only offer line + status (no "Send new offer" button).
    var forceGreyedOut: Bool = false

    private var offerLine: String {
        let priceStr = String(format: "£%.2f", offer.offerPrice)
        if offer.sentByCurrentUser {
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

    /// Hide status label when Pending or Countered (per design: don't show "COUNTERED" / "Pending" on cards).
    private var shouldShowStatus: Bool {
        let s = (offer.status ?? "").uppercased()
        return s != "PENDING" && s != "COUNTERED"
    }

    /// True when this offer was sent by the current user (sender sees only "Send new offer").
    private var isOfferSentByMe: Bool {
        offer.sentByCurrentUser
    }

    /// Same relative format as message bubbles (e.g. "Just now", "9 mins ago").
    private static func relativeTimestamp(for date: Date) -> String {
        let now = Date()
        if now.timeIntervalSince(date) < 60 {
            return "Just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let str = formatter.localizedString(for: date, relativeTo: now)
        if str.hasPrefix("in ") { return "Just now" }
        return str
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(offerLine)
                .font(Theme.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.primaryText)
            if shouldShowStatus {
                Text(statusText)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(statusColor)
            }
            if let err = errorMessage, !err.isEmpty {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.red)
            }

            // Button logic: evaluate **accepted** before "I sent" so buyers who sent the accepted offer see Pay, not "Send new offer".
            if forceGreyedOut {
                EmptyView()
            }
            // CASE 1: Accepted → purchaser (not listing seller / accepter) pays, regardless of who sent that offer.
            else if offer.isAccepted {
                VStack(spacing: Theme.Spacing.sm) {
                    if !isSeller {
                        Button(action: onPayNow) {
                            Text("Pay")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.primaryColor)
                                .foregroundColor(.white)
                                .cornerRadius(22)
                        }
                        .disabled(isResponding)
                    }

                    // For both sides: accepted offers still allow starting a new offer.
                    Button(action: onSendNewOffer) {
                        Text("Send new offer")
                            .font(.system(size: 15, weight: .regular))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primaryColor, lineWidth: 1))
                            .foregroundColor(Theme.primaryColor)
                            .cornerRadius(22)
                    }
                    .disabled(isResponding)
                }
            }
            // CASE 2: I sent a pending offer → only "Send new offer"
            else if isOfferSentByMe {
                Button(action: onSendNewOffer) {
                    Text("Send new offer")
                        .font(.system(size: 15, weight: .regular))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primaryColor, lineWidth: 1))
                        .foregroundColor(Theme.Colors.primaryText)
                        .cornerRadius(22)
                }
                .disabled(isResponding)
            }
            // CASE 3: I received an offer (pending) → Accept / Decline / Send new offer
            else if !isOfferSentByMe && !offer.isRejected {
                VStack(spacing: Theme.Spacing.sm) {
                    Button(action: { Task { await onAccept() } }) {
                        Text("Accept")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(22)
                    }
                    .disabled(isResponding)
                    HStack(spacing: Theme.Spacing.sm) {
                        Button(action: { Task { await onDecline() } }) {
                            Text("Decline")
                                .font(.system(size: 15, weight: .regular))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primaryColor, lineWidth: 1))
                                .foregroundColor(Theme.Colors.primaryText)
                                .cornerRadius(22)
                        }
                        .disabled(isResponding)
                        Button(action: onSendNewOffer) {
                            Text("Send new offer")
                                .font(.system(size: 15, weight: .regular))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primaryColor, lineWidth: 1))
                                .foregroundColor(Theme.Colors.primaryText)
                                .cornerRadius(22)
                        }
                        .disabled(isResponding)
                    }
                }
            }
            // CASE 4: Rejected → both can send new offer
            else if offer.isRejected {
                Button(action: onSendNewOffer) {
                    Text("Send new offer")
                        .font(.system(size: 15, weight: .regular))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primaryColor, lineWidth: 1))
                        .foregroundColor(Theme.Colors.primaryText)
                        .cornerRadius(22)
                }
                .disabled(isResponding)
            }

            if isResponding {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            // Timestamp row (relative).
            HStack {
                Spacer(minLength: 0)
                Text(offer.createdAt.map { Self.relativeTimestamp(for: $0) } ?? "—")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
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

/// Order confirmation card shown in timeline when conversation has an order (sale details). Includes timestamp for chronological ordering.
struct OrderConfirmationCardView: View {
    let order: ConversationOrder
    let isSeller: Bool

    private static func orderStatusDisplay(_ status: String) -> String {
        switch status {
        case "CONFIRMED": return "Confirmed"
        case "SHIPPED": return "Shipped"
        case "DELIVERED": return "Completed"
        case "CANCELLED": return "Cancelled"
        case "REFUNDED": return "Refunded"
        default: return status
        }
    }

    private static func relativeTimestamp(for date: Date) -> String {
        let now = Date()
        if now.timeIntervalSince(date) < 60 { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let str = formatter.localizedString(for: date, relativeTo: now)
        if str.hasPrefix("in ") { return "Just now" }
        return str
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.primaryColor)
                Text(isSeller ? "Item sold" : "Order confirmed")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            HStack {
                Text(String(format: "£%.2f", order.total))
                    .font(Theme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primaryColor)
                Text("•")
                    .foregroundColor(Theme.Colors.secondaryText)
                Text(Self.orderStatusDisplay(order.status))
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            if let name = order.firstProductName, !name.isEmpty {
                Text(name)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(2)
            }
            NavigationLink(destination: OrderHelpView(orderId: order.id, conversationId: "")) {
                Text("Report an issue")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.primaryColor)
            }
            .buttonStyle(.plain)
            HStack {
                Spacer(minLength: 0)
                Text(order.createdAt.map { Self.relativeTimestamp(for: $0) } ?? "—")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }
}

/// Sold event card in timeline: "You bought this for £X" / "X bought this for £X".
struct SoldConfirmationCardView: View {
    let order: OrderInfo
    let currentUsername: String?
    var conversationId: String? = nil
    var onOrderChanged: (() -> Void)? = nil
    @EnvironmentObject var authService: AuthService
    @State private var showBuyerHelp = false
    @State private var showSellerOptions = false

    private var isBuyer: Bool {
        currentUsername.map {
            order.buyerUsername.trimmingCharacters(in: .whitespaces).lowercased() ==
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        } ?? false
    }

    private var isSeller: Bool {
        currentUsername.map {
            order.sellerUsername.trimmingCharacters(in: .whitespaces).lowercased() ==
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        } ?? false
    }

    private static func relativeTimestamp(for date: Date) -> String {
        let now = Date()
        if now.timeIntervalSince(date) < 60 { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let str = formatter.localizedString(for: date, relativeTo: now)
        if str.hasPrefix("in ") { return "Just now" }
        return str
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.primaryColor)
                Text(
                    isSeller
                        ? "This item has sold"
                        : (isBuyer ? "You bought this" : "\(order.buyerUsername) bought this")
                )
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            HStack {
                Button(action: {
                    if isSeller {
                        showSellerOptions = true
                    } else {
                        showBuyerHelp = true
                    }
                }) {
                    Text("I have a problem")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .buttonStyle(.plain)
                Spacer(minLength: Theme.Spacing.sm)
                Text(Self.relativeTimestamp(for: order.createdAt))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
        .background(
            NavigationLink(
                destination: OrderHelpView(orderId: order.orderId, conversationId: conversationId),
                isActive: $showBuyerHelp
            ) { EmptyView() }
            .hidden()
        )
        .sheet(isPresented: $showSellerOptions) {
            NavigationStack {
                SellerOrderProblemOptionsView(orderId: order.orderId) {
                    showSellerOptions = false
                    onOrderChanged?()
                }
                .environmentObject(authService)
            }
        }
    }
}

/// Seller-side problem actions from sold confirmation banner.
private struct SellerOrderProblemOptionsView: View {
    let orderId: String
    var onOrderChanged: (() -> Void)? = nil
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showCancelConfirm = false
    @State private var isCancelling = false
    @State private var errorMessage: String?
    private let userService = UserService()

    var body: some View {
        List {
            Section("Need help with this sale?") {
                NavigationLink("Order status issue") { HelpChatView() }
                NavigationLink("Delivery / collection issue") { HelpChatView() }
                NavigationLink("Payment issue") { HelpChatView() }
            }
            Section("Order actions") {
                Button(role: .destructive) { showCancelConfirm = true } label: {
                    if isCancelling {
                        ProgressView()
                    } else {
                        Text("Cancel order")
                    }
                }
                .disabled(isCancelling)
            }
            if let err = errorMessage, !err.isEmpty {
                Section {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Order issue options")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Cancel this order?", isPresented: $showCancelConfirm) {
            Button("Keep order", role: .cancel) { }
            Button("Cancel order", role: .destructive) {
                Task { await cancelOrder() }
            }
        } message: {
            Text("This will request cancellation for this order.")
        }
    }

    private func cancelOrder() async {
        guard let oid = Int(orderId) else {
            await MainActor.run { errorMessage = "Invalid order id" }
            return
        }
        await MainActor.run { isCancelling = true; errorMessage = nil }
        userService.updateAuthToken(authService.authToken)
        do {
            try await userService.cancelOrder(
                orderId: oid,
                reason: "CHANGED_MY_MIND",
                notes: "Seller requested cancellation from chat sold banner.",
                imagesUrl: []
            )
            await MainActor.run {
                isCancelling = false
                onOrderChanged?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isCancelling = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct OrderIssueChatCardView: View {
    let message: Message

    private static func relativeTimestamp(for date: Date) -> String {
        let now = Date()
        if now.timeIntervalSince(date) < 60 { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let str = formatter.localizedString(for: date, relativeTo: now)
        if str.hasPrefix("in ") { return "Just now" }
        return str
    }

    var body: some View {
        let payload = message.parsedOrderIssueDetails
        NavigationLink(destination: OrderIssueDetailView(issueId: payload?.issueId, publicId: payload?.publicId)) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Issue with order")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                if let rawType = payload?.issueType, !rawType.isEmpty {
                    Text(humanReadableIssueType(rawType))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                HStack {
                    Spacer(minLength: 0)
                    Text(Self.relativeTimestamp(for: message.timestamp))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func humanReadableIssueType(_ raw: String) -> String {
        switch raw {
        case "NOT_AS_DESCRIBED": return "Item not as described"
        case "TOO_SMALL": return "Item is too small"
        case "COUNTERFEIT": return "Item is counterfeit"
        case "DAMAGED": return "Item is damaged or broken"
        case "WRONG_COLOR": return "Item is wrong colour"
        case "WRONG_SIZE": return "Item is wrong size"
        case "DEFECTIVE": return "Item doesn't work / defective"
        case "OTHER": return "Other"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

private struct TypingDotsView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .frame(width: 5, height: 5)
                .scaleEffect(animate ? 1.0 : 0.6)
                .opacity(animate ? 1.0 : 0.45)
                .animation(.easeInOut(duration: 0.55).repeatForever().delay(0.0), value: animate)
            Circle()
                .frame(width: 5, height: 5)
                .scaleEffect(animate ? 1.0 : 0.6)
                .opacity(animate ? 1.0 : 0.45)
                .animation(.easeInOut(duration: 0.55).repeatForever().delay(0.12), value: animate)
            Circle()
                .frame(width: 5, height: 5)
                .scaleEffect(animate ? 1.0 : 0.6)
                .opacity(animate ? 1.0 : 0.45)
                .animation(.easeInOut(duration: 0.55).repeatForever().delay(0.24), value: animate)
        }
        .foregroundColor(Theme.Colors.secondaryText)
        .onAppear { animate = true }
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    /// When true and not current user, show avatar to the left of the bubble (first in group).
    var showAvatar: Bool = false
    /// When true, show timestamp below the bubble (only on last message of a group to avoid repetition).
    var showTimestamp: Bool = true
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
                if showTimestamp {
                    Text(message.formattedTimestamp)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
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
