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
    @ObservedObject var inboxViewModel: InboxViewModel
    @Binding var path: [AppRoute]
    @State private var searchText: String = ""
    @State private var scrollPosition: String? = "inbox_top"
    /// Inbox filter from 3-dot menu: all, unread, read, archived.
    @State private var inboxFilter: InboxFilter = .all

    private var conversations: [Conversation] { inboxViewModel.conversations }
    private var isLoading: Bool { inboxViewModel.isLoading }
    private var errorMessage: String? { inboxViewModel.errorMessage }

    init(tabCoordinator: TabCoordinator, path: Binding<[AppRoute]>, inboxViewModel: InboxViewModel) {
        self.tabCoordinator = tabCoordinator
        _path = path
        self.inboxViewModel = inboxViewModel
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
                                inboxViewModel.errorMessage = nil
                                inboxViewModel.refresh()
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
                                .buttonStyle(PlainTappableButtonStyle())
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
                                Task { await loadInboxConversations() }
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
                        await loadInboxConversations()
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
                Task { await loadInboxConversations() }
            }
            if tabCoordinator.openInboxListOnly {
                tabCoordinator.openInboxListOnly = false
                path = []
                guard !authService.isGuestMode else { return }
                inboxViewModel.updateAuthToken(authService.authToken)
                inboxViewModel.refresh()
                return
            }
            if path.isEmpty, let preview = tabCoordinator.lastMessagePreviewForConversation {
                inboxViewModel.updatePreview(conversationId: preview.id, text: preview.text, date: preview.date)
                tabCoordinator.lastMessagePreviewForConversation = nil
            }
            if let conv = tabCoordinator.pendingOpenConversation {
                tabCoordinator.pendingOpenConversation = nil
                DispatchQueue.main.async { path = [.conversation(conv)] }
            }
            guard !authService.isGuestMode else { return }
            inboxViewModel.updateAuthToken(authService.authToken)
            if conversations.isEmpty && !isLoading {
                inboxViewModel.refresh()
            }
        }
        .onChange(of: path.count) { oldCount, newCount in
            if oldCount > 0, newCount == 0, !authService.isGuestMode {
                if let preview = tabCoordinator.lastMessagePreviewForConversation {
                    inboxViewModel.updatePreview(conversationId: preview.id, text: preview.text, date: preview.date)
                    tabCoordinator.lastMessagePreviewForConversation = nil
                }
                Task { await loadInboxConversations() }
            }
        }
        .onChange(of: tabCoordinator.pendingOpenConversation) { _, pending in
            guard let conv = pending else { return }
            tabCoordinator.pendingOpenConversation = nil
            Task {
                await loadInboxConversations()
                await MainActor.run {
                    if !conversations.contains(where: { $0.id == conv.id }) {
                        inboxViewModel.prependConversation(Conversation(
                            id: conv.id,
                            recipient: conv.recipient,
                            lastMessage: conv.lastMessage,
                            lastMessageTime: conv.lastMessageTime ?? Date(),
                            unreadCount: conv.unreadCount,
                            offer: conv.offer,
                            order: conv.order
                        ))
                    }
                    path = [.conversation(conv)]
                }
            }
        }
        .onChange(of: authService.authToken) { _, newToken in
            inboxViewModel.updateAuthToken(newToken)
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        guard let convId = Int(conversation.id) else { return }
        Task { await inboxViewModel.deleteConversation(conversationId: convId) }
    }

    /// Load conversations (with optional preview from tabCoordinator) and clear preview after.
    private func loadInboxConversations() async {
        let preview = tabCoordinator.lastMessagePreviewForConversation
        let previewTuple: (id: String, text: String, date: Date)? = preview.map { ($0.id, $0.text, $0.date) }
        await inboxViewModel.loadConversationsAsync(preview: previewTuple)
        if preview != nil { tabCoordinator.lastMessagePreviewForConversation = nil }
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
            let title = PreluraSupportBranding.displayTitle(forRecipientUsername: $0.recipient.username).lowercased()
            return $0.recipient.username.lowercased().contains(query)
                || title.contains(query)
                || ($0.lastMessage?.lowercased().contains(query) ?? false)
        }
    }

}


struct ChatRowView: View {
    let conversation: Conversation
    var currentUsername: String?

    private static var offerProductImageCache: [Int: String] = [:]
    private let productService = ProductService()

    @State private var loadedOfferProductImageURL: String?
    @State private var isLoadingOfferProductImage = false

    /// Interpret `1:13` as `width:height = 1:1.3` (so the thumbnail isn't extremely thin).
    private static let productThumbWidthToHeightRatio: CGFloat = 1.0 / 1.3
    private static let productThumbHeight: CGFloat = 44

    private var offerThumbProductId: Int? {
        guard conversation.order == nil else { return nil } // order thumbnails come from `conversation.order`
        return conversation.offer?.products?.first?.id.flatMap { Int($0) }
    }

    private var productImageURL: URL? {
        if let s = conversation.order?.firstProductImageUrl, !s.isEmpty {
            return ProductListImageURL.url(forListDisplay: s)
        }
        if let id = offerThumbProductId {
            if let s = Self.offerProductImageCache[id] ?? loadedOfferProductImageURL, !s.isEmpty {
                return ProductListImageURL.url(forListDisplay: s) ?? URL(string: s)
            }
        }
        return nil
    }

