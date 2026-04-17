import SwiftUI

/// List of in-app notifications (Flutter NotificationsScreen + NotificationsTab).
struct NotificationsListView: View {
    /// Matches `NotificationRowView` vertical tightening (20% less than former 4pt).
    private static let listRowInsetVertical: CGFloat = 4 * 0.8

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
    @ViewBuilder let failureIcon: () -> FailureIcon

    @State private var tier: Int = 0

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
                    cornerRadius: cornerRadius,
                    placeholder: {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Theme.Colors.secondaryBackground)
                            .overlay(ProgressView().scaleEffect(0.7))
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
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
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
            for (_, v) in meta where v.lowercased().contains("mystery") {
                return true
            }
        }
        let m = notification.message.lowercased()
        if m.contains("mystery box") || m.contains("mystery listing") { return true }
        if isNewOfferOnListingMessage, m.contains("mystery") { return true }
        return false
    }

    /// Prefer animated mystery art when meta/copy says so, after GraphQL resolve, or while resolving (static `media_thumbnail` is the generated mystery JPEG — wrong for bell rows).
    private var shouldShowMysteryBoxAnimation: Bool {
        if isMysteryBoxRelatedNotification { return true }
        if resolvedProductIsMysteryBox == true { return true }
        // Resolve offer/sale listing type before showing `media_thumbnail` (avoids static mystery JPEG flash).
        if shouldResolveMysteryFromProduct { return true }
        if resolvedProductIsMysteryBox == false { return false }
        return false
    }

    /// Offer on a listing: `media_thumbnail` is the static JPEG from `MysteryBoxListingCoverImage` — resolve `isMysteryBox` from the product when meta omits flags.
    private var shouldResolveMysteryFromProduct: Bool {
        guard let pid = notificationResolvedProductId, pid > 0 else { return false }
        let mg = modelGroupLower
        let offerishGroup = mg == "offer" || (mg == "product" && notification.message.lowercased().contains("offer"))
        let sellerSale = isSellerOrderSaleNotification
        guard offerishGroup || sellerSale else { return false }
        if isMysteryBoxRelatedNotification { return false }
        if resolvedProductIsMysteryBox != nil { return false }
        return true
    }

    /// Seller sale rows: fetch listing art when the API did not attach `media_thumbnail`.
    private var shouldResolveTransactionalListingThumbnail: Bool {
        guard isSellerOrderSaleNotification else { return false }
        guard !shouldShowMysteryBoxAnimation else { return false }
        guard productThumbnailURLFromMeta == nil else { return false }
        return notificationResolvedProductId != nil
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
        let modelLower = (notification.model ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if modelLower == "product", let mid = notification.modelId, let v = Int(mid), v > 0 { return v }
        return nil
    }

    private var productThumbnailURLFromMeta: URL? {
        guard let meta = notification.meta else { return nil }
        for key in Self.metaImageURLCandidateKeys {
            guard let raw = meta[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
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
            WearhouseSupportBranding.supportAvatar(size: Self.productThumbHeight)
        } else if shouldShowMysteryBoxAnimation {
            MysteryBoxAnimatedMediaView()
                .frame(width: Self.productThumbWidth, height: Self.productThumbHeight)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
        } else if productThumbnailURLFromMeta != nil || resolvedTransactionalListingURL != nil || (!isSellerOrderSaleNotification && senderAvatarURL != nil) {
            NotificationBellThumbnail(
                productURL: productThumbnailURLFromMeta ?? resolvedTransactionalListingURL,
                avatarURL: isSellerOrderSaleNotification ? nil : senderAvatarURL,
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
            if shouldResolveMysteryFromProduct, let pid = notificationResolvedProductId {
                let isMystery = await NotificationMysteryListingResolver.shared.isMysteryListing(productId: pid, authToken: authService.authToken)
                await MainActor.run {
                    resolvedProductIsMysteryBox = isMystery
                }
            }
            if shouldResolveTransactionalListingThumbnail, let pid = notificationResolvedProductId {
                let url = await NotificationListingThumbnailResolver.shared.listingThumbnailURL(productId: pid, authToken: authService.authToken)
                await MainActor.run {
                    resolvedTransactionalListingURL = url
                }
            }
        }
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
