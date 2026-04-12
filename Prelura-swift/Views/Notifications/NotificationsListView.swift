import SwiftUI

/// List of in-app notifications (Flutter NotificationsScreen + NotificationsTab).
struct NotificationsListView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var bellUnreadStore: BellUnreadStore
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    /// Next GraphQL page to request (1-based). Chat rows are filtered out unless stale unread.
    @State private var nextBackendPage = 1
    @State private var backendHasMore = true
    private let pageSize = 15
    private let notificationService = NotificationService()

    var body: some View {
        Group {
            if isLoading && notifications.isEmpty && errorMessage == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage, !err.isEmpty, notifications.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(err)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        errorMessage = nil
                        Task { await reloadFromStart() }
                    }
                    .foregroundColor(Theme.primaryColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notifications.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(L10n.string("No notifications"))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(notifications) { notification in
                        NavigationLink(destination: NotificationDestinationView(notification: notification, onMarkRead: { markAsRead(notification) })) {
                            NotificationRowView(notification: notification)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainTappableButtonStyle())
                        .listRowBackground(Theme.Colors.background)
                        .listRowInsets(EdgeInsets(top: 4, leading: Theme.Spacing.md, bottom: 4, trailing: Theme.Spacing.md))
                        .navigationLinkIndicatorVisibility(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteNotification(notification)
                            } label: {
                                Label(L10n.string("Delete"), systemImage: "trash")
                            }
                        }
                    }
                    .listRowBackground(Theme.Colors.background)
                    if backendHasMore {
                        HStack {
                            Spacer()
                            if isLoadingMore { ProgressView() }
                            Spacer()
                        }
                        .onAppear { Task { await loadMoreVisible() } }
                        .listRowBackground(Theme.Colors.background)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Notifications"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await reloadFromStart()
        }
        .onAppear {
            notificationService.updateAuthToken(authService.authToken)
            bellUnreadStore.scheduleRefresh(authService: authService)
            Task { await reloadFromStart() }
        }
        .onChange(of: authService.authToken) { _, newToken in
            notificationService.updateAuthToken(newToken)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .wearhouseInAppNotificationsDidChange, object: nil)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func reloadFromStart() async {
        isLoading = true
        errorMessage = nil
        nextBackendPage = 1
        backendHasMore = true
        defer { isLoading = false }
        do {
            try await fetchVisibleBatch(appending: false)
        } catch {
            await MainActor.run { errorMessage = L10n.userFacingError(error) }
            return
        }
        notificationService.updateAuthToken(authService.authToken)
        do {
            try await notificationService.markAllBellEligibleUnreadRead()
            await MainActor.run {
                notifications = notifications.map { n in
                    guard n.shouldCountTowardBellBadge else { return n }
                    return AppNotification(
                        id: n.id,
                        sender: n.sender,
                        message: n.message,
                        model: n.model,
                        modelId: n.modelId,
                        modelGroup: n.modelGroup,
                        isRead: true,
                        createdAt: n.createdAt,
                        meta: n.meta
                    )
                }
                NotificationCenter.default.post(name: .wearhouseInAppNotificationsDidChange, object: nil)
            }
            bellUnreadStore.scheduleRefresh(authService: authService)
        } catch {
            #if DEBUG
            print("Wearhouse: markAllBellEligibleUnreadRead failed: \(error)")
            #endif
        }
    }

    /// Pulls one or more backend pages until `pageSize` visible rows or API exhaustion.
    private func fetchVisibleBatch(appending: Bool) async throws {
        notificationService.updateAuthToken(authService.authToken)
        var collected: [AppNotification] = []
        var safety = 0
        while collected.count < pageSize && backendHasMore && safety < 40 {
            safety += 1
            let (batch, _) = try await notificationService.getNotifications(pageCount: pageSize, pageNumber: nextBackendPage)
            backendHasMore = batch.count == pageSize
            nextBackendPage += 1
            for n in batch where n.shouldShowOnNotificationsPage() {
                collected.append(n)
            }
            if batch.isEmpty {
                backendHasMore = false
                break
            }
            if collected.count >= pageSize {
                break
            }
        }
        await MainActor.run {
            if appending {
                notifications.append(contentsOf: collected)
            } else {
                notifications = collected
            }
        }
    }

    private func loadMoreVisible() async {
        guard !isLoading, !isLoadingMore, backendHasMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            try await fetchVisibleBatch(appending: true)
        } catch {
            await MainActor.run { errorMessage = L10n.userFacingError(error) }
        }
    }
    
    private func markAsRead(_ notification: AppNotification) {
        guard let idInt = Int(notification.id) else { return }
        Task {
            _ = try? await notificationService.readNotifications(notificationIds: [idInt])
            await MainActor.run {
                NotificationCenter.default.post(name: .wearhouseInAppNotificationsDidChange, object: nil)
                if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
                    notifications[idx] = AppNotification(
                        id: notifications[idx].id,
                        sender: notifications[idx].sender,
                        message: notifications[idx].message,
                        model: notifications[idx].model,
                        modelId: notifications[idx].modelId,
                        modelGroup: notifications[idx].modelGroup,
                        isRead: true,
                        createdAt: notifications[idx].createdAt,
                        meta: notifications[idx].meta
                    )
                }
            }
        }
    }
    
    private func deleteNotification(_ notification: AppNotification) {
        guard let idInt = Int(notification.id) else { return }
        Task {
            do {
                _ = try await notificationService.deleteNotification(notificationId: idInt)
                await MainActor.run {
                    notifications.removeAll { $0.id == notification.id }
                    NotificationCenter.default.post(name: .wearhouseInAppNotificationsDidChange, object: nil)
                }
            } catch {
                await MainActor.run { errorMessage = L10n.userFacingError(error) }
            }
        }
    }
}