    private func loadOfferProductThumbnailIfNeeded(for productId: Int) async {
        if isLoadingOfferProductImage { return }
        if let cached = Self.offerProductImageCache[productId] {
            await MainActor.run { loadedOfferProductImageURL = cached }
            return
        }
        isLoadingOfferProductImage = true
        defer { isLoadingOfferProductImage = false }

        guard let product = try? await productService.getProduct(id: productId) else { return }
        let thumbURL = product.thumbnailURLForChrome
        await MainActor.run {
            guard let thumbURL, !thumbURL.isEmpty else { return }
            Self.offerProductImageCache[productId] = thumbURL
            loadedOfferProductImageURL = thumbURL
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar (branded for system Prelura Support account)
            if PreluraSupportBranding.isSupportRecipient(username: conversation.recipient.username) {
                PreluraSupportBranding.supportAvatar(size: 50)
            } else if let avatarURL = conversation.recipient.avatarURL, let url = URL(string: avatarURL) {
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
                HStack(spacing: Theme.Spacing.xs) {
                    Text(PreluraSupportBranding.displayTitle(forRecipientUsername: conversation.recipient.username))
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)

                    if let time = conversation.lastMessageTime {
                        Text("• \(formatTime(time))")
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

            Spacer(minLength: 0)

            // Product thumbnail (right side).
            ZStack(alignment: .topTrailing) {
                Group {
                    if let url = productImageURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ImageShimmerPlaceholderFilled(cornerRadius: 8)
                        }
                    } else {
                        ImageShimmerPlaceholderFilled(cornerRadius: 8)
                    }
                }
                .frame(
                    width: productThumbWidth,
                    height: Self.productThumbHeight
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Unread badge overlay.
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primaryColor)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.xs)
        .task(id: offerThumbProductId) {
            // Only fetch thumbnail for offer conversations when we don't already have one.
            guard let productId = offerThumbProductId else { return }
            if conversation.order != nil { return }
            if Self.offerProductImageCache[productId] != nil { return }
            guard loadedOfferProductImageURL == nil, !isLoadingOfferProductImage else { return }
            await loadOfferProductThumbnailIfNeeded(for: productId)
        }
    }

    private var productThumbWidth: CGFloat {
        Self.productThumbHeight * Self.productThumbWidthToHeightRatio
    }
    
    private func formatTime(_ date: Date) -> String {
        let now = Date()
        if now.timeIntervalSince(date) < 60 {
            return L10n.string("Just now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let str = formatter.localizedString(for: date, relativeTo: now)
        // iOS formatter returns values like "6 min ago"; UI wants just "6 min".
        if str.lowercased().hasSuffix(" ago") {
            return String(str.dropLast(4))
        }
        return str
    }

    /// Case-insensitive username match so backend "Testuser" matches "testuser".
    fileprivate static func usernamesMatch(_ a: String?, _ b: String?) -> Bool {
        guard let a = a?.trimmingCharacters(in: .whitespaces).lowercased(),
              let b = b?.trimmingCharacters(in: .whitespaces).lowercased(),
              !a.isEmpty, !b.isEmpty else { return false }
        return a == b
    }

    /// Human-readable preview for list. Use last message sender: if I sent the last message (offer), "You sent an offer"; else "Offer received". When there's an order, show order summary. Accepted offers use `updatedBy` / accepter for copy.
    static func previewText(for raw: String?, conversation: Conversation, currentUsername: String?) -> String? {
        if let offer = conversation.offer, offer.isAccepted, conversation.order == nil {
            let accepter = offer.updatedByUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let accepter, !accepter.isEmpty {
                if usernamesMatch(accepter, currentUsername) {
                    return "You accepted an offer"
                }
                return "\(accepter) accepted your offer"
            }
            return "Offer accepted"
        }
        /// True when the current user sent the latest offer (last message sender matches).
        let iSentLastOffer = usernamesMatch(conversation.lastMessageSenderUsername, currentUsername)
        guard let raw = raw, !raw.isEmpty else {
            if conversation.offer != nil, iSentLastOffer {
                return "You sent an offer"
            }
            if conversation.offer != nil {
                return "Offer received"
            }
            if let order = conversation.order {
                return String(format: "Order • £%.2f", order.total)
            }
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("offer_id") || (trimmed.hasPrefix("{") && (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) as? [String: Any])?["offer_id"] != nil) {
            return iSentLastOffer ? "You sent an offer" : "Offer received"
        }
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return raw.count > 60 ? String(raw.prefix(57)) + "..." : raw
        }
        switch type {
        case "order_issue":
            if usernamesMatch(conversation.lastMessageSenderUsername, currentUsername) {
                return "You reported an issue"
            }
            if let sender = conversation.lastMessageSenderUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !sender.isEmpty {
                return "\(sender) reported an issue"
            }
            return "Issue reported"
        case "order": return "Order update"
        case "offer": return iSentLastOffer ? "You sent an offer" : "Offer received"
        case "account_report": return Message.humanReadableReportLine(json: json, reportType: type, maxLength: 56)
        case "product_report": return Message.humanReadableReportLine(json: json, reportType: type, maxLength: 56)
        case "sold_confirmation":
            // Seller = person who listed the product (offer’s product seller). Buyer sees "Order confirmed".
            if usernamesMatch(conversation.offer?.products?.first?.seller?.username, currentUsername) {
                return "You made a sale 🎉"
            }
            return "Order confirmed"
        default: return raw.count > 60 ? String(raw.prefix(57)) + "..." : raw
        }
    }
}

#Preview {
    ChatListView(tabCoordinator: TabCoordinator(), path: .constant([]), inboxViewModel: InboxViewModel())
        .preferredColorScheme(.dark)
}
