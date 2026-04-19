import SwiftUI

/// List of in-app notifications (Flutter NotificationsScreen + NotificationsTab).
struct NotificationsListView: View {
    /// Matches `NotificationRowView` vertical tightening (20% less than former 4pt).
    private static let listRowInsetVertical: CGFloat = 4 * 0.8

    private enum NotificationListSegment: Int, CaseIterable, Hashable {
        case general = 0
        case lookbook = 1
    }

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var bellUnreadStore: BellUnreadStore
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [AppNotification] = []
    @State private var segment: NotificationListSegment = .general
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    /// Next GraphQL page to request (1-based). Chat rows are filtered out unless stale unread.
    @State private var nextBackendPage = 1
    @State private var backendHasMore = true
    private let pageSize = 15
    private let notificationService = NotificationService()

    private var filteredNotifications: [AppNotification] {
        switch segment {
        case .general:
            return notifications.filter { !$0.isLookbookRelatedNotification }
        case .lookbook:
            return notifications.filter { $0.isLookbookRelatedNotification }
        }
    }

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
                VStack(spacing: 0) {
                    Picker("", selection: $segment) {
                        Text(L10n.string("General")).tag(NotificationListSegment.general)
                        Text(L10n.string("Lookbook")).tag(NotificationListSegment.lookbook)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)

                    if filteredNotifications.isEmpty {
                        segmentEmptyView
                    } else {
                        notificationRowsList
                    }
                }
                .task(id: segment) {
                    await ensureContentForCurrentSegment()
                }
                .wearhouseChatThreadReadableWidthIfPadMac()
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
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            nextBackendPage = 1
            backendHasMore = true
        }
        do {
            try await fetchVisibleBatch(appending: false)
        } catch {
            await MainActor.run {
                errorMessage = L10n.userFacingError(error)
                isLoading = false
            }
            return
        }
        await MainActor.run { isLoading = false }
        notificationService.updateAuthToken(authService.authToken)
        await ensureContentForCurrentSegment()
        // Mark bell-eligible rows read without blocking first paint (was serializing an extra multi-page fetch before the list appeared).
        Task { @MainActor in
            do {
                try await notificationService.markAllBellEligibleUnreadRead()
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
                bellUnreadStore.scheduleRefresh(authService: authService)
            } catch {
                #if DEBUG
                print("Wearhouse: markAllBellEligibleUnreadRead failed: \(error)")
                #endif
            }
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

    /// When the active segment’s filter yields no rows but older pages may contain matches, fetch until we find some or exhaust the feed.
    private func ensureContentForCurrentSegment() async {
        for _ in 0..<25 {
            let stillEmpty = await MainActor.run {
                switch segment {
                case .general:
                    return notifications.filter { !$0.isLookbookRelatedNotification }.isEmpty
                case .lookbook:
                    return notifications.filter { $0.isLookbookRelatedNotification }.isEmpty
                }
            }
            if !stillEmpty { return }

            let shouldLoad = await MainActor.run {
                if let err = errorMessage, !err.isEmpty { return false }
                return backendHasMore && !isLoading
            }
            guard shouldLoad else { return }

            // Avoid stacking concurrent `loadMore` work if the infinite-scroll row is also loading.
            var spin = 0
            while spin < 40 {
                let loadingMore = await MainActor.run { isLoadingMore }
                if !loadingMore { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
                spin += 1
            }

            await loadMoreVisible()

            let failed = await MainActor.run {
                if let err = errorMessage, !err.isEmpty { return true }
                return false
            }
            if failed { return }
        }
    }

    @ViewBuilder
    private var segmentEmptyView: some View {
        VStack(spacing: Theme.Spacing.md) {
            if isLoadingMore {
                ProgressView()
            }
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.secondaryText)
            Text(
                segment == .lookbook
                    ? L10n.string("No lookbook notifications yet")
                    : L10n.string("No general notifications yet")
            )
            .font(Theme.Typography.body)
            .foregroundColor(Theme.Colors.secondaryText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notificationRowsList: some View {
        List {
            ForEach(filteredNotifications) { notification in
                NavigationLink(destination: NotificationDestinationView(notification: notification, onMarkRead: { markAsRead(notification) })) {
                    NotificationRowView(notification: notification)
                        .environmentObject(authService)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainTappableButtonStyle())
                .listRowBackground(Theme.Colors.background)
                .listRowInsets(
                    EdgeInsets(
                        top: Self.listRowInsetVertical,
                        leading: Theme.Spacing.md,
                        bottom: Self.listRowInsetVertical,
                        trailing: Theme.Spacing.md
                    )
                )
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

    /// Backend sets `meta.is_liked_item_sold` when a favourited listing sells (similar picks screen).
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

/// Caches `Item.isMysteryBox` by product id so bell rows can show `MysteryBoxAnimatedMediaView` instead of the static listing JPEG (same raster as `MysteryBoxListingCoverImage`).
@MainActor
private final class NotificationMysteryListingResolver {
    static let shared = NotificationMysteryListingResolver()
    private var cache: [Int: Bool] = [:]

    func isMysteryListing(productId: Int, authToken: String?) async -> Bool {
        if let hit = cache[productId] { return hit }
        let client = GraphQLClient()
        client.setAuthToken(authToken)
        let service = ProductService(client: client)
        service.updateAuthToken(authToken)
        guard let item = try? await service.getProduct(id: productId) else {
            cache[productId] = false
            return false
        }
        let v = item.isMysteryBox
        cache[productId] = v
        return v
    }
}

/// Fetches the listing’s chrome thumbnail for bell rows when transactional notifications omit image URLs in meta.
@MainActor
private final class NotificationListingThumbnailResolver {
    static let shared = NotificationListingThumbnailResolver()
    private var cache: [Int: URL] = [:]

    func listingThumbnailURL(productId: Int, authToken: String?) async -> URL? {
        if let hit = cache[productId] { return hit }
        let client = GraphQLClient()
        client.setAuthToken(authToken)
        let service = ProductService(client: client)
        service.updateAuthToken(authToken)
        guard let item = try? await service.getProduct(id: productId) else { return nil }
        guard let raw = item.thumbnailURLForChrome?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        guard let url = Self.httpURL(from: raw) else { return nil }
        cache[productId] = url
        return url
    }

    private static func httpURL(from raw: String) -> URL? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let u = URL(string: t), u.scheme != nil { return u }
        let encodedSpaces = t.replacingOccurrences(of: " ", with: "%20")
        if encodedSpaces != t, let u = URL(string: encodedSpaces), u.scheme != nil { return u }
        return nil
    }
}

/// Loads product/listing art from meta when present; otherwise sender avatar. Retries transient failures and falls back to avatar if the product URL errors.
private struct NotificationBellThumbnail<FailureIcon: View>: View {
    let productURL: URL?
    let avatarURL: URL?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    /// Profile-style circle (comments / follows / likes); listing rows stay rounded-rect.
    var circular: Bool = false
    @ViewBuilder let failureIcon: () -> FailureIcon

    @State private var tier: Int = 0

    private var effectiveCornerRadius: CGFloat {
        circular ? min(width, height) / 2 : cornerRadius
    }

    private var currentURL: URL? {
        if tier == 0 { return productURL ?? avatarURL }
        return avatarURL
    }

    var body: some View {
        Group {
            if let url = currentURL {
                RetryAsyncImage(
                    url: url,
                    width: width,
                    height: height,
                    cornerRadius: effectiveCornerRadius,
                    placeholder: {
                        Group {
                            if circular {
                                Circle()
                                    .fill(Theme.Colors.secondaryBackground)
                                    .overlay(ProgressView().scaleEffect(0.7))
                            } else {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .fill(Theme.Colors.secondaryBackground)
                                    .overlay(ProgressView().scaleEffect(0.7))
                            }
                        }
                    },
                    failurePlaceholder: {
                        failureIcon()
                            .frame(width: width, height: height)
                            .onAppear {
                                if tier == 0, let p = productURL, let a = avatarURL, p != a {
                                    tier = 1
                                }
                            }
                    }
                )
                .id("\(tier)-\(url.absoluteString)")
            } else {
                failureIcon()
                    .frame(width: width, height: height)
                    .modifier(NotificationThumbClipShape(circular: circular, cornerRadius: cornerRadius))
            }
        }
    }
}

/// Shared clip for placeholder rows (avoids `AnyShape` / type erasure at call sites).
private struct NotificationThumbClipShape: ViewModifier {
    let circular: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if circular {
            content.clipShape(Circle())
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

private struct NotificationRowView: View {
    let notification: AppNotification
    @EnvironmentObject private var authService: AuthService
    /// Filled when `modelGroup == offer` and the listing is a mystery box (API omits meta flags but product image is the generated cover JPEG).
    @State private var resolvedProductIsMysteryBox: Bool?
    @State private var resolvedTransactionalListingURL: URL?

    /// Slightly larger than `Theme.Typography.caption` (13pt) for readability.
    private static let lineFontSize: CGFloat = 15
    /// Portrait thumbnail (20% smaller than former 48×64).
    private static let productThumbWidth: CGFloat = 48 * 0.8
    private static let productThumbHeight: CGFloat = 64 * 0.8
    /// Social rows use a circular avatar with the same vertical weight as the product portrait thumb.
    private static let socialAvatarDiameter: CGFloat = productThumbHeight
    private static let thumbCornerRadius: CGFloat = 8 * 0.8
    private static let placeholderSymbolPointSize: CGFloat = 22 * 0.8
    /// 20% tighter than former `Theme.Spacing.sm` row padding.
    private static let rowVerticalPadding: CGFloat = Theme.Spacing.sm * 0.8

    private var senderUsername: String? {
        notification.sender?.username
    }

    private var modelGroupLower: String {
        (notification.modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isLikedItemSoldNotification: Bool {
        notification.meta?["is_liked_item_sold"] == "true"
    }

    private var isSupportNotification: Bool {
        WearhouseSupportBranding.isSupportSender(username: senderUsername)
    }

    /// Seller-side order / payment success (in-app row text is normalized to match chat).
    private var isSellerOrderSaleNotification: Bool {
        guard modelGroupLower == "order" else { return false }
        let m = notification.message.lowercased()
        return m.localizedCaseInsensitiveContains("your item sold")
            || m.range(of: "SOLD!", options: .caseInsensitive) != nil
            || m.contains("bought your item")
            || m.contains("you made a sale")
            || (m.contains("congratulations") && m.contains("sale"))
    }

    /// New offer on your listing(s) — shorten list copy.
    private var isNewOfferOnListingMessage: Bool {
        notification.message.lowercased().contains("made an offer on your product")
    }

    /// Someone liked your product — tighten wording.
    private var isProductLikeMessage: Bool {
        modelGroupLower == "product" && notification.message.lowercased().contains("liked your product")
    }

    /// Mystery box listing (offer, sale, etc.) — use the same animated tile as chat/product feeds when meta or copy indicates mystery.
    private var isMysteryBoxRelatedNotification: Bool {
        let truthy: Set<String> = ["true", "1", "yes"]
        let falsy: Set<String> = ["false", "0", "no"]
        if let raw = notification.metaValue(caseInsensitiveKey: "is_mystery_box")?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            if truthy.contains(raw) { return true }
            if falsy.contains(raw) { return false }
        }
        if let meta = notification.meta {
            let flagKeys: Set<String> = [
                "is_mystery", "mystery_box", "is_mystery_listing",
                "product_is_mystery", "mystery", "listing_is_mystery", "ismysterybox", "ismystery"
            ]
            for (k, v) in meta {
                let kl = k.lowercased()
                guard flagKeys.contains(kl) else { continue }
                let vv = v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if truthy.contains(vv) { return true }
            }
            func metaAt(_ name: String) -> String? {
                for (k, v) in meta where k.caseInsensitiveCompare(name) == .orderedSame { return v }
                return nil
            }
            if metaAt("listing_type")?.lowercased() == "mystery" { return true }
            if metaAt("product_type")?.lowercased() == "mystery" { return true }
            for titleKey in ["product_title", "title", "product_name", "item_title"] {
                if let t = metaAt(titleKey)?.lowercased(), t.contains("mystery") { return true }
            }
            for (_, v) in meta {
                let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.lowercased().contains("mystery") { return true }
                if BellNotificationMysteryThumbnailMigration.isLikelyStaticMysteryCoverURL(t) { return true }
            }
        }
        let m = notification.message.lowercased()
        if m.contains("mystery box") || m.contains("mystery listing") { return true }
        if isNewOfferOnListingMessage, m.contains("mystery") { return true }
        return false
    }

    /// Animated tile when meta/copy/GraphQL says mystery, or for offer rows until we confirm otherwise (hides buggy static cover JPEG).
    private var shouldShowMysteryBoxAnimation: Bool {
        if isMysteryBoxRelatedNotification { return true }
        if resolvedProductIsMysteryBox == true { return true }
        if shouldTreatOfferAsMysteryUntilResolved { return true }
        return false
    }

    /// Resolve `Item.isMysteryBox` when meta omits flags but `media_thumbnail` may be the generated mystery JPEG.
    private var shouldResolveMysteryFromProduct: Bool {
        guard let pid = notificationResolvedProductId, pid > 0 else { return false }
        if isMysteryBoxRelatedNotification { return false }
        if resolvedProductIsMysteryBox != nil { return false }
        let mg = modelGroupLower
        let m = notification.message.lowercased()
        if mg == "offer" { return true }
        if m.contains("sent you an offer") { return true }
        if isSellerOrderSaleNotification || isNewOfferOnListingMessage { return true }
        if mg == "product", m.contains("offer") { return true }
        if mg == "order", m.contains("mystery") || m.contains("offer") { return true }
        // Buyer/seller order rows sometimes only have avatar + product id — resolve to pick animation vs real product art.
        if mg == "order", productThumbnailURLFromMeta == nil { return true }
        return false
    }

    /// Order / sale rows: fetch listing art when meta omitted `media_thumbnail` (buyer “shipped” rows included).
    private var shouldResolveTransactionalListingThumbnail: Bool {
        guard !shouldShowMysteryBoxAnimation else { return false }
        guard productThumbnailURLFromMeta == nil else { return false }
        guard notificationResolvedProductId != nil else { return false }
        if isSellerOrderSaleNotification { return true }
        let mg = modelGroupLower
        let m = notification.message.lowercased()
        if mg == "order", m.contains("shipped") || m.contains("delivered") || m.contains("picked up") { return true }
        if mg == "offer" { return true }
        return false
    }

    /// **Only** comments, follows, and like notifications use a circular **profile** avatar. Everything else
    /// (offers, orders, lookbook thumbnails, DMs, etc.) uses the normal portrait / product tile.
    private var isSocialSenderAvatarThumbnail: Bool {
        if isSupportNotification { return false }
        if isLikedItemSoldNotification { return false }
        let mg = modelGroupLower
        let m = notification.message.lowercased()
        // Follows
        if m.contains("followed you") { return true }
        if m.contains("started following") || m.contains("is now following you") { return true }
        // Comments (avoid bare `comment` substring — too broad)
        if mg == "comment" || mg == "comments" { return true }
        if m.contains("commented") { return true }
        if m.contains("comment on your") || m.contains("new comment on your") { return true }
        // Likes — product
        if isProductLikeMessage { return true }
        // Likes — lookbook / feed (do not use `modelGroup == lookbook` alone; that catches non-like rows)
        if m.contains("liked your lookbook") || m.contains("likes your lookbook") { return true }
        if m.contains("lookbook post"), (m.contains("liked") || m.contains("likes")) { return true }
        return false
    }

    /// Orders, offers, sales — listing / product image (never fall back to sender avatar for these).
    private var isTransactionalProductThumbnail: Bool {
        if isSupportNotification { return false }
        let mg = modelGroupLower
        let m = notification.message.lowercased()
        if mg == "order" { return true }
        if mg == "offer" { return true }
        if isSellerOrderSaleNotification { return true }
        if isNewOfferOnListingMessage { return true }
        if m.contains("sent you an offer") { return true }
        if mg == "product", m.contains("offer") || m.contains("sold") || m.contains("sale") { return true }
        if m.contains("accepted your offer") { return true }
        if m.contains("shipped") && m.contains("order") { return true }
        return false
    }

    /// Image URL from notification meta (flat string, JSON blob, or nested object — see `ProductListImageURL` + `NotificationService` meta parsing).
    private static let metaImageURLCandidateKeys: [String] = [
        "media_thumbnail", "product_image", "product_image_url",
        "thumbnail_url", "thumbnailUrl", "image_url", "imageUrl",
        "product_thumbnail", "media_url", "lookbook_image", "lookbook_thumbnail",
        "thumbnail", "image", "photo_url", "photoUrl", "listing_image", "item_image",
        "listing_image_url", "productImage", "listingImage"
    ]

    /// Numeric product id from meta (order / sale pushes often omit image URLs but include a listing id).
    private var notificationResolvedProductIdFromMeta: Int? {
        guard let meta = notification.meta else { return nil }
        let keys = [
            "sold_product_id", "product_id", "productId", "listing_id", "listingId",
            "item_id", "itemId", "related_product_id", "relatedProductId",
            "order_product_id", "orderProductId", "line_item_product_id", "lineItemProductId",
            "primary_product_id", "primaryProductId", "soldProductId", "listingProductId",
        ]
        let lowerIndex: [String: String] = Dictionary(uniqueKeysWithValues: meta.map { ($0.key.lowercased(), $0.value) })
        for k in keys {
            let raw = (meta[k] ?? lowerIndex[k.lowercased()])?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let raw, !raw.isEmpty else { continue }
            if let v = Int(raw), v > 0 { return v }
        }
        return nil
    }

    private var notificationResolvedProductId: Int? {
        if let fromMeta = notificationResolvedProductIdFromMeta { return fromMeta }
        guard let midRaw = notification.modelId?.trimmingCharacters(in: .whitespacesAndNewlines), !midRaw.isEmpty,
              let v = Int(midRaw), v > 0 else { return nil }
        let modelLower = (notification.model ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if modelLower == "product" || modelLower == "offer" { return v }
        // Some payloads omit `model` but set model_group to Offer/Product.
        if modelLower.isEmpty, (modelGroupLower == "offer" || modelGroupLower == "product") { return v }
        return nil
    }

    /// Incoming / counterparty offer rows: show `MysteryBoxAnimatedMediaView` until GraphQL proves the listing isn’t a mystery box (avoids the generated cover JPEG).
    private var shouldTreatOfferAsMysteryUntilResolved: Bool {
        guard resolvedProductIsMysteryBox != false else { return false }
        guard notificationResolvedProductId != nil else { return false }
        let m = notification.message.lowercased()
        if modelGroupLower == "offer" { return true }
        if m.contains("sent you an offer") { return true }
        if isNewOfferOnListingMessage { return true }
        return false
    }

    private var productThumbnailURLFromMeta: URL? {
        guard let meta = notification.meta else { return nil }
        for key in Self.metaImageURLCandidateKeys {
            guard let raw = meta[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            // Never use generated mystery JPEG in the bell row; animation or GraphQL resolve handles mystery listings.
            if BellNotificationMysteryThumbnailMigration.isLikelyStaticMysteryCoverURL(raw) { continue }
            if let s = ProductListImageURL.preferredString(from: raw), let u = Self.urlFromHTTPString(s) { return u }
            if let u = Self.urlFromHTTPString(raw) { return u }
        }
        return nil
    }

    private var senderAvatarURL: URL? {
        guard let raw = notification.sender?.profilePictureUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return Self.urlFromHTTPString(raw)
    }

    private static func urlFromHTTPString(_ raw: String) -> URL? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let u = URL(string: t), u.scheme != nil { return u }
        let encodedSpaces = t.replacingOccurrences(of: " ", with: "%20")
        if encodedSpaces != t, let u = URL(string: encodedSpaces), u.scheme != nil { return u }
        return nil
    }

    /// Bell list line: always show who it’s from. If the API omits the username in `message`, prepend `sender.username`.
    private var displayMessage: String {
        let msg = notification.message.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSupportNotification { return msg }
        if isLikedItemSoldNotification {
            return L10n.string("An item you liked has sold. Here are similar listings to explore.")
        }
        if isSellerOrderSaleNotification {
            return L10n.string(WearhouseSaleNotificationCopy.sellerSaleMessage)
        }
        if isNewOfferOnListingMessage,
           let username = notification.sender?.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            let name = username.hasPrefix("@") ? String(username.dropFirst()) : username
            return String(format: L10n.string("%@ sent you an offer."), name)
        }
        if isProductLikeMessage,
           let username = notification.sender?.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            let name = username.hasPrefix("@") ? String(username.dropFirst()) : username
            return String(format: L10n.string("%@ likes your item."), name)
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

    @ViewBuilder
    private var leadingThumbnail: some View {
        let corner = Self.thumbCornerRadius
        if isSupportNotification {
            WearhouseSupportBranding.supportAvatar(size: Self.socialAvatarDiameter)
        } else if shouldShowMysteryBoxAnimation {
            MysteryBoxAnimatedMediaView()
                .frame(width: Self.productThumbWidth, height: Self.productThumbHeight)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
        } else if shouldResolveMysteryFromProduct {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
                .frame(width: Self.productThumbWidth, height: Self.productThumbHeight)
                .overlay(ProgressView().scaleEffect(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
        } else if isSocialSenderAvatarThumbnail {
            NotificationBellThumbnail(
                productURL: nil,
                avatarURL: senderAvatarURL,
                width: Self.socialAvatarDiameter,
                height: Self.socialAvatarDiameter,
                cornerRadius: Self.socialAvatarDiameter / 2,
                circular: true,
                failureIcon: { socialAvatarPlaceholderIcon }
            )
            .circularAvatarHairlineBorder()
        } else if isTransactionalProductThumbnail {
            NotificationBellThumbnail(
                productURL: productThumbnailURLFromMeta ?? resolvedTransactionalListingURL,
                avatarURL: nil,
                width: Self.productThumbWidth,
                height: Self.productThumbHeight,
                cornerRadius: corner,
                failureIcon: { productPlaceholderIcon }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
        } else if productThumbnailURLFromMeta != nil || resolvedTransactionalListingURL != nil || senderAvatarURL != nil {
            NotificationBellThumbnail(
                productURL: productThumbnailURLFromMeta ?? resolvedTransactionalListingURL,
                avatarURL: senderAvatarURL,
                width: Self.productThumbWidth,
                height: Self.productThumbHeight,
                cornerRadius: corner,
                failureIcon: { productPlaceholderIcon }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
        } else {
            productPlaceholderIcon
                .frame(width: Self.productThumbWidth, height: Self.productThumbHeight)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
        }
    }

    private var productPlaceholderIcon: some View {
        RoundedRectangle(cornerRadius: Self.thumbCornerRadius, style: .continuous)
            .fill(Theme.Colors.secondaryBackground)
            .overlay(
                Image(systemName: "tshirt")
                    .font(.system(size: Self.placeholderSymbolPointSize, weight: .regular))
                    .foregroundStyle(Theme.Colors.secondaryText)
            )
    }

    private var socialAvatarPlaceholderIcon: some View {
        Circle()
            .fill(Theme.Colors.secondaryBackground)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: Self.placeholderSymbolPointSize, weight: .regular))
                    .foregroundStyle(Theme.Colors.secondaryText)
            )
    }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md * 0.8) {
            leadingThumbnail
            HStack(alignment: .center, spacing: Theme.Spacing.sm * 0.8) {
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
        .padding(.vertical, Self.rowVerticalPadding)
        .task(id: notification.id) {
            await resolveBellRowThumbnails()
        }
    }

    /// Fetches mystery flag first, then listing chrome thumbnail in the same task so sale/offer rows can show product art after we know it isn’t a mystery listing.
    private func resolveBellRowThumbnails() async {
        guard let pid = notificationResolvedProductId, pid > 0 else { return }

        if isMysteryBoxRelatedNotification {
            await MainActor.run { resolvedProductIsMysteryBox = true }
            return
        }

        let needsMysteryFetch = await MainActor.run { resolvedProductIsMysteryBox == nil && shouldResolveMysteryFromProduct }
        if needsMysteryFetch {
            let isMystery = await NotificationMysteryListingResolver.shared.isMysteryListing(productId: pid, authToken: authService.authToken)
            await MainActor.run { resolvedProductIsMysteryBox = isMystery }
            if isMystery { return }
        }

        let mysteryTrue = await MainActor.run { resolvedProductIsMysteryBox == true }
        if mysteryTrue { return }

        guard productThumbnailURLFromMeta == nil else { return }
        let noListingURLYet = await MainActor.run { resolvedTransactionalListingURL == nil }
        guard noListingURLYet else { return }

        let mg = modelGroupLower
        let m = notification.message.lowercased()
        let needsListingArt =
            isSellerOrderSaleNotification
            || mg == "offer"
            || (mg == "order" && (m.contains("shipped") || m.contains("delivered") || m.contains("picked up")))
        guard needsListingArt else { return }

        let url = await NotificationListingThumbnailResolver.shared.listingThumbnailURL(productId: pid, authToken: authService.authToken)
        await MainActor.run { resolvedTransactionalListingURL = url }
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
