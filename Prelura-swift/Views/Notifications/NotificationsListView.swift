import SwiftUI
import Shimmer
import UIKit

/// List of in-app notifications (Flutter NotificationsScreen + NotificationsTab).
///
/// **Row art:** `relatedProductIsMysteryBox` (GraphQL, when present), meta flags, and legacy “static mystery cover” URL heuristics select **animated** mystery art; otherwise JPEG comes from the server field, meta image keys, or a one-shot `product(id:)` when still missing. Chat rows use the same 30-minute unread / hide-read policy as `origin/main` (`AppNotification.shouldShowOnNotificationsPage`).
///
/// **Realtime:** There is no dedicated in-app notifications WebSocket in this client; the list refreshes from GraphQL on open, pull-to-refresh (full shimmer reload), app foreground (`scenePhase`), and after push-driven `wearhouseInAppNotificationsDidChange` flows elsewhere. Last successful page is cached per username for instant paint offline.
///
/// **Read / accent rules:** Row fill = unread (`!isRead`). Tapping a row calls ``NotificationService/readNotifications`` when the id maps to an ``AppNotification/bellNotificationDatabaseIntId``; opened ids are also stored in ``BellLocallyReadNotificationIds`` so reopening the list stays “read” if the API still returns stale flags. Untapped bell-eligible unreads stay accented until a **second** visit (``NotificationService/markAllBellEligibleUnreadRead()``). Primed state is per-account in `UserDefaults`.
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
    /// True while ``ensureContentForCurrentSegmentBody()`` is paging for the active segment so we don’t flash “No … notifications yet” between load-more passes.
    @State private var isBackfillingSegment = false
    /// Cancels stale backfill UI when the user switches segments quickly (avoids clearing `isBackfillingSegment` mid-flight for the wrong tab).
    @State private var segmentBackfillSession = UUID()
    @State private var errorMessage: String?
    /// True while a full list reload is in flight. Prevents the infinite-scroll / backfill `loadMore` from racing the initial fetch and **appending a duplicate of page 1** when a cached list kept `isLoading` false.
    @State private var isReloadingNotifications = false
    /// Next GraphQL page to request (1-based). Rows are then filtered with `shouldShowOnNotificationsPage` (chat age/read rules, etc.).
    @State private var nextBackendPage = 1
    @State private var backendHasMore = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var imageReloadTokenForRows: Int = 0
    /// Full-screen shimmer during pull without unmounting the `List` / `ScrollView` that owns `.refreshable` (removing it cancels the refresh task → empty “No notifications” flash).
    @State private var isPullRefreshOverlay = false
    @State private var lastBecomeActiveReload: Date?
    /// Set from the two-visit gate in `onAppear` only; consumed on the next **successful** ``reloadFromStart()`` (not pull/foreground). Pull-to-refresh uses ``reloadFromStart(pullToRefresh:)`` and does not advance this gate.
    @State private var shouldMarkBellEligibleUnreadAfterNextSuccessfulReload = false
    /// One GraphQL page size (matches backend `pageCount`).
    private let pageSize = 15
    /// Initial load: keep paging the API until we have `pageSize` **visible** rows (after chat-age filtering) or the feed ends. A low cap left users with 1–2 non-chat rows when recent pages were mostly DMs.
    private let maxInitialBackendPages = 64
    /// “Load more” / segment backfill: walk several API pages in one call so a **full page of DMs** (all filtered) still advances
    /// until we have `pageSize` visible rows or a non-full page. `1` left users stuck with 0 new rows per scroll.
    private let maxLoadMoreBackendPages = 16
    private let notificationService = NotificationService()

    private var filteredNotifications: [AppNotification] {
        switch segment {
        case .general:
            return Self.dedupeGeneralTabChatRows(notifications.filter { !$0.isLookbookRelatedNotification })
        case .lookbook:
            return notifications.filter { $0.isLookbookRelatedNotification }
        }
    }

    /// One row per chat thread in General (newest first) so the list isn’t a wall of duplicate “new message” lines.
    private static func uniqueByNotificationId(_ items: [AppNotification]) -> [AppNotification] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }

    private static func dedupeGeneralTabChatRows(_ list: [AppNotification]) -> [AppNotification] {
        let sorted = list.sorted {
            let a = $0.createdAt ?? .distantPast
            let b = $1.createdAt ?? .distantPast
            return a > b
        }
        var seenConversation = Set<String>()
        return sorted.compactMap { n in
            if n.isChatCentricNotification, let cid = n.bellConversationIdFromMeta, !cid.isEmpty {
                if seenConversation.contains(cid) { return nil }
                seenConversation.insert(cid)
            }
            return n
        }
    }

    /// Non-nil only when there is user-visible error copy (treats `""` as nil so cancellation / cleared errors don’t break loading branches).
    private var nonEmptyErrorMessage: String? {
        guard let e = errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty else { return nil }
        return e
    }

    var body: some View {
        Group {
            if isLoading && nonEmptyErrorMessage == nil {
                notificationsListShimmerLayout(includeSegmentPicker: true)
                    .refreshable { await reloadFromStart(pullToRefresh: true) }
            } else if let err = nonEmptyErrorMessage, notifications.isEmpty {
                ScrollView {
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
                            Task { await reloadFromStart(pullToRefresh: true) }
                        }
                        .foregroundColor(Theme.primaryColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xl)
                }
                .refreshable { await reloadFromStart(pullToRefresh: true) }
            } else if notifications.isEmpty {
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.Colors.secondaryText)
                        Text(L10n.string("No notifications"))
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xl)
                }
                .refreshable { await reloadFromStart(pullToRefresh: true) }
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
                .onChange(of: segment) { _, _ in
                    if filteredNotifications.isEmpty {
                        isBackfillingSegment = true
                    } else {
                        isBackfillingSegment = false
                    }
                }
                .task(id: segment) {
                    let session = UUID()
                    await MainActor.run {
                        segmentBackfillSession = session
                        isBackfillingSegment = true
                    }
                    await ensureContentForCurrentSegmentBody()
                    await MainActor.run {
                        guard segmentBackfillSession == session else { return }
                        isBackfillingSegment = false
                    }
                }
                .wearhouseChatThreadReadableWidthIfPadMac()
            }
        }
        .overlay {
            if isPullRefreshOverlay {
                notificationsListShimmerLayout(includeSegmentPicker: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
                    .refreshable { await reloadFromStart(pullToRefresh: true) }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Notifications"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notificationService.updateAuthToken(authService.authToken)
            bellUnreadStore.scheduleRefresh(authService: authService)
            applyNotificationsSecondVisitBulkReadGate()
            restoreNotificationsFromCacheIfAvailable()
            Task { await reloadFromStart() }
        }
        .onChange(of: authService.authToken) { _, newToken in
            notificationService.updateAuthToken(newToken)
            NotificationBellConversationPrefetcher.shared.clear()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let now = Date()
            if let last = lastBecomeActiveReload, now.timeIntervalSince(last) < 25 { return }
            lastBecomeActiveReload = now
            Task { await reloadFromStart() }
        }
        .onDisappear {
            NotificationCenter.default.post(name: .wearhouseInAppNotificationsDidChange, object: nil)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    /// Per-account: `false` until first list open primes; second open runs bulk `readNotifications` then clears.
    private static func notificationsSecondVisitPrimedKey(accountKey: String) -> String {
        "wearhouse.notifications.secondVisitPrimed.\(accountKey)"
    }

    /// First visit: prime for next time, no bulk. Second visit: bulk after successful reload; primed cleared only after mutation succeeds.
    private func applyNotificationsSecondVisitBulkReadGate() {
        guard let accountKey = InAppNotificationsCache.accountKey(username: authService.username) else {
            shouldMarkBellEligibleUnreadAfterNextSuccessfulReload = false
            return
        }
        let key = Self.notificationsSecondVisitPrimedKey(accountKey: accountKey)
        let primed = UserDefaults.standard.bool(forKey: key)
        if primed {
            shouldMarkBellEligibleUnreadAfterNextSuccessfulReload = true
        } else {
            shouldMarkBellEligibleUnreadAfterNextSuccessfulReload = false
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    private func restoreNotificationsFromCacheIfAvailable() {
        guard let key = InAppNotificationsCache.accountKey(username: authService.username),
              let cached = InAppNotificationsCache.load(accountKey: key),
              !cached.isEmpty else { return }
        let merged = BellLocallyReadNotificationIds.mergedWithLocalReadState(
            accountKey: key,
            notifications: Self.uniqueByNotificationId(cached)
        )
        notifications = merged
        isLoading = false
    }

    private func reloadFromStart(pullToRefresh: Bool = false) async {
        await MainActor.run {
            isReloadingNotifications = true
            if pullToRefresh {
                imageReloadTokenForRows += 1
                NotificationRowView.resetCachesForToolbarReload()
                // Only the cold first-load shimmer is safe to replace entirely: its `ScrollView` owns refresh, not a `List`.
                let onColdLaunchShimmer = isLoading && notifications.isEmpty && nonEmptyErrorMessage == nil
                if onColdLaunchShimmer {
                    isLoading = true
                    notifications = []
                } else {
                    isPullRefreshOverlay = true
                }
            } else if notifications.isEmpty {
                isLoading = true
            }
            errorMessage = nil
            nextBackendPage = 1
            backendHasMore = true
        }
        do {
            let batch = try await fetchVisibleBatch(appending: false, maxBackendPages: maxInitialBackendPages)
            await NotificationBellConversationPrefetcher.shared.prefetch(
                notifications: batch,
                authToken: authService.authToken,
                currentUsername: authService.username
            )
        } catch {
            await MainActor.run {
                if L10n.isCancellationLikeError(error) {
                    errorMessage = nil
                } else {
                    errorMessage = L10n.userFacingError(error)
                }
                isPullRefreshOverlay = false
                isLoading = false
                isReloadingNotifications = false
                isBackfillingSegment = false
            }
            return
        }
        // Keep `isLoading == true` through segment backfill on cold launch; pull overlay stays until here on normal feeds.
        notificationService.updateAuthToken(authService.authToken)
        await MainActor.run { isBackfillingSegment = true }
        await ensureContentForCurrentSegmentBody()
        await MainActor.run {
            isBackfillingSegment = false
            isReloadingNotifications = false
            isLoading = false
            isPullRefreshOverlay = false
            if let key = InAppNotificationsCache.accountKey(username: authService.username) {
                if notifications.isEmpty {
                    InAppNotificationsCache.clear(accountKey: key)
                } else {
                    InAppNotificationsCache.save(notifications, accountKey: key)
                }
            }
        }
        let runOpenMarkRead = await MainActor.run {
            if shouldMarkBellEligibleUnreadAfterNextSuccessfulReload {
                shouldMarkBellEligibleUnreadAfterNextSuccessfulReload = false
                return true
            }
            return false
        }
        if runOpenMarkRead {
            await markBellEligibleUnreadReadOnNotificationsOpened()
        }
        await MainActor.run {
            bellUnreadStore.scheduleRefresh(authService: authService)
            NotificationCenter.default.post(name: .wearhouseInAppNotificationsDidChange, object: nil)
        }
    }

    /// Pulls backend pages until we have `pageSize` visible rows, `maxBackendPages` is reached, or the feed ends.
    @discardableResult
    private func fetchVisibleBatch(appending: Bool, maxBackendPages: Int) async throws -> [AppNotification] {
        notificationService.updateAuthToken(authService.authToken)
        var collected: [AppNotification] = []
        var safety = 0
        var page = await MainActor.run { nextBackendPage }
        var hasMore = await MainActor.run { backendHasMore }
        while collected.count < pageSize && hasMore && safety < maxBackendPages {
            safety += 1
            let (batch, _) = try await notificationService.getNotifications(pageCount: pageSize, pageNumber: page)
            page += 1
            for n in batch where n.shouldShowOnNotificationsPage() {
                collected.append(n)
            }
            if batch.isEmpty {
                hasMore = false
                break
            }
            // A **full** page means more *might* exist. A **short, non-empty** first page (e.g. 2–5 rows) must still allow
            // a follow-up request-many servers return a short “newest” page first; `notificationsTotalNumber` is unreliable.
            // After the first request (`safety == 1`), a short page means the feed has ended.
            let fullPage = (batch.count == pageSize)
            let shortFirstPageMayHaveMore = (safety == 1) && (batch.count < pageSize) && (batch.count > 0)
            hasMore = fullPage || shortFirstPageMayHaveMore
            if collected.count >= pageSize { break }
        }
        await MainActor.run {
            nextBackendPage = page
            backendHasMore = hasMore
            let dedupedCollected = Self.uniqueByNotificationId(collected)
            if appending {
                let existing = Set(notifications.map(\.id))
                let onlyNew = dedupedCollected.filter { !existing.contains($0.id) }
                notifications.append(contentsOf: onlyNew)
            } else {
                notifications = dedupedCollected
            }
            if let key = InAppNotificationsCache.accountKey(username: authService.username) {
                notifications = BellLocallyReadNotificationIds.mergedWithLocalReadState(
                    accountKey: key,
                    notifications: notifications
                )
            }
        }
        return collected
    }

    private func loadMoreVisible() async {
        let mayLoad = await MainActor.run { () -> Bool in
            guard backendHasMore, !isLoadingMore else { return false }
            if isReloadingNotifications {
                // Full list reload runs `ensureContentForCurrentSegmentBody` while this flag is set; allow paging only then.
                return isBackfillingSegment
            }
            return !isLoading
        }
        guard mayLoad else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let batch = try await fetchVisibleBatch(appending: true, maxBackendPages: maxLoadMoreBackendPages)
            await NotificationBellConversationPrefetcher.shared.prefetch(
                notifications: batch,
                authToken: authService.authToken,
                currentUsername: authService.username
            )
        } catch {
            await MainActor.run { errorMessage = L10n.userFacingError(error) }
        }
    }

    /// When the active segment’s filter yields no rows but older pages may contain matches, keep paging (bounded) until a match or the feed ends.
    /// A small cap (e.g. 4) caused “No general notifications yet” right after pull-to-refresh when the newest pages were all lookbook-classified.
    private func ensureContentForCurrentSegmentBody() async {
        let maxBackfillPages = 40
        for _ in 0..<maxBackfillPages {
            if Task.isCancelled { return }
            let stillEmpty = await MainActor.run {
                switch segment {
                case .general:
                    return Self.dedupeGeneralTabChatRows(notifications.filter { !$0.isLookbookRelatedNotification }).isEmpty
                case .lookbook:
                    return notifications.filter { $0.isLookbookRelatedNotification }.isEmpty
                }
            }
            if !stillEmpty { return }

            let shouldLoad = await MainActor.run {
                if let err = errorMessage, !err.isEmpty { return false }
                let pagingDuringListReload = isReloadingNotifications && isBackfillingSegment
                // Idle list: don’t page during initial shimmer. Reload+backfill: allow paging while `isLoading` is still true.
                return backendHasMore
                    && (pagingDuringListReload || (!isReloadingNotifications && !isLoading))
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
        Group {
            if isLoadingMore || isBackfillingSegment {
                notificationsListShimmerLayout(includeSegmentPicker: false)
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
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
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xl)
                }
                .refreshable { await reloadFromStart(pullToRefresh: true) }
            }
        }
    }

    /// Skeleton rows (optional segmented control stub) while notifications load.
    @ViewBuilder
    private func notificationsListShimmerLayout(includeSegmentPicker: Bool) -> some View {
        VStack(spacing: 0) {
            if includeSegmentPicker {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(height: 32)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(0..<8, id: \.self) { _ in
                        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Theme.Colors.secondaryBackground)
                                    .frame(height: 14)
                                    .frame(maxWidth: .infinity)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Theme.Colors.secondaryBackground)
                                    .frame(height: 12)
                                    .frame(maxWidth: 220, alignment: .leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .shimmering()
    }

    private var notificationRowsList: some View {
        List {
            ForEach(filteredNotifications) { notification in
                NavigationLink(destination: NotificationDestinationView(notification: notification, onMarkRead: { markAsRead(notification) })) {
                    NotificationRowView(notification: notification, imageReloadEpoch: imageReloadTokenForRows)
                        .id(notification.id)
                        .environmentObject(authService)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .id("\(notification.id)-\(notification.isRead)")
                .buttonStyle(PlainTappableButtonStyle())
                .listRowBackground(notificationListRowChrome(isUnread: !notification.isRead))
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
            if backendHasMore {
                HStack {
                    Spacer()
                    if isLoadingMore { ProgressView() }
                    Spacer()
                }
                .listRowInsets(
                    EdgeInsets(
                        top: Self.listRowInsetVertical,
                        leading: Theme.Spacing.md,
                        bottom: Self.listRowInsetVertical,
                        trailing: Theme.Spacing.md
                    )
                )
                .onAppear { Task { await loadMoreVisible() } }
                .listRowBackground(Theme.Colors.background)
                .listRowSeparator(.hidden, edges: .bottom)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await reloadFromStart(pullToRefresh: true) }
    }

    /// Unread rows: light primary tint fill across the full row (no stroke). Clears when read (tap) or after a **second** visit to this list without tap (bulk read).
    @ViewBuilder
    private func notificationListRowChrome(isUnread: Bool) -> some View {
        if isUnread {
            Rectangle()
                .fill(Theme.primaryColor.opacity(0.1))
        } else {
            Theme.Colors.background
        }
    }

    private func markAsRead(_ notification: AppNotification) {
        let nid = notification.id
        let dbId = notification.bellNotificationDatabaseIntId
        Task {
            await MainActor.run {
                if let key = InAppNotificationsCache.accountKey(username: authService.username) {
                    BellLocallyReadNotificationIds.record(accountKey: key, notificationId: nid)
                }
                if let idx = notifications.firstIndex(where: { $0.id == nid }) {
                    notifications[idx] = notifications[idx].withIsRead(true)
                }
            }
            if let dbId {
                do {
                    try await notificationService.readNotifications(notificationIds: [dbId])
                } catch {
                    #if DEBUG
                    print("Wearhouse: readNotifications failed for id \(dbId): \(error)")
                    #endif
                }
            }
            await MainActor.run {
                NotificationCenter.default.post(name: .wearhouseInAppNotificationsDidChange, object: nil)
                if let key = InAppNotificationsCache.accountKey(username: authService.username), !notifications.isEmpty {
                    InAppNotificationsCache.save(notifications, accountKey: key)
                }
            }
        }
    }

    /// Second list visit only (see ``applyNotificationsSecondVisitBulkReadGate()``): bell-eligible unreads → `readNotifications` batch; then clear primed so the next pair of visits repeats the rule.
    private func markBellEligibleUnreadReadOnNotificationsOpened() async {
        notificationService.updateAuthToken(authService.authToken)
        do {
            try await notificationService.markAllBellEligibleUnreadRead()
        } catch {
            await MainActor.run {
                shouldMarkBellEligibleUnreadAfterNextSuccessfulReload = true
            }
            return
        }
        await MainActor.run {
            if let accountKey = InAppNotificationsCache.accountKey(username: authService.username) {
                UserDefaults.standard.set(false, forKey: Self.notificationsSecondVisitPrimedKey(accountKey: accountKey))
            }
            if let key = InAppNotificationsCache.accountKey(username: authService.username) {
                let ids = notifications.filter { $0.shouldCountTowardBellBadge }.map(\.id)
                BellLocallyReadNotificationIds.recordMany(accountKey: key, notificationIds: ids)
            }
            notifications = notifications.map { n in
                n.shouldCountTowardBellBadge ? n.withIsRead(true) : n
            }
            if let key = InAppNotificationsCache.accountKey(username: authService.username), !notifications.isEmpty {
                InAppNotificationsCache.save(notifications, accountKey: key)
            }
        }
    }

    private func deleteNotification(_ notification: AppNotification) {
        guard let idInt = notification.bellNotificationDatabaseIntId else { return }
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

/// In-memory decode cache so notification list rows do not re-hit the network / flash placeholders when `List` recycles cells.
@MainActor
private enum NotificationBellUIImageMemoryCache {
    private static let cache = NSCache<NSString, UIImage>()
    private static let costLimitBytes = 48 * 1024 * 1024

    static func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    static func insert(_ image: UIImage, for url: URL) {
        cache.totalCostLimit = costLimitBytes
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: max(cost, 1))
    }

    static func remove(for url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }

    static func removeAll() {
        cache.removeAllObjects()
    }
}

/// URLSession + in-memory cache (not `AsyncImage`) so `List` recycling does not flash placeholders while URLSession’s disk cache warms.
private struct NotificationBellCachedSessionImage<Placeholder: View, FailurePlaceholder: View>: View {
    let url: URL
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var maxAutoRetries: Int = 2
    var externalReloadToken: Int = 0
    var onAutoRetriesExhausted: (() -> Void)?
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failurePlaceholder: () -> FailurePlaceholder

    @State private var loaded: UIImage?
    @State private var hardFailed = false

    private var loadIdentity: String {
        "\(url.absoluteString)-\(externalReloadToken)"
    }

    var body: some View {
        Group {
            if let loaded {
                Image(uiImage: loaded)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else if hardFailed {
                failurePlaceholder()
            } else {
                placeholder()
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(cornerRadius)
        .id(loadIdentity)
        .task(id: loadIdentity) {
            let fromMemory = await MainActor.run { () -> Bool in
                hardFailed = false
                if let mem = NotificationBellUIImageMemoryCache.image(for: url) {
                    loaded = mem
                    return true
                }
                loaded = nil
                return false
            }
            if fromMemory { return }
            var attempt = 0
            while attempt <= maxAutoRetries {
                if Task.isCancelled { return }
                if attempt > 0 {
                    let delayNs = UInt64((0.65 + 0.55 * Double(attempt - 1)) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNs)
                }
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard !Task.isCancelled else { return }
                    if let ui = UIImage(data: data) {
                        await MainActor.run {
                            NotificationBellUIImageMemoryCache.insert(ui, for: url)
                            loaded = ui
                        }
                        return
                    }
                } catch {
                    // Retry below.
                }
                attempt += 1
            }
            await MainActor.run {
                hardFailed = true
                onAutoRetriesExhausted?()
            }
        }
    }
}

/// Loads product/listing art from meta when present; otherwise sender avatar. Retries transient failures, offers a manual reload, then falls back to avatar when both URLs exist.
private struct NotificationBellThumbnail<FailureIcon: View>: View {
    let productURL: URL?
    let avatarURL: URL?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    /// Profile-style circle (comments / follows / likes); listing rows stay rounded-rect.
    var circular: Bool = false
    /// Bumped from the notifications screen toolbar so every row remounts image loaders.
    var imageReloadEpoch: Int = 0
    /// Tapping the reload badge on a failed row.
    @State private var tapReloadEpoch: Int = 0
    @ViewBuilder let failureIcon: () -> FailureIcon

    @State private var tier: Int = 0

    private var effectiveCornerRadius: CGFloat {
        circular ? min(width, height) / 2 : cornerRadius
    }

    private var currentURL: URL? {
        if tier == 0 { return productURL ?? avatarURL }
        return avatarURL
    }

    private var combinedReloadToken: Int {
        imageReloadEpoch + tapReloadEpoch
    }

    private var showsManualImageReload: Bool {
        !circular && currentURL != nil
    }

    var body: some View {
        Group {
            if let url = currentURL {
                NotificationBellCachedSessionImage(
                    url: url,
                    width: width,
                    height: height,
                    cornerRadius: effectiveCornerRadius,
                    maxAutoRetries: 2,
                    externalReloadToken: combinedReloadToken,
                    onAutoRetriesExhausted: {
                        if tier == 0, let p = productURL, let a = avatarURL, p != a {
                            tier = 1
                        }
                    },
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
                        ZStack(alignment: .bottomTrailing) {
                            failureIcon()
                                .frame(width: width, height: height)
                            if showsManualImageReload {
                                Button {
                                    if let p = productURL { NotificationBellUIImageMemoryCache.remove(for: p) }
                                    if let a = avatarURL { NotificationBellUIImageMemoryCache.remove(for: a) }
                                    tapReloadEpoch += 1
                                } label: {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(Theme.primaryColor, Theme.Colors.secondaryBackground)
                                        .font(.system(size: 22))
                                }
                                .buttonStyle(.plain)
                                .padding(2)
                                .accessibilityLabel("Reload image")
                            }
                        }
                    }
                )
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

/// Maps `conversation_id` from chat bell rows to **subtitle preview** only (chat rows are filtered out of the list, but this stays safe if a row slips in).
@MainActor
private final class NotificationBellConversationPrefetcher {
    static let shared = NotificationBellConversationPrefetcher()

    struct ChatListingHint {
        /// Inbox-style subtitle from the thread (`ChatRowView.previewText`); when set, prefer over stale API `message` for chat bell rows.
        let lastMessagePreview: String?
    }

    private var byConversationId: [String: ChatListingHint] = [:]

    func clear() {
        byConversationId.removeAll()
    }

    func listing(forConversationId id: String) -> ChatListingHint? {
        guard !id.isEmpty else { return nil }
        return byConversationId[id]
    }

    func prefetch(notifications: [AppNotification], authToken: String?, currentUsername: String?) async {
        let ids: [String] = Array(Set(notifications.compactMap { n in
            guard n.isChatCentricNotification else { return nil }
            return n.bellConversationIdFromMeta
        }))
        guard !ids.isEmpty else { return }

        let chatService = ChatService()
        chatService.updateAuthToken(authToken)
        for cid in ids {
            guard let c = try? await chatService.getConversationByIdForBellPrefetch(conversationId: cid, currentUsername: currentUsername) else { continue }
            let preview = ChatRowView.previewText(
                for: c.lastMessage,
                conversation: c,
                currentUsername: currentUsername
            )
            byConversationId[c.id] = ChatListingHint(lastMessagePreview: preview)
        }
    }
}

private struct NotificationProductThumbResolveCacheEntry: Equatable {
    var listingURL: URL?
    var mystery: Bool
    /// True once ``resolveProductThumbnailIfNeeded()`` finished for this notification + `imageReloadEpoch` (scroll remount skips network re-fetch).
    var isComplete: Bool
}

private struct NotificationRowView: View {
    let notification: AppNotification
    /// Screen-level refresh (toolbar) forces AsyncImage remount.
    var imageReloadEpoch: Int = 0
    @EnvironmentObject private var authService: AuthService
    @State private var productFetchMystery: Bool = false
    @State private var productFetchListingURL: URL?

    private let productService = ProductService()
    private let userService = UserService()
    /// `userOrders` line-item fetch keyed by order id; avoids re-querying the same order on every row refresh.
    private static var orderLinePreviewByOrderId: [Int: (productId: Int, imageUrl: String?, isMysteryBox: Bool)] = [:]
    /// Survives List row teardown so thumbnails do not flash back to placeholders on vertical scroll.
    private static var productThumbResolveCache: [String: NotificationProductThumbResolveCacheEntry] = [:]

    private static func productThumbCacheKey(notificationId: String, imageEpoch: Int) -> String {
        "\(notificationId)-\(imageEpoch)"
    }

    /// Toolbar full refresh: allow product-id resolution to run again; bust in-memory images so rows match new payloads.
    fileprivate static func resetCachesForToolbarReload() {
        productThumbResolveCache.removeAll()
        NotificationBellUIImageMemoryCache.removeAll()
    }

    private var productThumbCacheKey: String {
        Self.productThumbCacheKey(notificationId: notification.id, imageEpoch: imageReloadEpoch)
    }

    private var cachedProductThumbResolve: NotificationProductThumbResolveCacheEntry? {
        Self.productThumbResolveCache[productThumbCacheKey]
    }

    /// Slightly larger than `Theme.Typography.caption` (13pt) for readability.
    private static let lineFontSize: CGFloat = 15
    /// Trailing relative time must stay visually subordinate to the message line.
    private static let timeFontSize: CGFloat = 12
    /// Portrait thumbnail (20% smaller than former 48×64).
    private static let productThumbWidth: CGFloat = 48 * 0.8
    private static let productThumbHeight: CGFloat = 64 * 0.8
    /// Social rows: circle diameter matches listing thumb **width** (same column footprint as product tiles; General + Lookbook).
    private static let socialAvatarDiameter: CGFloat = productThumbWidth
    private static let thumbCornerRadius: CGFloat = 8 * 0.8
    private static let placeholderSymbolPointSize: CGFloat = 22 * 0.8
    /// 20% tighter than former `Theme.Spacing.sm` row padding.
    private static let rowVerticalPadding: CGFloat = Theme.Spacing.sm * 0.8

    private var senderUsername: String? {
        notification.sender?.username
    }

    private var serverProductThumbnailURL: URL? {
        guard let s = notification.productThumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return Self.urlFromHTTPString(s)
    }

    private static let metaImageURLCandidateKeys: [String] = [
        "listing_image_url", "listingImage", "listing_image", "item_image",
        "product_image", "product_image_url", "productImage", "product_thumbnail",
        "sold_product_thumbnail", "sold_product_image", "sold_product_image_url",
        "sold_item_image", "sold_thumbnail", "order_item_thumbnail", "listing_thumbnail",
        "media_thumbnail",
        "thumbnail_url", "thumbnailUrl", "image_url", "imageUrl", "media_url",
        "lookbook_image", "lookbook_thumbnail", "photo_url", "photoUrl", "thumbnail", "image",
    ]

    private var metaDerivedListingURL: URL? {
        Self.metaImageURLFromNotificationExcludingSenderProfile(
            notification: notification,
            sender: notification.sender
        )
    }

    private var productIdForThumbnailResolve: Int? {
        if let p = notification.bellProductIdFromMeta { return p }
        return notification.bellModelBackedProductId(modelGroupLowercased: modelGroupLower)
    }

    /// Listing art uses animated mystery when the API, meta, URL shape, or product fetch says so.
    private var listingMysteryAnimated: Bool {
        if isCelebrationOrBirthdayBellRow { return false }
        if productFetchMystery { return true }
        if cachedProductThumbResolve?.mystery == true { return true }
        if notification.relatedProductIsMysteryBox == true { return true }
        if notification.bellMysteryFromMeta { return true }
        if let s = notification.productThumbnailUrl, BellNotificationMysteryHelpers.isLikelyStaticMysteryOrPlaceholderCoverURL(s) {
            return true
        }
        return false
    }

    private var firstMetaImageRawString: String? {
        for key in Self.metaImageURLCandidateKeys {
            let raw = notification.metaValue(caseInsensitiveKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !raw.isEmpty else { continue }
            if let s = ProductListImageURL.preferredString(from: raw) { return s }
            return raw
        }
        return nil
    }

    /// Non-mystery, non-celebration: prefer server, then meta, then one-shot `getProduct` image.
    private var displayListingJpegURL: URL? {
        if isCelebrationOrBirthdayBellRow { return nil }
        if listingMysteryAnimated { return nil }
        if let u = serverProductThumbnailURL { return u }
        if let u = metaDerivedListingURL { return u }
        if let u = productFetchListingURL { return u }
        return cachedProductThumbResolve?.listingURL
    }

    private static func metaImageURLFromNotificationExcludingSenderProfile(
        notification: AppNotification,
        sender: AppNotification.NotificationSender?
    ) -> URL? {
        for key in Self.metaImageURLCandidateKeys {
            let raw = notification.metaValue(caseInsensitiveKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !raw.isEmpty else { continue }
            if BellNotificationMysteryHelpers.isLikelyStaticMysteryOrPlaceholderCoverURL(raw) { continue }
            let u: URL?
            if let s = ProductListImageURL.preferredString(from: raw) {
                u = Self.urlFromHTTPString(s)
            } else {
                u = Self.urlFromHTTPString(raw)
            }
            guard let resolved = u else { continue }
            if urlIsSenderProfileImage(resolved, sender: sender) { continue }
            return resolved
        }
        return nil
    }

    private static func urlIsSenderProfileImage(_ url: URL, sender: AppNotification.NotificationSender?) -> Bool {
        guard let sender else { return false }
        let parts: [String] = [sender.thumbnailUrl, sender.profilePictureUrl]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for p in parts {
            guard let u = Self.urlFromHTTPString(p) else { continue }
            if u.absoluteString == url.absoluteString { return true }
        }
        return false
    }

    private var isCelebrationOrBirthdayBellRow: Bool {
        let m = notification.message
        if m.contains("🎉"), m.localizedCaseInsensitiveContains("special day") { return true }
        if m.contains("🥳"), m.localizedCaseInsensitiveContains("special day") { return true }
        if m.localizedCaseInsensitiveContains("wishing you a birth") { return true }
        if m.localizedCaseInsensitiveContains("birthday"), m.contains("🎂") || m.contains("🎉") || m.contains("🥳") { return true }
        return false
    }

    private var modelGroupLower: String {
        (notification.modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var prefetchedChatListingHint: NotificationBellConversationPrefetcher.ChatListingHint? {
        guard notification.isChatCentricNotification, let cid = notification.bellConversationIdFromMeta else { return nil }
        return NotificationBellConversationPrefetcher.shared.listing(forConversationId: cid)
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

    /// New offer on your listing(s) - shorten list copy.
    private var isNewOfferOnListingMessage: Bool {
        notification.message.lowercased().contains("made an offer on your product")
    }

    /// Someone liked your product - tighten wording.
    private var isProductLikeMessage: Bool {
        modelGroupLower == "product" && notification.message.lowercased().contains("liked your product")
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
        // Comments (avoid bare `comment` substring - too broad)
        if mg == "comment" || mg == "comments" { return true }
        if m.contains("commented") { return true }
        if m.contains("comment on your") || m.contains("new comment on your") { return true }
        // Likes - product
        if isProductLikeMessage { return true }
        // Likes - lookbook / feed (do not use `modelGroup == lookbook` alone; that catches non-like rows)
        if m.contains("liked your lookbook") || m.contains("likes your lookbook") { return true }
        if m.contains("lookbook post"), (m.contains("liked") || m.contains("likes")) { return true }
        return false
    }

    private var senderAvatarURL: URL? {
        let thumbnailRaw = notification.sender?.thumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !thumbnailRaw.isEmpty, let thumbURL = Self.urlFromHTTPString(thumbnailRaw) {
            return thumbURL
        }
        let raw = notification.sender?.profilePictureUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
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
            let name = NotificationUsernameDisplay.canonicalUsernameForDisplay(username)
            return String(format: L10n.string("%@ sent you an offer."), name)
        }
        if isProductLikeMessage,
           let username = notification.sender?.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            let name = NotificationUsernameDisplay.canonicalUsernameForDisplay(username)
            return String(format: L10n.string("%@ likes your item."), name)
        }
        if notification.isChatCentricNotification,
           let cid = notification.bellConversationIdFromMeta,
           let hint = NotificationBellConversationPrefetcher.shared.listing(forConversationId: cid),
           let line = hint.lastMessagePreview?.trimmingCharacters(in: .whitespacesAndNewlines),
           !line.isEmpty {
            if let username = notification.sender?.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
                let display = NotificationUsernameDisplay.canonicalUsernameForDisplay(username)
                return "\(display) \(line)"
            }
            return line
        }
        guard let username = notification.sender?.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty else {
            return msg
        }
        let lowerMsg = msg.lowercased()
        let lowerUser = username.lowercased()
        if lowerMsg.hasPrefix(lowerUser + " ") || lowerMsg == lowerUser {
            return NotificationUsernameDisplay.replacingLeadingUsername(fullText: msg, username: username)
        }
        // Prepend sender: always show lowercase handle (no leading capital).
        let display = NotificationUsernameDisplay.canonicalUsernameForDisplay(username)
        return "\(display) \(msg)"
    }

    /// When the line starts with the sender username, return that segment (preserving message casing) and the rest for styled `Text` composition.
    private var usernamePrefixAndBody: (username: String, body: String)? {
        if isSupportNotification { return nil }
        guard let u = notification.sender?.username?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty else { return nil }
        let canonical = NotificationUsernameDisplay.canonicalUsernameForDisplay(u)
        let msg = displayMessage
        guard msg.lowercased().hasPrefix(canonical) else { return nil }
        let nameEnd = msg.index(msg.startIndex, offsetBy: canonical.count)
        guard nameEnd <= msg.endIndex else { return nil }
        if nameEnd < msg.endIndex, msg[nameEnd] == " " {
            let afterSpace = msg.index(after: nameEnd)
            return (canonical, String(msg[afterSpace...]))
        }
        if nameEnd == msg.endIndex { return (canonical, "") }
        return nil
    }

    private var notificationBodyFont: Font {
        .system(size: Self.lineFontSize, weight: .regular)
    }

    private var notificationTimeFont: Font {
        .system(size: Self.timeFontSize, weight: .regular)
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
        } else if isCelebrationOrBirthdayBellRow, !isSocialSenderAvatarThumbnail {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
                .frame(width: Self.productThumbWidth, height: Self.productThumbHeight)
                .overlay(
                    Image(systemName: "gift.fill")
                        .font(.system(size: Self.placeholderSymbolPointSize * 1.1, weight: .semibold))
                        .foregroundStyle(Theme.primaryColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
        } else if listingMysteryAnimated, !isSocialSenderAvatarThumbnail {
            MysteryBoxAnimatedMediaView()
                .frame(width: Self.productThumbWidth, height: Self.productThumbHeight)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
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
                imageReloadEpoch: imageReloadEpoch,
                failureIcon: { socialAvatarInitialPlaceholder }
            )
            .circularAvatarHairlineBorder()
        } else {
            // Non-social rows: server / meta / `getProduct` JPEG, or placeholder - never the sender’s profile in the bell list.
            NotificationBellThumbnail(
                productURL: displayListingJpegURL,
                avatarURL: nil,
                width: Self.productThumbWidth,
                height: Self.productThumbHeight,
                cornerRadius: corner,
                circular: false,
                imageReloadEpoch: imageReloadEpoch,
                failureIcon: { productPlaceholderIcon }
            )
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

    /// No profile photo URL, image load failure, or empty URL: same default as profile (initial on brand circle).
    private var socialAvatarInitialPlaceholder: some View {
        UsernameInitialAvatarView(username: senderUsername ?? "", size: Self.socialAvatarDiameter)
    }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md * 0.8) {
            leadingThumbnail
            HStack(alignment: .center, spacing: Theme.Spacing.sm * 0.8) {
                messageText
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let date = notification.createdAt {
                    Text(formatDate(date))
                        .font(notificationTimeFont)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Self.rowVerticalPadding)
        .task(id: "\(notification.id)-\(imageReloadEpoch)") {
            await resolveProductThumbnailIfNeeded()
        }
    }

    @MainActor
    private func loadProductThumbResolveFromCacheIfPresent() -> Bool {
        guard let entry = cachedProductThumbResolve, entry.isComplete else { return false }
        productFetchListingURL = entry.listingURL
        productFetchMystery = entry.mystery
        return true
    }

    @MainActor
    private func persistProductThumbResolveCache() {
        Self.productThumbResolveCache[productThumbCacheKey] = NotificationProductThumbResolveCacheEntry(
            listingURL: productFetchListingURL,
            mystery: productFetchMystery,
            isComplete: true
        )
    }

    @MainActor
    private func resolveProductThumbnailIfNeeded() async {
        if loadProductThumbResolveFromCacheIfPresent() { return }
        defer { persistProductThumbResolveCache() }
        productFetchListingURL = nil
        productFetchMystery = false
        if isSupportNotification { return }
        if isSocialSenderAvatarThumbnail { return }
        if isCelebrationOrBirthdayBellRow { return }
        if notification.relatedProductIsMysteryBox == true { return }
        if notification.bellMysteryFromMeta { return }
        if let s = notification.productThumbnailUrl,
           BellNotificationMysteryHelpers.isLikelyStaticMysteryOrPlaceholderCoverURL(s) { return }
        if let s = firstMetaImageRawString,
           BellNotificationMysteryHelpers.isLikelyStaticMysteryOrPlaceholderCoverURL(s) { return }
        if serverProductThumbnailURL != nil { return }
        if metaDerivedListingURL != nil { return }

        productService.updateAuthToken(authService.authToken)
        userService.updateAuthToken(authService.authToken)

        var orderLine: (productId: Int, imageUrl: String?, isMysteryBox: Bool)?
        if let orderId = notification.bellOrderIdForNotificationThumbnail {
            if let cached = Self.orderLinePreviewByOrderId[orderId] {
                orderLine = cached
            } else if let loaded = try? await userService.getSoldOrderLineItemPreviewForBell(orderId: orderId) {
                Self.orderLinePreviewByOrderId[orderId] = loaded
                orderLine = loaded
            }
            if let ol = orderLine {
                if ol.isMysteryBox {
                    productFetchMystery = true
                    return
                }
                if let uStr = ol.imageUrl, let u = Self.urlFromHTTPString(uStr) {
                    productFetchListingURL = u
                    return
                }
            }
        }

        let productId = productIdForThumbnailResolve ?? orderLine?.productId
        guard let pid = productId else { return }

        guard let item = try? await productService.getProduct(id: pid) else { return }
        if item.isMysteryBox {
            productFetchMystery = true
            return
        }
        if let s = item.listDisplayImageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
           let u = Self.urlFromHTTPString(s) {
            productFetchListingURL = u
            return
        }
        for raw in item.imageURLs {
            if let u = Self.urlFromHTTPString(raw) {
                productFetchListingURL = u
                return
            }
        }
        if let uStr = orderLine?.imageUrl, let u = Self.urlFromHTTPString(uStr) {
            productFetchListingURL = u
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