// MARK: - Notification tap destination (product, profile, or chat)

/// Resolves and presents the appropriate screen when user taps a notification (matches Flutter NotificationCard navigation).
struct NotificationDestinationView: View {
    let notification: AppNotification
    var onMarkRead: (() -> Void)? = nil
    @EnvironmentObject private var authService: AuthService

    /// Backend sets `meta.is_liked_item_sold` when a favorited listing sells (similar picks screen).
    private var isLikedItemSoldNotification: Bool {
        notification.meta?["is_liked_item_sold"] == "true"
    }

    @State private var resolvedItem: Item?
    @State private var resolvedUser: User?
    @State private var resolvedConversation: Conversation?
    @State private var resolvedLookbookEntry: LookbookEntry?
    @State private var isLoading = true
    @State private var loadError: String?

    private let productService = ProductService()
    private let userService = UserService()
    private let chatService = ChatService()

    var body: some View {
        content
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            productService.updateAuthToken(authService.authToken)
            userService.updateAuthToken(authService.authToken)
            chatService.updateAuthToken(authService.authToken)
            onMarkRead?()
            if isLikedItemSoldNotification {
                isLoading = false
            } else {
                Task { await resolve() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLikedItemSoldNotification {
            LikedItemSoldSimilarView(
                soldProductId: notification.meta?["sold_product_id"] ?? notification.modelId ?? "",
                categoryId: Int(notification.meta?["category_id"] ?? ""),
                suggestionQuery: notification.meta?["suggestion_query"] ?? ""
            )
            .environmentObject(authService)
        } else if isLoading {
            VStack(spacing: Theme.Spacing.md) {
                ProgressView()
                if let err = loadError {
                    Text(err)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
        } else if modelGroupKey == "product", let item = resolvedItem {
            ItemDetailView(item: item, authService: authService)
        } else if modelGroupKey == "userprofile", let user = resolvedUser {
            UserProfileView(seller: user, authService: authService)
        } else if (modelGroupKey == "chat" || modelGroupKey == "offer" || modelGroupKey == "order"), let conv = resolvedConversation {
            ChatDetailView(conversation: conv)
        } else if modelGroupKey == "lookbook", let entry = resolvedLookbookEntry {
            NotificationLookbookDeepLinkHost(entry: entry)
                .environmentObject(authService)
                .environmentObject(SavedLookbookFavoritesStore.shared)
        } else if let err = loadError {
            VStack(spacing: Theme.Spacing.md) {
                Text(err)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
        } else {
            EmptyView()
        }
    }

    private var modelGroupKey: String {
        (notification.modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func resolve() async {
        switch modelGroupKey {
        case "product":
            guard let modelId = notification.modelId, let productId = Int(modelId) else {
                await MainActor.run { loadError = "Invalid product"; isLoading = false }
                return
            }
            do {
                let item = try await productService.getProduct(id: productId)
                await MainActor.run {
                    resolvedItem = item
                    loadError = item == nil ? "Product not found" : nil
                    isLoading = false
                }
            } catch {
                await MainActor.run { loadError = L10n.userFacingError(error); isLoading = false }
            }
        case "userprofile":
            guard let username = notification.sender?.username, !username.isEmpty else {
                await MainActor.run { loadError = "Unknown user"; isLoading = false }
                return
            }
            do {
                let user = try await userService.getUser(username: username)
                await MainActor.run {
                    resolvedUser = user
                    isLoading = false
                }
            } catch {
                await MainActor.run { loadError = L10n.userFacingError(error); isLoading = false }
            }
        case "chat", "offer", "order":
            let convId = notification.meta?["conversation_id"] ?? ""
            let username = notification.sender?.username ?? ""
            let avatarUrl = notification.sender?.profilePictureUrl
            do {
                let convs = try await chatService.getConversations()
                let existing = convs.first { $0.id == convId }
                if let conv = existing {
                    await MainActor.run {
                        resolvedConversation = conv
                        isLoading = false
                    }
                } else {
                    let recipient = User(
                        username: username,
                        displayName: username,
                        avatarURL: avatarUrl
                    )
                    await MainActor.run {
                        resolvedConversation = Conversation(
                            id: convId.isEmpty ? "0" : convId,
                            recipient: recipient,
                            lastMessage: nil,
                            lastMessageTime: nil,
                            unreadCount: 0
                        )
                        isLoading = false
                    }
                }
            } catch {
                let recipient = User(
                    username: username,
                    displayName: username,
                    avatarURL: avatarUrl
                )
                await MainActor.run {
                    resolvedConversation = Conversation(
                        id: convId.isEmpty ? "0" : convId,
                        recipient: recipient,
                        lastMessage: nil,
                        lastMessageTime: nil,
                        unreadCount: 0
                    )
                    isLoading = false
                }
            }
        case "lookbook":
            guard let postId = notification.modelId?.trimmingCharacters(in: .whitespacesAndNewlines), !postId.isEmpty else {
                await MainActor.run { loadError = "Invalid lookbook"; isLoading = false }
                return
            }
            do {
                let client = GraphQLClient()
                if let token = authService.authToken {
                    client.setAuthToken(token)
                }
                let service = LookbookService(client: client)
                guard let post = try await service.fetchLookbookPost(postId: postId) else {
                    await MainActor.run {
                        loadError = "Lookbook not found"
                        isLoading = false
                    }
                    return
                }
                let localRecords = LookbookFeedStore.load()
                let entry = LookbookEntry(
                    from: post,
                    localRecord: localRecords.first { r in r.id == post.id || r.imagePath == post.imageUrl }
                )
                await MainActor.run {
                    resolvedLookbookEntry = entry
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = L10n.userFacingError(error)
                    isLoading = false
                }
            }
        default:
            await MainActor.run { loadError = "Unknown notification type"; isLoading = false }
        }
    }
}

/// Presents the same lookbook post UI as push/deep link, with back popping the notifications stack.
private struct NotificationLookbookDeepLinkHost: View {
    let entry: LookbookEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LookbookSinglePostFeedPresentedView(entry: entry, onDismiss: { dismiss() })
    }
}

private struct NotificationRowView: View {
    let notification: AppNotification

    /// Slightly larger than `Theme.Typography.caption` (13pt) for readability.
    private static let lineFontSize: CGFloat = 15

    private var senderUsername: String? {
        notification.sender?.username
    }

    private var isSupportNotification: Bool {
        WearhouseSupportBranding.isSupportSender(username: senderUsername)
    }

    /// Legacy payment success copy stored as "SOLD!… Your item sold for £…" — show same short line as new backend.
    private var isLegacySellerSaleRow: Bool {
        let g = (notification.modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard g.caseInsensitiveCompare("Order") == .orderedSame else { return false }
        let m = notification.message
        return m.localizedCaseInsensitiveContains("your item sold")
            || m.range(of: "SOLD!", options: .caseInsensitive) != nil
    }

    /// Bell list line: always show who it’s from. If the API omits the username in `message`, prepend `sender.username`.
    private var displayMessage: String {
        let msg = notification.message.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSupportNotification { return msg }
        if isLegacySellerSaleRow,
           let username = notification.sender?.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            return "\(username) bought your item"
        }
        guard let username = notification.sender?.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty else {
            return msg
        }
        let lowerMsg = msg.lowercased()
        let lowerUser = username.lowercased()
        if lowerMsg.hasPrefix(lowerUser + " ") || lowerMsg == lowerUser {
            return msg
        }
        return "\(username) \(msg)"
    }

    /// When the line starts with the sender username, return that segment (preserving message casing) and the rest for styled `Text` composition.
    private var usernamePrefixAndBody: (username: String, body: String)? {
        if isSupportNotification { return nil }
        guard let u = notification.sender?.username?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty else { return nil }
        let msg = displayMessage
        guard msg.lowercased().hasPrefix(u.lowercased()) else { return nil }
        let nameEnd = msg.index(msg.startIndex, offsetBy: u.count)
        guard nameEnd <= msg.endIndex else { return nil }
        let namePart = String(msg[..<nameEnd])
        if nameEnd < msg.endIndex, msg[nameEnd] == " " {
            let afterSpace = msg.index(after: nameEnd)
            return (namePart, String(msg[afterSpace...]))
        }
        if nameEnd == msg.endIndex { return (namePart, "") }
        return nil
    }

    private var notificationBodyFont: Font {
        .system(size: Self.lineFontSize, weight: .regular)
    }

    private var notificationUsernameFont: Font {
        .system(size: Self.lineFontSize, weight: .semibold)
    }

    @ViewBuilder
    private var messageText: some View {
        let primary = Theme.Colors.primaryText
        if let parts = usernamePrefixAndBody {
            let tail = parts.body.isEmpty ? "" : " " + parts.body
            (Text(parts.username).font(notificationUsernameFont).foregroundColor(primary)
                + Text(tail).font(notificationBodyFont).foregroundColor(primary))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        } else {
            Text(displayMessage)
                .font(notificationBodyFont)
                .foregroundColor(primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            if isSupportNotification {
                WearhouseSupportBranding.supportAvatar(size: 44)
            } else if let sender = notification.sender, let urlString = sender.profilePictureUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Circle()
                            .fill(Theme.primaryColor.opacity(0.3))
                            .overlay(
                                Text(String((sender.username ?? "?").prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .circularAvatarHairlineBorder()
            } else {
                Circle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person")
                            .foregroundColor(Theme.Colors.secondaryText)
                    )
                    .circularAvatarHairlineBorder()
            }
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                messageText
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let date = notification.createdAt {
                    Text(formatDate(date))
                        .font(notificationBodyFont)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        NotificationsListView()
            .environmentObject(AuthService())
            .environmentObject(BellUnreadStore())
    }
}
