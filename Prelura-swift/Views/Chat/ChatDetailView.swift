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

/// One item in the chat timeline: message, offer card, or order card. Sorted by time.
enum TimelineEntry: Hashable {
    case message(UUID)
    case offer(String)
    case order(String)

    var isOffer: Bool {
        if case .offer = self { return true }
        return false
    }
    var isOrder: Bool {
        if case .order = self { return true }
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
    /// Fetched product for order-conversation header (sale confirmation bar); enables tap-to-open product.
    @State private var orderProductItem: Item?
    /// Single source of truth for offer cards. UI = source of truth; server used only to seed on load or confirm after send.
    @State private var offers: [OfferInfo] = []

    private let productService = ProductService()

    /// Cache for re-open: restore offers when returning to chat (API only returns latest).
    private static var offerHistoryCache: [String: [OfferInfo]] = [:]
    private static let offerHistoryUserDefaultsPrefix = "offerHistory_"
    /// Order of items in the chat (message vs offer card), sorted by date.
    @State private var timelineOrder: [TimelineEntry] = []
    private static var timelineOrderCache: [String: [TimelineEntry]] = [:]

    private static func persistOfferHistory(convId: String, offers: [OfferInfo]) {
        guard let data = try? JSONEncoder().encode(offers) else { return }
        UserDefaults.standard.set(data, forKey: offerHistoryUserDefaultsPrefix + convId)
    }

    private static func loadOfferHistory(convId: String) -> [OfferInfo]? {
        guard let data = UserDefaults.standard.data(forKey: offerHistoryUserDefaultsPrefix + convId),
              let offers = try? JSONDecoder().decode([OfferInfo].self, from: data) else { return nil }
        return offers
    }

    init(conversation: Conversation, item: Item? = nil) {
        self.conversation = conversation
        self.item = item
        _displayedConversation = State(initialValue: conversation)
    }

    private var recipientTitle: String {
        !displayedConversation.recipient.displayName.isEmpty ? displayedConversation.recipient.displayName : displayedConversation.recipient.username
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
                .padding(.top, topPadding)
            }
        case .offer(let offerId):
            if let offer = offers.first(where: { $0.id == offerId }) {
                let isLatest = offer.id == offers.last?.id
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
                        forceGreyedOut: !isLatest || displayedConversation.order != nil
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.background)
                    .id(isLatest ? "latest_offer_card" : offer.id)
                }
                .padding(.top, topPadding)
            }
        case .order(let orderId):
            if let order = displayedConversation.order, order.id == orderId {
                let prevIsOfferOrOrder = (timelineIndex > 0 && timelineIndex - 1 < timelineOrder.count) && (timelineOrder[timelineIndex - 1].isOffer || timelineOrder[timelineIndex - 1].isOrder)
                let topPadding: CGFloat = timelineIndex == 0 ? 0 : (prevIsOfferOrOrder ? 0 : Theme.Spacing.md)
                Group {
                    if timelineIndex > 0, timelineIndex - 1 < timelineOrder.count, timelineOrder[timelineIndex - 1].isOffer || timelineOrder[timelineIndex - 1].isOrder {
                        Rectangle()
                            .fill(Theme.Colors.glassBorder)
                            .frame(height: 0.5)
                    }
                    OrderConfirmationCardView(order: order)
                        .id("order_\(order.id)")
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .padding(.top, topPadding)
            }
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
                        ForEach(Array(timelineOrder.enumerated()), id: \.1) { timelineIndex, entry in
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
                        case .offer(let id): proxy.scrollTo(id == offers.last?.id ? "latest_offer_card" : id, anchor: .bottom)
                        case .order(let orderId): proxy.scrollTo("order_\(orderId)", anchor: .bottom)
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
                    listingPrice: nil,
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
            loadOffers()
        }
        .onDisappear {
            if !offers.isEmpty {
                Self.offerHistoryCache[displayedConversation.id] = offers
                Self.persistOfferHistory(convId: displayedConversation.id, offers: offers)
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
                // Do not call loadOffers() here: it can race with the send-success block and overwrite the just-sent offer with stale server data. Offers are loaded on appear and when conversation id changes; loadOffers() also guards against overwriting a recently added offer.
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

    /// Single source of truth load: restore offers from cache when re-opening chat, or seed from server when empty. No merge, no sync override.
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
        if Self.offerHistoryCache[convId] == nil, let persisted = Self.loadOfferHistory(convId: convId), !persisted.isEmpty {
            Self.offerHistoryCache[convId] = persisted.map { o in
                OfferInfo(id: o.id, status: o.status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date())
            }
        }
        if let cached = Self.offerHistoryCache[convId], !cached.isEmpty {
            offers = cached.map { o in OfferInfo(id: o.id, status: o.status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date()) }
        } else if let serverOffer = displayedConversation.offer {
            offers = [
                OfferInfo(
                    id: serverOffer.id,
                    status: serverOffer.status,
                    offerPrice: serverOffer.offerPrice,
                    buyer: serverOffer.buyer,
                    products: serverOffer.products,
                    createdAt: serverOffer.createdAt ?? Date()
                )
            ]
        } else {
            offers = []
        }
        rebuildTimelineOrder()
    }

    /// Build timeline order by merging offers, messages, and order card; sort by date.
    private func rebuildTimelineOrder() {
        let offerList = offers
        let msgs = displayedMessages
        var entries: [(Date, TimelineEntry)] = []
        for o in offerList {
            entries.append((o.createdAt ?? .distantPast, .offer(o.id)))
        }
        for m in msgs {
            entries.append((m.timestamp, .message(m.id)))
        }
        if let order = displayedConversation.order {
            let orderDate = order.createdAt ?? .distantPast
            entries.append((orderDate, .order(order.id)))
        }
        entries.sort { $0.0 < $1.0 }
        timelineOrder = entries.map(\.1)
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
            let optimistic = OfferInfo(id: UUID().uuidString, status: "PENDING", offerPrice: offerPrice, buyer: offer.buyer, products: offer.products, createdAt: Date())
            offers = offers + [optimistic]
            timelineOrder = timelineOrder + [.offer(optimistic.id)]
        }
        do {
            let (_, newConv) = try await productService.createOffer(offerPrice: offerPrice, productIds: productIds, message: nil)
            let convs = try await chatService.getConversations()
            await MainActor.run {
                if let updated = convs.first(where: { $0.id == displayedConversation.id }) {
                    displayedConversation = updated
                }
                // Always replace last (optimistic) with a confirmed card using LOCAL sent price; server may be stale.
                guard let lastIndex = offers.indices.last else {
                    isRespondingToOffer = false
                    offerError = nil
                    return
                }
                let serverOffer = (newConv?.id == displayedConversation.id ? newConv?.offer : nil) ?? displayedConversation.offer
                // Use a unique id when server returned the previous offer (same id already in list); otherwise first(where:) would show wrong card.
                let confirmedId: String
                if let sid = serverOffer?.id, offers.contains(where: { $0.id == sid }) {
                    confirmedId = "\(sid)-\(UUID().uuidString)"
                } else {
                    confirmedId = serverOffer?.id ?? offers[lastIndex].id
                }
                let confirmed = OfferInfo(
                    id: confirmedId,
                    status: serverOffer?.status ?? "PENDING",
                    offerPrice: offerPrice,
                    buyer: serverOffer?.buyer ?? offer.buyer,
                    products: serverOffer?.products ?? offer.products,
                    createdAt: Date()
                )
                var nextOffers = offers
                nextOffers[lastIndex] = confirmed
                offers = nextOffers
                if let idx = timelineOrder.lastIndex(where: { if case .offer = $0 { return true }; return false }) {
                    var nextOrder = timelineOrder
                    nextOrder[idx] = .offer(confirmed.id)
                    timelineOrder = nextOrder
                }
                Self.offerHistoryCache[displayedConversation.id] = offers
                Self.persistOfferHistory(convId: displayedConversation.id, offers: offers)
                isRespondingToOffer = false
                offerError = nil
            }
        } catch {
            await MainActor.run {
                if !offers.isEmpty { offers = Array(offers.dropLast()) }
                if let last = timelineOrder.last, case .offer = last { timelineOrder = Array(timelineOrder.dropLast()) }
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
                let optimistic = OfferInfo(id: UUID().uuidString, status: "PENDING", offerPrice: newPrice, buyer: offer.buyer, products: offer.products, createdAt: Date())
                offers = offers + [optimistic]
                timelineOrder = timelineOrder + [.offer(optimistic.id)]
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
                if isCounter, let lastIndex = offers.indices.last {
                    let serverOffer = updated.offer
                    let confirmedId: String
                    if let sid = serverOffer?.id, offers.contains(where: { $0.id == sid }) {
                        confirmedId = "\(sid)-\(UUID().uuidString)"
                    } else {
                        confirmedId = serverOffer?.id ?? offers[lastIndex].id
                    }
                    let confirmed = OfferInfo(
                        id: confirmedId,
                        status: serverOffer?.status ?? "PENDING",
                        offerPrice: newPrice,
                        buyer: serverOffer?.buyer ?? offer.buyer,
                        products: serverOffer?.products ?? offer.products,
                        createdAt: Date()
                    )
                    var nextOffers = offers
                    nextOffers[lastIndex] = confirmed
                    offers = nextOffers
                    if let idx = timelineOrder.lastIndex(where: { if case .offer = $0 { return true }; return false }) {
                        var nextOrder = timelineOrder
                        nextOrder[idx] = .offer(confirmed.id)
                        timelineOrder = nextOrder
                    }
                    Self.offerHistoryCache[displayedConversation.id] = offers
                    Self.persistOfferHistory(convId: displayedConversation.id, offers: offers)
                } else if action == "ACCEPT" || action == "REJECT", let serverOffer = updated.offer, let lastIndex = offers.indices.last {
                    let last = offers[lastIndex]
                    let updatedOffer = OfferInfo(id: last.id, status: serverOffer.status, offerPrice: last.offerPrice, buyer: last.buyer, products: last.products, createdAt: last.createdAt ?? Date())
                    var nextOffers = offers
                    nextOffers[lastIndex] = updatedOffer
                    offers = nextOffers
                    Self.offerHistoryCache[displayedConversation.id] = offers
                    Self.persistOfferHistory(convId: displayedConversation.id, offers: offers)
                }
                isRespondingToOffer = false
                offerError = nil
            }
        } catch {
            await MainActor.run {
                if isCounter, !offers.isEmpty { offers = Array(offers.dropLast()) }
                if isCounter, let last = timelineOrder.last, case .offer = last { timelineOrder = Array(timelineOrder.dropLast()) }
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

    /// Order header bar: shown in every chat that has an order. Loads the related product so the top bar
    /// shows thumbnail, name, price, status and is tappable to product. Fetched in onAppear and when order changes.
    private var orderHeaderBar: some View {
        guard let order = displayedConversation.order else { return AnyView(EmptyView()) }
        let priceStr = String(format: "£%.2f", order.total)
        let bar = HStack(spacing: Theme.Spacing.md) {
            Group {
                if let urlString = orderProductItem?.imageURLs.first ?? order.firstProductImageUrl,
                   let url = URL(string: urlString) {
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

    private func fetchOrderProductIfNeeded() {
        guard let order = displayedConversation.order,
              let firstId = order.firstProductId.flatMap({ Int($0) }) else {
            orderProductItem = nil
            return
        }
        Task {
            if let product = try? await productService.getProduct(id: firstId) {
                await MainActor.run { orderProductItem = product }
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

    /// Handle NEW_OFFER / UPDATE_OFFER from WebSocket. When backend pushes these, update offers without refetch.
    private func handleOfferSocketEvent(_ event: OfferSocketEvent) {
        if let convId = event.conversationId, convId != displayedConversation.id { return }
        switch event.type {
        case "NEW_OFFER":
            guard let offer = event.offer else { break }
            let lastIsOptimistic = offers.indices.last.map { Int(offers[$0].id) == nil } ?? false
            if lastIsOptimistic, let lastIndex = offers.indices.last {
                let last = offers[lastIndex]
                // Keep the price (and time) the user just sent; server/WebSocket may be stale.
                let resolvedId = offers.contains(where: { $0.id == offer.id }) ? "\(offer.id)-\(UUID().uuidString)" : offer.id
                var nextOffers = offers
                nextOffers[lastIndex] = OfferInfo(id: resolvedId, status: offer.status, offerPrice: last.offerPrice, buyer: offer.buyer, products: offer.products, createdAt: last.createdAt ?? Date())
                offers = nextOffers
                if let idx = timelineOrder.lastIndex(where: { if case .offer = $0 { return true }; return false }) {
                    var nextOrder = timelineOrder
                    nextOrder[idx] = .offer(resolvedId)
                    timelineOrder = nextOrder
                }
            } else if !offers.contains(where: { $0.id == offer.id }) {
                offers = offers + [OfferInfo(id: offer.id, status: offer.status, offerPrice: offer.offerPrice, buyer: offer.buyer, products: offer.products, createdAt: offer.createdAt ?? Date())]
                timelineOrder = timelineOrder + [.offer(offer.id)]
            }
            Self.offerHistoryCache[displayedConversation.id] = offers
            Self.persistOfferHistory(convId: displayedConversation.id, offers: offers)
            rebuildTimelineOrder()
        case "UPDATE_OFFER":
            guard let offerId = event.offerId ?? event.offer?.id, let status = event.status,
                  let idx = offers.firstIndex(where: { $0.id == offerId || $0.id.hasPrefix(offerId + "-") }) else { break }
            let o = offers[idx]
            var nextOffers = offers
            nextOffers[idx] = OfferInfo(id: o.id, status: status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date())
            offers = nextOffers
            Self.offerHistoryCache[displayedConversation.id] = offers
            Self.persistOfferHistory(convId: displayedConversation.id, offers: offers)
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
                return
            }
            if messages.contains(where: { $0.id == msg.id }) { return }
            messages.append(msg)
            messages.sort { $0.timestamp < $1.timestamp }
            if msg.isSoldConfirmation, displayedConversation.order == nil {
                Task { await refetchConversationForOrder() }
            }
        }
        ws.onOfferEvent = { [self] event in
            handleOfferSocketEvent(event)
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
    /// When true, this card was superseded by a newer offer; show only offer line + status (no "Send new offer" button).
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

            if forceGreyedOut {
                // Overwritten by a newer offer: hide "Send new offer" so only the latest card shows it.
            } else if isSeller && offer.isPending {
                VStack(spacing: Theme.Spacing.sm) {
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
                    HStack(spacing: Theme.Spacing.sm) {
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
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.primaryColor)
                                .foregroundColor(.white)
                                .cornerRadius(22)
                        }
                        .disabled(isResponding)
                    }
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
                        .background(Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(22)
                }
                .disabled(isResponding)
            } else if !isSeller && !offer.isAccepted {
                // My offer in any other state (e.g. COUNTERED): primary Send new offer.
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

/// Order confirmation card shown in timeline when conversation has an order (sale details). Includes timestamp for chronological ordering.
struct OrderConfirmationCardView: View {
    let order: ConversationOrder

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
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
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
