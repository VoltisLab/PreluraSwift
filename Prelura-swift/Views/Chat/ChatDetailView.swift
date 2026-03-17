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

/// One item in the chat timeline: either a message or an offer card. Order is preserved so nothing moves above/below.
enum TimelineEntry: Hashable {
    case message(UUID)
    case offer(String)

    var isOffer: Bool {
        if case .offer = self { return true }
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
    @State private var pendingMessageUUID: String?
    @State private var showCounterOfferSheet = false
    @State private var isRespondingToOffer = false
    @State private var offerError: String?
    @State private var offerModalSubmitting = false
    @State private var showPayNowCover = false
    @State private var showReportUserSheet = false
    @State private var payNowProducts: [Item] = []
    @State private var payNowTotalPrice: Double = 0
    /// Fetched product for offer-conversation header (thumbnail + price bar).
    @State private var offerProductItem: Item?
    /// Offer cards to show: [previous, …] + current. After sending a counter we append optimistically so previous card shows greyed button.
    @State private var offerHistory: [OfferInfo] = []

    private let productService = ProductService()

    /// In-memory cache of offer chain per conversation so reloading the chat restores previous offers (API only returns latest).
    private static var offerHistoryCache: [String: [OfferInfo]] = [:]
    /// Order of items in the chat (message vs offer card) so every element keeps their position (X, Y, X, Y, …).
    @State private var timelineOrder: [TimelineEntry] = []
    private static var timelineOrderCache: [String: [TimelineEntry]] = [:]

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

    /// Current offer cards to show (history + current). Synced from displayedConversation.offer when it changes.
    private var offerCards: [OfferInfo] {
        if offerHistory.isEmpty, let offer = displayedConversation.offer {
            return [offer]
        }
        return offerHistory
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

    @ViewBuilder
    private func timelineRow(timelineIndex: Int, entry: TimelineEntry) -> some View {
        switch entry {
        case .message(let messageId):
            if let index = displayedMessages.firstIndex(where: { $0.id == messageId }),
               index < displayedMessages.count {
                let message = displayedMessages[index]
                let topPadding: CGFloat = timelineIndex == 0 ? 0 : (isSameGroupAsPrevious(timelineIndex: timelineIndex, message: message) ? Theme.Spacing.xs : Theme.Spacing.md)
                Group {
                    if message.isSoldConfirmation {
                        SoldConfirmationBannerView(
                            message: message,
                            isSeller: message.senderUsername != authService.username,
                            conversationId: displayedConversation.id
                        )
                        .id(message.id)
                    } else {
                        let isCurrentUser = message.senderUsername == authService.username
                        MessageBubbleView(
                            message: message,
                            isCurrentUser: isCurrentUser,
                            showAvatar: showAvatarForMessage(at: index),
                            showTimestamp: showTimestampForMessage(at: index),
                            avatarURL: showAvatarForMessage(at: index) ? displayedConversation.recipient.avatarURL : nil,
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
                .padding(.top, topPadding)
            }
        case .offer(let offerId):
            if let offer = offerCards.first(where: { $0.id == offerId }) {
                let isLatest = offer.id == offerCards.last?.id
                let prevIsOffer = (timelineIndex > 0 && timelineIndex - 1 < timelineOrder.count) && (timelineOrder[timelineIndex - 1].isOffer)
                let topPadding: CGFloat = timelineIndex == 0 ? 0 : (prevIsOffer ? 0 : Theme.Spacing.md)
                Group {
                    if timelineIndex > 0, timelineIndex - 1 < timelineOrder.count, timelineOrder[timelineIndex - 1].isOffer {
                        Rectangle()
                            .fill(Theme.Colors.glassBorder)
                            .frame(height: 0.5)
                    }
                    OfferCardView(
                        offer: offer,
                        currentUsername: authService.username,
                        isSeller: isSeller,
                        isResponding: isLatest ? isRespondingToOffer : false,
                        errorMessage: isLatest ? offerError : nil,
                        onAccept: { await handleRespondToOffer(action: "ACCEPT") },
                        onDecline: { await handleRespondToOffer(action: "REJECT") },
                        onSendNewOffer: { showCounterOfferSheet = true },
                        onPayNow: { presentPayNow() },
                        forceGreyedOut: !isLatest
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.background)
                    .id(isLatest ? "latest_offer_card" : offer.id)
                }
                .padding(.top, topPadding)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if displayedConversation.offer != nil {
                offerProductHeaderBar
                Rectangle()
                    .fill(Theme.Colors.glassBorder)
                    .frame(height: 0.5)
            }
            if displayedConversation.order != nil {
                orderHeaderBar
                Rectangle()
                    .fill(Theme.Colors.glassBorder)
                    .frame(height: 0.5)
            }
            if let item = item {
                ChatProductCardView(item: item)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.background)
                if !offerCards.isEmpty {
                    Rectangle()
                        .fill(Theme.Colors.glassBorder)
                        .frame(height: 0.5)
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let order = displayedConversation.order {
                            OrderConfirmationCardView(order: order)
                                .padding(.bottom, Theme.Spacing.sm)
                        }
                        ForEach(Array(timelineOrder.enumerated()), id: \.offset) { timelineIndex, entry in
                            timelineRow(timelineIndex: timelineIndex, entry: entry)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: timelineOrder.count) { _, newCount in
                    guard newCount > 0 else { return }
                    let last = timelineOrder[newCount - 1]
                    withAnimation(.easeOut(duration: 0.2)) {
                        switch last {
                        case .message(let id): proxy.scrollTo(id, anchor: .bottom)
                        case .offer(let id): proxy.scrollTo(id == offerCards.last?.id ? "latest_offer_card" : id, anchor: .bottom)
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
                onDismiss: { showCounterOfferSheet = false },
                detents: item != nil ? [.height(480)] : [.height(340)],
                useCustomCornerRadius: false
            ) {
                OfferModalContent(
                    item: item,
                    listingPrice: item == nil ? (displayedConversation.offer?.offerPrice ?? 0) * 2 : nil,
                    onSubmit: { newPrice in
                        showCounterOfferSheet = false
                        Task {
                            if displayedConversation.offer?.isRejected == true {
                                await handleCreateNewOffer(offerPrice: newPrice)
                            } else {
                                await handleRespondToOffer(action: "COUNTER", offerPrice: newPrice)
                            }
                        }
                    },
                    onDismiss: { showCounterOfferSheet = false },
                    isSubmitting: $offerModalSubmitting,
                    errorMessage: $offerError
                )
            }
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
            connectWebSocket()
            fetchOfferProductIfNeeded()
            syncOfferHistoryFromConversation()
            loadConversationAndMessagesFromBackend()
        }
        .onChange(of: displayedConversation.offer?.id) { _, _ in
            fetchOfferProductIfNeeded()
        }
        .onChange(of: displayedConversation.offer) { _, _ in
            syncLastOfferFromConversation()
        }
        .onChange(of: displayedConversation.id) { _, _ in
            offerHistory = []
            timelineOrder = []
            syncOfferHistoryFromConversation()
        }
        .onDisappear {
            if !offerHistory.isEmpty {
                Self.offerHistoryCache[displayedConversation.id] = offerHistory
            }
            if !timelineOrder.isEmpty {
                Self.timelineOrderCache[displayedConversation.id] = timelineOrder
            }
            if let last = messages.last, displayedConversation.id != "0", let tc = tabCoordinator {
                let previewText = last.isSoldConfirmation ? "Order confirmed" : (last.content.count > 60 ? String(last.content.prefix(57)) + "..." : last.content)
                tc.lastMessagePreviewForConversation = (displayedConversation.id, previewText, last.timestamp)
            }
            webSocket?.disconnect()
            webSocket = nil
        }
    }

    /// After receiving sold_confirmation via WebSocket, refetch conversation so we get order from backend when it has been linked.
    private func refetchConversationForOrder() async {
        let convId = displayedConversation.id
        guard let conv = try? await chatService.getConversationById(conversationId: convId) else { return }
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
            let updatedConv: Conversation? = try? await chatService.getConversationById(conversationId: convId)
            let msgs: [Message] = (try? await chatService.getMessages(conversationId: convId)) ?? []
            await MainActor.run {
                guard displayedConversation.id == convId else { return }
                if let conv = updatedConv {
                    displayedConversation = conv
                }
                self.messages = msgs
                self.isLoading = false
                rebuildTimelineOrder()
                if displayedConversation.order == nil, msgs.contains(where: { $0.isSoldConfirmation }) {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await refetchConversationForOrder()
                    }
                }
            }
            if !msgs.isEmpty {
                let idsToMarkRead = msgs
                    .filter { $0.senderUsername != authService.username }
                    .compactMap(\.backendId)
                if !idsToMarkRead.isEmpty {
                    _ = try? await chatService.readMessages(messageIds: idsToMarkRead)
                }
            }
        }
    }

    /// Restore offer chain from cache when reloading chat; merge with server's latest offer so we keep previous cards.
    private func syncOfferHistoryFromConversation() {
        let convId = displayedConversation.id
        guard let serverOffer = displayedConversation.offer else {
            offerHistory = Self.offerHistoryCache[convId] ?? []
            rebuildTimelineOrder()
            return
        }
        if let cached = Self.offerHistoryCache[convId], !cached.isEmpty {
            if cached.last?.id == serverOffer.id {
                offerHistory = cached.dropLast() + [serverOffer]
            } else {
                offerHistory = cached + [serverOffer]
            }
        } else if offerHistory.isEmpty {
            offerHistory = [serverOffer]
        }
        rebuildTimelineOrder()
    }

    /// Build or restore timeline order so messages and offer cards keep their positions (X, Y, X, Y, …).
    private func rebuildTimelineOrder() {
        let convId = displayedConversation.id
        let offers = offerCards
        let msgs = displayedMessages
        if let cached = Self.timelineOrderCache[convId], !cached.isEmpty {
            let offerIds = Set(offers.map(\.id))
            let messageIds = Set(msgs.map(\.id))
            var filtered: [TimelineEntry] = cached.filter { entry in
                switch entry {
                case .message(let id): return messageIds.contains(id)
                case .offer(let id): return offerIds.contains(id)
                }
            }
            var existingIds = Set<String>()
            for e in filtered {
                switch e {
                case .message(let id): existingIds.insert("m\(id.uuidString)")
                case .offer(let id): existingIds.insert("o\(id)")
                }
            }
            for o in offers where !existingIds.contains("o\(o.id)") {
                filtered.append(.offer(o.id))
                existingIds.insert("o\(o.id)")
            }
            for m in msgs where !existingIds.contains("m\(m.id.uuidString)") {
                filtered.append(.message(m.id))
            }
            timelineOrder = filtered
        } else if timelineOrder.isEmpty {
            timelineOrder = offers.map { .offer($0.id) } + msgs.map { .message($0.id) }
        } else {
            var merged = timelineOrder
            for o in offers where !merged.contains(where: { if case .offer(let id) = $0 { return id == o.id }; return false }) {
                merged.append(.offer(o.id))
            }
            for m in msgs where !merged.contains(where: { if case .message(let id) = $0 { return id == m.id }; return false }) {
                merged.append(.message(m.id))
            }
            timelineOrder = merged
        }
    }

    /// Update only the last offer card when the server pushes an offer update (e.g. declined). Keeps previous cards as snapshots.
    /// Never overwrite an optimistic (pending-*) card with the server's OLD offer — only when server has the new offer or status update for the same offer.
    private func syncLastOfferFromConversation() {
        guard let serverOffer = displayedConversation.offer else { return }
        if offerHistory.isEmpty {
            offerHistory = [serverOffer]
            return
        }
        let lastIndex = offerHistory.count - 1
        let last = offerHistory[lastIndex]
        let lastIsOptimistic = last.id.hasPrefix("pending-")
        // If the last card is our optimistic placeholder, do NOT replace it with the server's OLD offer (same id and same price as first card).
        if lastIsOptimistic, offerHistory.count >= 2 {
            let first = offerHistory[0]
            if serverOffer.id == first.id && abs(serverOffer.offerPrice - first.offerPrice) < 0.01 {
                // Server returned the previous offer again — don't overwrite our new optimistic card.
                return
            }
        }
        let isLastSameOffer = last.id == serverOffer.id || lastIsOptimistic
        if isLastSameOffer {
            var next = offerHistory
            next[lastIndex] = serverOffer
            offerHistory = next
            Self.offerHistoryCache[displayedConversation.id] = offerHistory
        }
    }

    /// Create a new offer (same products) when the current offer is declined — backend rejects COUNTER on cancelled offers.
    private func handleCreateNewOffer(offerPrice: Double) async {
        guard let offer = displayedConversation.offer,
              let productIds = offer.products?.compactMap({ p in p.id.flatMap(Int.init) }),
              !productIds.isEmpty else {
            await MainActor.run { offerError = "Could not load product" }
            return
        }
        await MainActor.run {
            isRespondingToOffer = true
            offerError = nil
            let cards = offerCards
            let optimistic = OfferInfo(id: "pending-\(UUID().uuidString)", status: "PENDING", offerPrice: offerPrice, buyer: offer.buyer, products: offer.products)
            offerHistory = cards + [optimistic]
            timelineOrder.append(.offer(optimistic.id))
        }
        do {
            let (_, newConv) = try await productService.createOffer(offerPrice: offerPrice, productIds: productIds, message: nil)
            let convs = try await chatService.getConversations()
            await MainActor.run {
                if let updated = convs.first(where: { $0.id == displayedConversation.id }) {
                    displayedConversation = updated
                    if let serverOffer = updated.offer, !offerHistory.isEmpty {
                        var next = offerHistory
                        next[next.count - 1] = serverOffer
                        offerHistory = next
                        Self.offerHistoryCache[displayedConversation.id] = offerHistory
                        if let last = timelineOrder.last, case .offer(let pid) = last, pid.hasPrefix("pending-") {
                            timelineOrder[timelineOrder.count - 1] = .offer(serverOffer.id)
                        }
                    }
                } else if let newConv = newConv, newConv.id == displayedConversation.id, let serverOffer = newConv.offer, !offerHistory.isEmpty {
                    displayedConversation = newConv
                    var next = offerHistory
                    next[next.count - 1] = serverOffer
                    offerHistory = next
                    Self.offerHistoryCache[displayedConversation.id] = offerHistory
                    if let last = timelineOrder.last, case .offer(let pid) = last, pid.hasPrefix("pending-") {
                        timelineOrder[timelineOrder.count - 1] = .offer(serverOffer.id)
                    }
                }
                isRespondingToOffer = false
                offerError = nil
            }
        } catch {
            await MainActor.run {
                if !offerHistory.isEmpty { offerHistory = Array(offerHistory.dropLast()) }
                if let last = timelineOrder.last, case .offer(let pid) = last, pid.hasPrefix("pending-") { timelineOrder.removeLast() }
                isRespondingToOffer = false
                offerError = error.localizedDescription
            }
        }
    }

    private func handleRespondToOffer(action: String, offerPrice: Double? = nil) async {
        guard let offer = displayedConversation.offer, let offerId = offer.offerIdInt else { return }
        let isCounter = action == "COUNTER"
        let newPrice = offerPrice ?? offer.offerPrice
        if isCounter {
            await MainActor.run {
                let cards = offerCards
                let optimistic = OfferInfo(id: "pending-\(UUID().uuidString)", status: "PENDING", offerPrice: newPrice, buyer: offer.buyer, products: offer.products)
                offerHistory = cards + [optimistic]
                timelineOrder.append(.offer(optimistic.id))
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
                if let updated = convs.first(where: { $0.id == displayedConversation.id }) {
                    displayedConversation = updated
                    if isCounter, let serverOffer = updated.offer {
                        if !offerHistory.isEmpty {
                            let previous = offerHistory.dropLast()
                            let firstOffer = offerHistory.first
                            let lastWasOptimistic = offerHistory.last?.id.hasPrefix("pending-") == true
                            // Only replace optimistic with server data if server has the offer we just sent (same price) or a clearly new offer (different id).
                            let serverMatchesSentPrice = abs(serverOffer.offerPrice - newPrice) < 0.01
                            let serverIsNewOffer = firstOffer == nil || serverOffer.id != firstOffer!.id
                            if lastWasOptimistic && (serverMatchesSentPrice || serverIsNewOffer) {
                                offerHistory = Array(previous) + [serverOffer]
                                Self.offerHistoryCache[displayedConversation.id] = offerHistory
                                if let last = timelineOrder.last, case .offer(let pid) = last, pid.hasPrefix("pending-") {
                                    timelineOrder[timelineOrder.count - 1] = .offer(serverOffer.id)
                                }
                            }
                        } else {
                            offerHistory = [serverOffer]
                            Self.offerHistoryCache[displayedConversation.id] = offerHistory
                        }
                    }
                }
                isRespondingToOffer = false
                offerError = nil
            }
        } catch {
            await MainActor.run {
                if isCounter, !offerHistory.isEmpty {
                    offerHistory = Array(offerHistory.dropLast())
                }
                if isCounter, let last = timelineOrder.last, case .offer(let pid) = last, pid.hasPrefix("pending-") {
                    timelineOrder.removeLast()
                }
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

    /// Second header: product thumbnail (default 1:1) + latest offer price; tappable -> product page.
    /// Order header bar (sale confirmation) when conversation has an order.
    private var orderHeaderBar: some View {
        guard let order = displayedConversation.order else { return AnyView(EmptyView()) }
        let priceStr = String(format: "£%.2f", order.total)
        let bar = HStack(spacing: Theme.Spacing.md) {
            Group {
                if let urlString = order.firstProductImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Rectangle().fill(Theme.Colors.secondaryBackground).overlay(Image(systemName: "photo").foregroundColor(Theme.Colors.secondaryText))
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Theme.Colors.secondaryBackground)
                        .overlay(Image(systemName: "bag.fill").font(.body).foregroundColor(Theme.Colors.secondaryText))
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
                Text(order.status)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
        return AnyView(bar)
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
                        default: Rectangle().fill(Theme.Colors.secondaryBackground).overlay(Image(systemName: "photo").foregroundColor(Theme.Colors.secondaryText))
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Theme.Colors.secondaryBackground)
                        .overlay(Image(systemName: "photo").font(.body).foregroundColor(Theme.Colors.secondaryText))
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
        Task {
            if let product = try? await productService.getProduct(id: firstId) {
                await MainActor.run { offerProductItem = product }
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
            if msg.isSoldConfirmation, displayedConversation.order == nil {
                Task { await refetchConversationForOrder() }
            }
        }
        webSocket = ws
        ws.connect()
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
                    self.rebuildTimelineOrder()
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
    /// When true, show only offer line + status and a disabled/greyed "Send new offer" (for previous cards).
    var forceGreyedOut: Bool = false

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

    /// Hide status label when Pending or Countered (per design: don't show "COUNTERED" / "Pending" on cards).
    private var shouldShowStatus: Bool {
        let s = (offer.status ?? "").uppercased()
        return s != "PENDING" && s != "COUNTERED"
    }

    /// True when this offer was sent by the current user (buyer).
    private var isMyOffer: Bool { offer.buyer?.username == currentUsername }

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

            if forceGreyedOut {
                // Previous card: show active "Send new offer" for my offers, disabled for others.
                if isMyOffer {
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
                } else {
                    Button(action: {}) {
                        Text("Send new offer")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            .foregroundColor(Theme.Colors.secondaryText)
                            .cornerRadius(22)
                    }
                    .disabled(true)
                }
            } else if isSeller && offer.isPending {
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
            } else if !isSeller && offer.isPending {
                Button(action: onSendNewOffer) {
                    Text("Send new offer")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(22)
                }
                .disabled(isResponding)
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
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primaryColor, lineWidth: 1))
                        .foregroundColor(Theme.primaryColor)
                        .cornerRadius(22)
                }
                .disabled(isResponding)
            } else if !isSeller && !offer.isAccepted {
                // My offer in any other state (e.g. COUNTERED): always show Send new offer.
                Button(action: onSendNewOffer) {
                    Text("Send new offer")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(22)
                }
                .disabled(isResponding)
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

/// Order confirmation card shown at top of chat when conversation has an order (sale details).
struct OrderConfirmationCardView: View {
    let order: ConversationOrder

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.primaryColor)
                Text("Order confirmed")
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
                Text(order.status)
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
