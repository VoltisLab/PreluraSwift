//
//  LookbookView.swift
//  Prelura-swift
//
//  Instagram-style feed: full-width images, scrollable, poster, comments (tappable), style filters.
//

import SwiftUI
import Shimmer
import UIKit

/// Strips query + fragment so presigned CDN URLs from different sessions still match local upload records.
fileprivate func lookbookNormalizedMediaURLString(_ raw: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let u = URL(string: t), var c = URLComponents(url: u, resolvingAgainstBaseURL: false) else { return t }
    c.query = nil
    c.fragment = nil
    return c.url?.absoluteString ?? t
}

/// Matches `LookbookFeedStore` records to API posts even when id/image string formatting differs.
func lookbookFeedLocalRecord(for post: ServerLookbookPost, records: [LookbookUploadRecord]) -> LookbookUploadRecord? {
    let pid = LookbookPostIdFormatting.graphQLUUIDString(from: post.id).lowercased()
    let surl = lookbookNormalizedMediaURLString(post.imageUrl)
    let sthumb = (post.thumbnailUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let sthumbNorm = sthumb.isEmpty ? "" : lookbookNormalizedMediaURLString(sthumb)
    let sLast = URL(string: surl)?.lastPathComponent ?? URL(string: post.imageUrl.trimmingCharacters(in: .whitespacesAndNewlines))?.lastPathComponent ?? surl

    return records.first { r in
        let rid = LookbookPostIdFormatting.graphQLUUIDString(from: r.id).lowercased()
        if rid == pid { return true }
        var recordUrls: [String] = [lookbookNormalizedMediaURLString(r.imagePath)]
        if let extra = r.imageUrls {
            recordUrls.append(contentsOf: extra.map { lookbookNormalizedMediaURLString($0) })
        }
        for rurl in recordUrls {
            let trimmed = rurl.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed == surl { return true }
            if !sthumbNorm.isEmpty, trimmed == sthumbNorm { return true }
            if surl.hasSuffix(trimmed) || trimmed.hasSuffix(surl) { return true }
            if !sthumbNorm.isEmpty, sthumbNorm.hasSuffix(trimmed) || trimmed.hasSuffix(sthumbNorm) { return true }
            let rLast = URL(string: trimmed)?.lastPathComponent ?? trimmed
            if !sLast.isEmpty && !rLast.isEmpty && sLast == rLast { return true }
        }
        return false
    }
}

/// One lookbook post: image(s), poster, comments, styles for filtering. Remote URLs in `imageUrls` (carousel), or legacy document/asset.
/// Optional tags + productSnapshots come from local LookbookFeedStore (merged when post id / URL matches).
struct LookbookEntry: Identifiable {
    let id: UUID
    /// Raw id from the API (`ServerLookbookPost.id`). Mutations must use this string, not a client-only `id` when it differs.
    let serverPostId: String?
    let imageNames: [String]
    /// When set, first image is loaded from Documents (legacy local).
    let documentImagePath: String?
    /// Remote slide URLs (single or multiple for in-post carousel). Empty when using document/assets only.
    let imageUrls: [String]
    /// Server or CDN thumbnail for the primary image (grid / fast loads); full `imageUrls` stay HD for the feed.
    let thumbnailUrl: String?
    /// First remote URL, if any.
    var imageUrl: String? { imageUrls.first }
    let posterUsername: String
    /// Remote avatar URL for the poster when the API provides it.
    let posterProfilePictureUrl: String?
    var caption: String?
    /// ISO8601 from API (`createdAt`); used for relative post time under caption.
    let createdAt: String?
    var likesCount: Int
    var isLiked: Bool
    var commentsCount: Int
    /// Server: opens of tagged products from this post.
    var productLinkClicks: Int
    /// Server: “View shop” taps attributed to this post.
    var shopLinkClicks: Int
    let styles: [String]
    /// Tag positions (0–1) and productIds; from local store when available.
    let tags: [LookbookTagData]?
    /// productId -> snapshot for thumbnails; from local store when available.
    let productSnapshots: [String: LookbookProductSnapshot]?
    /// From API when exposed (`taggedProductCount`); lets all viewers see grid product badge without local upload record.
    let serverTaggedProductCount: Int?

    /// GraphQL `UUID` argument for this post (server id when available).
    var apiPostId: String {
        let s = serverPostId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !s.isEmpty { return s }
        return id.uuidString
    }

    /// Normalized key for matching a row to `entries` and GraphQL (handles `urn:uuid:` / braces / casing).
    var lookbookPostKey: String {
        LookbookPostIdFormatting.graphQLUUIDString(from: apiPostId).lowercased()
    }

    init(id: UUID? = nil, serverPostId: String? = nil, imageNames: [String], documentImagePath: String? = nil, imageUrl: String? = nil, thumbnailUrl: String? = nil, posterUsername: String, posterProfilePictureUrl: String? = nil, caption: String? = nil, createdAt: String? = nil, likesCount: Int = 0, isLiked: Bool = false, commentsCount: Int, productLinkClicks: Int = 0, shopLinkClicks: Int = 0, styles: [String], serverTaggedProductCount: Int? = nil, tags: [LookbookTagData]? = nil, productSnapshots: [String: LookbookProductSnapshot]? = nil) {
        self.id = id ?? UUID()
        self.serverPostId = serverPostId
        self.imageNames = imageNames
        self.documentImagePath = documentImagePath
        if let u = imageUrl, !u.isEmpty {
            self.imageUrls = [u]
        } else {
            self.imageUrls = []
        }
        self.thumbnailUrl = thumbnailUrl
        self.posterUsername = posterUsername
        self.posterProfilePictureUrl = posterProfilePictureUrl
        self.caption = caption
        self.createdAt = createdAt
        self.likesCount = likesCount
        self.isLiked = isLiked
        self.commentsCount = commentsCount
        self.productLinkClicks = productLinkClicks
        self.shopLinkClicks = shopLinkClicks
        self.styles = styles
        self.serverTaggedProductCount = serverTaggedProductCount
        self.tags = tags
        self.productSnapshots = productSnapshots
    }

    /// Entry from server (feed). Merges local multi-image URLs and tags when record matches.
    init(from serverPost: ServerLookbookPost, localRecord: LookbookUploadRecord? = nil) {
        let tid = serverPost.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedId = LookbookPostIdFormatting.graphQLUUIDString(from: tid)
        self.serverPostId = normalizedId.isEmpty ? tid : normalizedId
        self.id = UUID(uuidString: normalizedId) ?? UUID(uuidString: tid) ?? UUID()
        self.imageNames = []
        self.documentImagePath = nil
        let serverTrim = serverPost.imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let fromServer: [String] = serverTrim.isEmpty ? [] : [serverTrim]
        if let local = localRecord {
            let localUrls = dedupeOrderedValidLookbookURLs(local.allImageUrls)
            if localUrls.count > 1 {
                self.imageUrls = localUrls
            } else {
                self.imageUrls = fromServer.isEmpty ? localUrls : fromServer
            }
        } else {
            self.imageUrls = fromServer
        }
        let apiThumb = serverPost.thumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = apiThumb, !t.isEmpty {
            self.thumbnailUrl = t
        } else if !serverTrim.isEmpty, let derived = LookbookCDNThumbnailURL.urlString(forFullImageURL: serverTrim) {
            self.thumbnailUrl = derived
        } else {
            self.thumbnailUrl = nil
        }
        self.posterUsername = serverPost.username
        self.posterProfilePictureUrl = serverPost.profilePictureUrl
        let serverCaptionTrimmed = serverPost.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let localCaptionTrimmed = localRecord?.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !serverCaptionTrimmed.isEmpty {
            self.caption = serverPost.caption
        } else if !localCaptionTrimmed.isEmpty {
            self.caption = localRecord?.caption
        } else {
            self.caption = nil
        }
        self.createdAt = serverPost.createdAt
        self.likesCount = serverPost.likesCount ?? 0
        self.isLiked = serverPost.userLiked ?? false
        self.commentsCount = serverPost.commentsCount ?? 0
        self.productLinkClicks = serverPost.productLinkClicks ?? 0
        self.shopLinkClicks = serverPost.shopLinkClicks ?? 0
        self.styles = localRecord?.styles ?? []
        self.serverTaggedProductCount = serverPost.taggedProductCount

        let fromServerTags: [LookbookTagData]? = serverPost.productTags?.map { t in
            let cid = t.clientId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return LookbookTagData(
                clientId: cid.isEmpty ? UUID().uuidString : cid,
                productId: t.productId,
                x: t.x,
                y: t.y,
                imageIndex: t.imageIndex ?? 0
            )
        }
        let fromServerSnaps: [String: LookbookProductSnapshot]? = {
            guard let ps = serverPost.productSnapshots, !ps.isEmpty else { return nil }
            var m: [String: LookbookProductSnapshot] = [:]
            for s in ps {
                let k = s.productId.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !k.isEmpty else { continue }
                m[k] = LookbookProductSnapshot(productId: k, title: s.title, imageUrl: s.imageUrl)
            }
            return m.isEmpty ? nil : m
        }()

        if let lt = fromServerTags, !lt.isEmpty {
            self.tags = lt
        } else {
            self.tags = localRecord?.tags
        }
        if let fs = fromServerSnaps, !fs.isEmpty {
            self.productSnapshots = fs
        } else {
            self.productSnapshots = localRecord?.productSnapshots
        }
    }
}

extension LookbookEntry {
    /// Distinct product ids from local tag pins (upload device only); does not require `productSnapshots`.
    fileprivate var localDistinctTaggedProductCount: Int {
        guard let tags = tags, !tags.isEmpty else { return 0 }
        let ids = tags.map { $0.productId.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Set(ids).count
    }

    /// Grid bag badge: prefer API count for all viewers; else local pins; else imply ≥1 if product/shop taps were recorded.
    fileprivate var gridThumbnailTaggedProductCount: Int {
        let fromServer = serverTaggedProductCount ?? 0
        let local = localDistinctTaggedProductCount
        var n = max(fromServer, local)
        if n == 0, productLinkClicks + shopLinkClicks > 0 { n = 1 }
        return n
    }

    /// Stable key for fullscreen grid → vertical pager (`scrollPosition`); avoids `UUID()` fallback collisions on `id`.
    fileprivate var lookbookImmersiveScrollKey: String {
        let k = lookbookPostKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !k.isEmpty { return k }
        return id.uuidString
    }

}

/// Vertical rhythm between major feed blocks (slightly looser than before).
private let lookbookSpacing: CGFloat = 16

/// Shared 3-column lookbook grid (Feed + My items).
private enum LookbookThreeColumnGrid {
    static let gutter: CGFloat = 2
    static let columns: [GridItem] = [
        GridItem(.flexible(), spacing: gutter),
        GridItem(.flexible(), spacing: gutter),
        GridItem(.flexible(), spacing: gutter)
    ]
}
/// Horizontal gap between carousel thumbnails (was `sm`; nudge wider).
private let lookbookThumbInterItem: CGFloat = Theme.Spacing.sm + 4
/// Ordered de-duplication so accidental duplicate URLs do not spawn a multi-page `TabView` with collapsed height.
private func dedupeOrderedValidLookbookURLs(_ urls: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for u in urls {
        let t = u.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, URL(string: t) != nil else { continue }
        if seen.insert(t).inserted { out.append(t) }
    }
    return out
}

/// Matches `prelura-app/utils/upload_utils.py` LOOKBOOK keys: `…/abc.jpeg` → `…/abc_thumbnail.jpeg` on the CDN.
private enum LookbookCDNThumbnailURL {
    static func urlString(forFullImageURL full: String) -> String? {
        let t = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let u = URL(string: t), u.host != nil, !u.path.isEmpty else { return nil }
        let path = u.path
        guard let dotIdx = path.lastIndex(of: "."), dotIdx < path.endIndex else { return nil }
        let prefix = path[..<dotIdx]
        let ext = path[path.index(after: dotIdx)...]
        if prefix.hasSuffix("_thumbnail") { return nil }
        let newPath = String(prefix) + "_thumbnail." + String(ext)
        var c = URLComponents(url: u, resolvingAgainstBaseURL: false)
        c?.path = newPath
        return c?.string
    }
}

// MARK: - Canonical media frames (1080×1350, 1080×1080, 1920×1080)

/// Width ÷ height for each canonical lookbook crop; closest bucket is chosen from the loaded image’s pixel aspect ratio.
private enum LookbookCanonicalAspect: CGFloat, CaseIterable {
    case portrait1080x1350 = 0.8 // 1080/1350
    case square1080 = 1
    case landscape1920x1080 = 1.7777777777777777 // 1920/1080

    static func bucket(for imageWidthOverHeight: CGFloat) -> Self {
        allCases.min(by: { abs($0.rawValue - imageWidthOverHeight) < abs($1.rawValue - imageWidthOverHeight) })!
    }
}

/// `AsyncImage` has no intrinsic size in `.empty`; without this, feed rows in a `LazyVStack` collapse to a thin strip (spinner only).
private let lookbookFeedAsyncImagePlaceholderAspect: CGFloat = LookbookCanonicalAspect.portrait1080x1350.rawValue

// MARK: - One feed row per post (`LookbookFeedRowModel.id` is stable per post; counts refresh via `entry` updates)

struct LookbookFeedRowModel: Identifiable {
    let id: String
    let entry: LookbookEntry
}

/// Stable per-post id for `ForEach` / `.id`. Do **not** bake like or comment counts into this — that recreates the whole row
/// (and any `UIViewRepresentable` like the heart) on every count change, which breaks taps.
func lookbookFeedRowStableId(for entry: LookbookEntry) -> String {
    let k = entry.lookbookPostKey
    if !k.isEmpty { return k }
    return entry.id.uuidString
}

func buildLookbookFeedRows(from list: [LookbookEntry]) -> [LookbookFeedRowModel] {
    list.map { entry in
        LookbookFeedRowModel(id: lookbookFeedRowStableId(for: entry), entry: entry)
    }
}

/// Same URLs the feed row carousel will load (`LookbookFeedRowView.carouselImageURLs` / `LookbookFeedRowRemoteImage`).
private func lookbookFeedMediaPrefetchURLs(for entry: LookbookEntry) -> [URL] {
    dedupeOrderedValidLookbookURLs(entry.imageUrls).compactMap { URL(string: $0) }
}

/// Warms `URLSession`/`URLCache` before `AsyncImage` mounts on `LazyVStack` rows (grid → list jump).
private actor LookbookFeedImagePrefetchCoordinator {
    static let shared = LookbookFeedImagePrefetchCoordinator()

    private var highWaterIndex: Int = 0
    private var lowWaterIndex: Int = 0
    private var lastScrollPrefetch: ContinuousClock.Instant?

    /// After opening the list from the grid: load the tapped post’s full media first (parallel), then neighbors in both directions.
    func beginAfterGridSelection(entries: [LookbookEntry], center: Int) async {
        guard entries.indices.contains(center) else { return }
        highWaterIndex = center
        lowWaterIndex = center
        let primary = lookbookFeedMediaPrefetchURLs(for: entries[center])
        await prefetchURLsParallel(primary)

        var dist = 1
        var postsBudget = 26
        while postsBudget > 0 {
            var stepped = false
            let hi = center + dist
            if hi < entries.count {
                await prefetchURLsSerial(lookbookFeedMediaPrefetchURLs(for: entries[hi]))
                highWaterIndex = max(highWaterIndex, hi)
                postsBudget -= 1
                stepped = true
            }
            let lo = center - dist
            if lo >= 0 {
                await prefetchURLsSerial(lookbookFeedMediaPrefetchURLs(for: entries[lo]))
                lowWaterIndex = min(lowWaterIndex, lo)
                postsBudget -= 1
                stepped = true
            }
            dist += 1
            if !stepped { break }
            await Task.yield()
        }
    }

    /// As the user scrolls the feed, extend the warm window in the scroll direction (throttled).
    func extendForScrollDelta(entries: [LookbookEntry], forward: Bool, span: Int = 6) async {
        guard !entries.isEmpty else { return }
        let now = ContinuousClock.now
        if let t = lastScrollPrefetch, now - t < .milliseconds(280) { return }
        lastScrollPrefetch = now

        if forward {
            let start = min(highWaterIndex + 1, entries.count - 1)
            guard start < entries.count else { return }
            let end = min(start + max(1, span) - 1, entries.count - 1)
            for i in start...end {
                await prefetchURLsSerial(lookbookFeedMediaPrefetchURLs(for: entries[i]))
            }
            highWaterIndex = max(highWaterIndex, end)
        } else {
            let start = max(lowWaterIndex - 1, 0)
            guard start >= 0 else { return }
            let end = max(start - max(1, span) + 1, 0)
            for i in (end...start).reversed() {
                await prefetchURLsSerial(lookbookFeedMediaPrefetchURLs(for: entries[i]))
            }
            lowWaterIndex = min(lowWaterIndex, end)
        }
    }

    private func prefetchURLsParallel(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for u in urls {
                group.addTask { await Self.warmURL(u) }
            }
        }
    }

    private func prefetchURLsSerial(_ urls: [URL]) async {
        for u in urls {
            await Self.warmURL(u)
        }
    }

    nonisolated private static func warmURL(_ url: URL) async {
        var req = URLRequest(url: url)
        req.cachePolicy = .returnCacheDataElseLoad
        req.timeoutInterval = 60
        do {
            _ = try await URLSession.shared.data(for: req)
        } catch {
            // Best-effort prefetch; feed row still retries on failure.
        }
    }
}

private func lookbookScheduleFeedImagePrefetchFromGrid(entries: [LookbookEntry], centerEntry: LookbookEntry) {
    let key = centerEntry.lookbookPostKey
    guard let idx = entries.firstIndex(where: { $0.lookbookPostKey == key }) else { return }
    Task(priority: .userInitiated) {
        await LookbookFeedImagePrefetchCoordinator.shared.beginAfterGridSelection(entries: entries, center: idx)
    }
}

/// Server like toggle with optimistic UI. Keeps `LikeButtonView` as the only tap target (no extra wrappers).
func handleLookbookFeedLikeTap(_ tapped: LookbookEntry, authService: AuthService, entries: Binding<[LookbookEntry]>) {
    guard authService.isAuthenticated else { return }
    let key = tapped.lookbookPostKey
    guard let idx = entries.wrappedValue.firstIndex(where: { $0.lookbookPostKey == key }) else { return }
    let prevLiked = entries.wrappedValue[idx].isLiked
    let prevCount = entries.wrappedValue[idx].likesCount
    var row = entries.wrappedValue[idx]
    row.isLiked.toggle()
    row.likesCount = max(0, prevCount + (row.isLiked ? 1 : -1))
    entries.wrappedValue[idx] = row

    let postId = tapped.apiPostId
    let token = authService.authToken
    Task {
        let client = GraphQLClient()
        client.setAuthToken(token)
        let service = LookbookService(client: client)
        service.setAuthToken(token)
        do {
            let result = try await service.toggleLike(postId: postId)
            await MainActor.run {
                var arr = entries.wrappedValue
                guard let i = arr.firstIndex(where: { $0.lookbookPostKey == key }) else { return }
                var u = arr[i]
                u.isLiked = result.liked
                u.likesCount = result.likesCount
                arr[i] = u
                entries.wrappedValue = arr
            }
        } catch {
            await MainActor.run {
                var arr = entries.wrappedValue
                guard let i = arr.firstIndex(where: { $0.lookbookPostKey == key }) else { return }
                var u = arr[i]
                u.isLiked = prevLiked
                u.likesCount = prevCount
                arr[i] = u
                entries.wrappedValue = arr
            }
        }
    }
}

/// Style raw values for filter pills — same as StyleSelectionView (uploads). Subset used for display.
private let lookbookStylePillValues: [String] = [
    "CASUAL", "VINTAGE", "STREETWEAR", "MINIMALIST", "BOHO", "CHIC", "FORMAL_WEAR",
    "PARTY_DRESS", "LOUNGEWEAR", "ACTIVEWEAR", "Y2K", "DRESSES_GOWNS", "DENIM_JEANS",
    "SUMMER_STYLES", "WINTER_ESSENTIALS", "ATHLEISURE", "DATE_NIGHT", "VACATION_RESORT_WEAR"
]

struct ProductIdNavigator: Identifiable, Hashable {
    let id: String
}

/// Lookbook entry from Menu / Discover: opens straight into the feed. Onboarding on first open.
struct LookbookView: View {
    @State private var showLookbooksOnboarding = false
    @State private var didScheduleLookbooksOnboarding = false

    var body: some View {
        LookbookFeedScreenView()
            .toolbar(.hidden, for: .tabBar)
            .onAppear { scheduleLookbooksOnboardingIfNeeded() }
            .overlay {
                if showLookbooksOnboarding {
                    LookbooksOnboardingPopupOverlay(onComplete: finishLookbooksOnboarding)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(900)
                }
            }
    }

    private func scheduleLookbooksOnboardingIfNeeded() {
        guard !didScheduleLookbooksOnboarding else { return }
        guard AppBannerPolicy.shouldPresent(.lookbooksIntro) else { return }
        didScheduleLookbooksOnboarding = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 380_000_000)
            withAnimation(.easeOut(duration: 0.22)) {
                showLookbooksOnboarding = true
            }
        }
    }

    private func finishLookbooksOnboarding() {
        if !AppBannerPolicy.forceShowLookbooksIntroEveryTime {
            AppBannerPolicy.markSeen(.lookbooksIntro)
        }
        withAnimation(.easeOut(duration: 0.2)) {
            showLookbooksOnboarding = false
        }
    }
}

// MARK: - Feed (posts only)

/// Lowercased usernames the viewer follows; used to pick which comment preview to show on each post.
@MainActor
func lookbookLoadFollowedUsernamesForFeedComments(authService: AuthService, graphQLClient: GraphQLClient) async -> Set<String> {
    guard authService.isAuthenticated,
          let raw = authService.username?.trimmingCharacters(in: .whitespacesAndNewlines),
          !raw.isEmpty else { return [] }
    let userSvc = UserService(client: graphQLClient)
    userSvc.updateAuthToken(authService.authToken)
    do {
        let following = try await userSvc.getFollowing(username: raw, pageCount: 500)
        return Set(following.compactMap { u -> String? in
            let n = u.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if n.isEmpty { return nil }
            return n.lowercased()
        })
    } catch {
        return []
    }
}

private func lookbookFollowingSetFingerprint(_ set: Set<String>) -> String {
    guard !set.isEmpty else { return "" }
    return set.sorted().joined(separator: "\u{1E}")
}

/// While immersive lookbook is open, disables the nav stack edge-swipe so the first Back dismisses the overlay (custom leading item), not the whole screen.
private struct LookbookNavigationInteractivePopGate: UIViewRepresentable {
    var disablesInteractivePop: Bool

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let disable = disablesInteractivePop
        DispatchQueue.main.async {
            guard let nav = uiView.lookbookNearestNavigationController() else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = !disable
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        DispatchQueue.main.async {
            guard let nav = uiView.lookbookNearestNavigationController() else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

private extension UIView {
    func lookbookNearestNavigationController() -> UINavigationController? {
        var r: UIResponder? = self
        while let cur = r {
            if let vc = cur as? UIViewController {
                return vc.navigationController
            }
            r = cur.next
        }
        return nil
    }
}

// MARK: - Lookbook list scroll (Lookbook settings: Sticky vs Smooth)

private extension View {
    /// Sticky list only: per-row targets for `.viewAligned` snap. Smooth uses plain inertial scroll (no snap).
    @ViewBuilder
    func lookbookListScrollTargetLayout(feel: LookbookImmersiveScrollFeel) -> some View {
        switch feel {
        case .sticky:
            self.scrollTargetLayout()
        case .smooth:
            self
        }
    }

    /// Sticky: snap posts into alignment. Smooth: no scroll-target behaviour (stop anywhere).
    @ViewBuilder
    func lookbookListScrollSnap(feel: LookbookImmersiveScrollFeel) -> some View {
        switch feel {
        case .sticky:
            self.scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        case .smooth:
            self
        }
    }
}

/// Bottom inset inside each immersive page so captions clear the floating shortcut bar.
private let lookbookImmersivePagerInnerBottomInset: CGFloat = 88

/// Random order whenever a lookbook feed load completes (screen open or pull-to-refresh).
private func lookbookShuffledEntriesFromPosts(_ posts: [ServerLookbookPost], localRecords: [LookbookUploadRecord]) -> [LookbookEntry] {
    var list = posts.map { post in
        LookbookEntry(from: post, localRecord: lookbookFeedLocalRecord(for: post, records: localRecords))
    }
    list.shuffle()
    return list
}

/// Animated hand hint for the Lookbook floating shortcut bar (swipe to collapse / expand).
private struct LookbookFabSwipeHandWiggle: View {
    @State private var offsetX: CGFloat = 0

    var body: some View {
        Image(systemName: "hand.draw.fill")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 26))
            .foregroundStyle(Theme.Colors.primaryText)
            .rotationEffect(.degrees(-8))
            .offset(x: offsetX, y: 2)
            .onAppear {
                offsetX = 0
                withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                    offsetX = 20
                }
            }
    }
}

/// Compact coach mark above the shortcut bar: swipe both ways, animated hand, dismiss with ✕.
private struct LookbookFloatingBarSwipeTipView: View {
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            LookbookFabSwipeHandWiggle()
                .frame(width: 42, height: 38)
            Text(L10n.string("Swipe this shortcut bar left or right to hide or show the buttons."))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.Colors.secondaryText, Theme.Colors.secondaryBackground.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("Close"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.primaryColor.opacity(0.42), Theme.primaryColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.14), radius: 14, y: 5)
    }
}

private struct LookbookFeedScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @ObservedObject private var immersiveScrollFeelStore = LookbookImmersiveScrollFeelStore.shared
    @AppStorage("lookbookFloatingBarSwipeTipDismissed_v1") private var lookbookFloatingBarSwipeTipDismissed = false
    @State private var entries: [LookbookEntry] = []
    @State private var followedCommentBoostUsernames: Set<String> = []
    @State private var feedLoading = false
    @State private var feedError: String?
    @State private var feedErrorBannerTitle: String?
    @State private var commentsEntry: LookbookEntry?
    @State private var selectedProductId: ProductIdNavigator?
    @State private var analyticsEntry: LookbookEntry?
    @State private var useGrid = true
    @State private var immersiveFeedInitialPostId: String?
    /// Outer vertical pager position (`ScrollView` + `scrollTargetLayout`, keyed by `LookbookEntry.id`).
    @State private var immersiveScrollTargetId: UUID?
    /// After grid → list, scroll this row id into view (`LookbookFeedRowModel.id`).
    @State private var pendingFeedListScrollRowId: String?
    /// Tracks vertical scroll offset for directional image prefetch after grid → list.
    @State private var feedListScrollOffsetY: CGFloat?
    /// When true, only the show/hide control is visible; swipe L→R on the bar to collapse, R→L (or tap chevron) to expand.
    @State private var lookbookQuickActionsCollapsed = false
    private let productService = ProductService()

    private var lookbookQuickActionsSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.86)
    }

    /// Show quick actions whenever we are not in the initial loading-empty state (so empty / error still gets shortcuts).
    private var showLookbookFeedFloatingActions: Bool {
        !(feedLoading && entries.isEmpty)
    }

    /// Space for the glass shortcut row plus optional first-run swipe tip above it.
    /// Tip is grid-only; list/feed (e.g. after opening a thumbnail) keeps clearance for the bar only.
    private var lookbookFeedQuickActionsBottomClearance: CGFloat {
        guard showLookbookFeedFloatingActions else { return 0 }
        if lookbookFloatingBarSwipeTipDismissed || !useGrid || immersiveFeedInitialPostId != nil {
            return 64
        }
        return 56 + 88 + 12
    }

    /// Matches `LookbookMyItemsScreenView.myItemsScrollBottomPadding`: list scroll clears the floating shortcut cluster.
    private var lookbookFeedListScrollBottomPadding: CGFloat {
        if immersiveFeedInitialPostId != nil { return Theme.Spacing.xl }
        if !showLookbookFeedFloatingActions { return Theme.Spacing.xl }
        return Theme.Spacing.xl + lookbookFeedQuickActionsBottomClearance
    }

    /// Liquid Glass circle; `interactive(false)` keeps default `.regular` material without the interactive lift shadow (taps still work on the outer `Button` / `NavigationLink`).
    private func lookbookFeedGlassCircleLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.Colors.primaryText)
            .frame(width: 54, height: 54)
            .glassEffect(.regular.interactive(false), in: .ellipse)
            .fixedSize()
    }

    /// Bottom inset for the floating shortcut row. Immersive bar uses `ignoresSafeArea(.bottom)` so this must include the **full** home-indicator inset plus a small margin (avoids stacking extra padding on top of an already safe-aligned overlay).
    private func lookbookFeedFloatingBarBottomInset(_ geometry: GeometryProxy, immersive: Bool) -> CGFloat {
        let s = geometry.safeAreaInsets.bottom
        if immersive {
            return s + 2
        }
        if s >= 60 {
            return Theme.Spacing.sm + Theme.Spacing.xs
        }
        return min(44, max(2, s - 48))
    }

    private func dismissLookbookFeedImmersive() {
        withAnimation(.easeOut(duration: 0.2)) {
            immersiveFeedInitialPostId = nil
            immersiveScrollTargetId = nil
        }
    }

    /// `onChange(of: useGrid)` on the list branch never runs for grid→list: the list is inserted with `useGrid` already false. Run from `onAppear` instead.
    private func scrollFeedListToPendingRowIfNeeded(proxy: ScrollViewProxy) {
        guard let id = pendingFeedListScrollRowId else { return }
        pendingFeedListScrollRowId = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(id, anchor: .top)
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            proxy.scrollTo(id, anchor: .top)
        }
    }

    private func handleFeedListScrollPrefetch(newY: CGFloat) {
        let prev = feedListScrollOffsetY ?? newY
        feedListScrollOffsetY = newY
        let delta = newY - prev
        guard abs(delta) > 56 else { return }
        let forward = delta > 0
        Task(priority: .utility) {
            await LookbookFeedImagePrefetchCoordinator.shared.extendForScrollDelta(entries: entries, forward: forward)
        }
    }

    @ViewBuilder
    private var lookbookFeedCollapseToggle: some View {
        Button {
            HapticManager.selection()
            lookbookQuickActionsCollapsed.toggle()
        } label: {
            Image(systemName: lookbookQuickActionsCollapsed ? "chevron.left" : "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(width: 54, height: 54)
                .glassEffect(.regular.interactive(false), in: .ellipse)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .frame(width: 54, height: 54)
        .fixedSize()
        .accessibilityLabel(
            lookbookQuickActionsCollapsed
                ? L10n.string("Show lookbook shortcuts")
                : L10n.string("Hide lookbook shortcuts")
        )
    }

    /// Shortcuts row: back (pop lookbook or exit immersive) → explore → create / my items / settings. Search + grid/list live in the nav bar.
    /// Per-icon `.glassEffect` only (same as `lookbookFeedCollapseToggle`). `GlassEffectContainer` adds grouped elevation/shadow that the standalone chevron does not get.
    @ViewBuilder
    private var lookbookFeedQuickActionsIconCluster: some View {
        HStack(spacing: 8) {
            Button {
                HapticManager.selection()
                if immersiveFeedInitialPostId != nil {
                    dismissLookbookFeedImmersive()
                } else {
                    dismiss()
                }
            } label: {
                lookbookFeedGlassCircleLabel(systemName: "chevron.backward")
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel(L10n.string("Back"))

            NavigationLink {
                LookbookExploreScreenView()
            } label: {
                lookbookFeedGlassCircleLabel(systemName: "sparkles.rectangle.stack")
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel(L10n.string("Explore"))

            NavigationLink {
                LookbooksUploadView()
            } label: {
                lookbookFeedGlassCircleLabel(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel(L10n.string("Create a post"))

            NavigationLink {
                LookbookMyItemsScreenView()
            } label: {
                lookbookFeedGlassCircleLabel(systemName: "person.crop.square")
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel(L10n.string("My items"))

            NavigationLink {
                LookbookSettingsView()
            } label: {
                lookbookFeedGlassCircleLabel(systemName: "gearshape.fill")
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel(L10n.string("Settings"))
        }
    }

    @ViewBuilder
    private func lookbookFeedFloatingQuickActionsBar(bottomInset: CGFloat) -> some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: lookbookQuickActionsCollapsed ? 0 : 8) {
                lookbookFeedQuickActionsIconCluster
                    .opacity(lookbookQuickActionsCollapsed ? 0 : 1)
                    .offset(x: lookbookQuickActionsCollapsed ? 14 : 0, y: lookbookQuickActionsCollapsed ? 6 : 0)
                    .scaleEffect(lookbookQuickActionsCollapsed ? 0.88 : 1, anchor: .trailing)
                    .frame(width: lookbookQuickActionsCollapsed ? 0 : nil, alignment: .trailing)
                    .clipped()
                    .allowsHitTesting(!lookbookQuickActionsCollapsed)
                    .accessibilityHidden(lookbookQuickActionsCollapsed)

                lookbookFeedCollapseToggle
            }
            .padding(.horizontal, Theme.Spacing.md)
            .animation(lookbookQuickActionsSpring, value: lookbookQuickActionsCollapsed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 28)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dy) < 56 else { return }
                        if dx > 52, !lookbookQuickActionsCollapsed {
                            HapticManager.selection()
                            lookbookQuickActionsCollapsed = true
                        } else if dx < -52, lookbookQuickActionsCollapsed {
                            HapticManager.selection()
                            lookbookQuickActionsCollapsed = false
                        }
                    }
            )
        }
        .padding(.bottom, bottomInset)
    }

    var body: some View {
        GeometryReader { geometry in
            let barBottomInset = lookbookFeedFloatingBarBottomInset(geometry, immersive: immersiveFeedInitialPostId != nil)
            ZStack(alignment: .bottom) {
                Group {
                    if feedLoading && entries.isEmpty {
                        Group {
                            if useGrid {
                                LookbookGridShimmerView(
                                    bottomBarPadding: lookbookFeedQuickActionsBottomClearance
                                )
                            } else {
                                LookbookFeedOnlyShimmerView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if entries.isEmpty {
                        feedEmptyPlaceholder(minHeight: geometry.size.height - 120)
                    } else if useGrid {
                        ScrollView {
                            LazyVGrid(columns: LookbookThreeColumnGrid.columns, spacing: LookbookThreeColumnGrid.gutter) {
                                ForEach(entries) { entry in
                                    Button {
                                        HapticManager.tap()
                                        lookbookScheduleFeedImagePrefetchFromGrid(entries: entries, centerEntry: entry)
                                        let rowId = lookbookFeedRowStableId(for: entry)
                                        var tx = Transaction()
                                        tx.animation = nil
                                        withTransaction(tx) {
                                            pendingFeedListScrollRowId = rowId
                                            useGrid = false
                                        }
                                    } label: {
                                        LookbookSquareGridThumbnail(entry: entry)
                                            .padding(1)
                                            .background(Theme.Colors.background)
                                            .aspectRatio(1, contentMode: .fit)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2)
                            .padding(.bottom, lookbookFeedQuickActionsBottomClearance)
                        }
                        .scrollContentBackground(.hidden)
                        .background(Theme.Colors.background)
                    } else {
                            ScrollViewReader { proxy in
                            ScrollView {
                                LookbookScrollImmediateTouchesAnchor()
                                    .frame(width: 0, height: 0)
                                LazyVStack(spacing: 0) {
                                    ForEach(buildLookbookFeedRows(from: entries)) { row in
                                        lookbookFeedRow(model: row)
                                            .id(row.id)
                                    }
                                }
                                .padding(.bottom, lookbookFeedListScrollBottomPadding)
                                .lookbookListScrollTargetLayout(feel: immersiveScrollFeelStore.feel)
                            }
                            .id(immersiveScrollFeelStore.feel)
                            .scrollContentBackground(.hidden)
                            .background(Theme.Colors.background)
                            .lookbookListScrollSnap(feel: immersiveScrollFeelStore.feel)
                            .onScrollGeometryChange(for: CGFloat.self) { geo in
                                -geo.contentOffset.y
                            } action: { _, newY in
                                handleFeedListScrollPrefetch(newY: newY)
                            }
                            .onAppear {
                                scrollFeedListToPendingRowIfNeeded(proxy: proxy)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .compositingGroup()
                .animation(nil, value: lookbookQuickActionsCollapsed)

                if immersiveFeedInitialPostId != nil {
                    GeometryReader { geo in
                        let pageHeight = geo.size.height
                        ZStack(alignment: .topTrailing) {
                            Theme.Colors.background.ignoresSafeArea()
                            feedImmersiveVerticalPager(pageHeight: pageHeight)
                            feedImmersiveDismissButton
                        }
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if showLookbookFeedFloatingActions {
                    VStack(spacing: 10) {
                        if useGrid && immersiveFeedInitialPostId == nil && !lookbookFloatingBarSwipeTipDismissed {
                            LookbookFloatingBarSwipeTipView {
                                HapticManager.selection()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                                    lookbookFloatingBarSwipeTipDismissed = true
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                        }
                        lookbookFeedFloatingQuickActionsBar(bottomInset: barBottomInset)
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.88), value: lookbookFloatingBarSwipeTipDismissed)
                    .animation(.spring(response: 0.35, dampingFraction: 0.88), value: useGrid)
                    .animation(.spring(response: 0.35, dampingFraction: 0.88), value: immersiveFeedInitialPostId)
                    .ignoresSafeArea(edges: immersiveFeedInitialPostId != nil ? .bottom : [])
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: immersiveFeedInitialPostId)
        .navigationTitle(L10n.string("Lookbook"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    HapticManager.selection()
                    useGrid.toggle()
                } label: {
                    Image(systemName: useGrid ? "list.bullet" : "square.grid.3x3")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(useGrid ? L10n.string("List view") : L10n.string("Grid view"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    LookbookFeedSearchView(entries: entries)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("Search"))
            }
        }
        .background {
            LookbookNavigationInteractivePopGate(disablesInteractivePop: immersiveFeedInitialPostId != nil)
        }
        .sheet(item: $commentsEntry) { entry in
            LookbookCommentsSheet(entry: entry) { newCount in
                let key = entry.apiPostId.lowercased()
                if let idx = entries.firstIndex(where: { $0.apiPostId.lowercased() == key }) {
                    var updated = entries[idx]
                    updated.commentsCount = newCount
                    entries[idx] = updated
                }
            }
            .lookbookCommentsPresentationChrome()
        }
        .navigationDestination(item: $selectedProductId) { nav in
            LookbookProductDetailLoader(productId: nav.id, productService: productService, authService: authService)
        }
        .navigationDestination(item: $analyticsEntry) { entry in
            LookbookAnalyticsView(entry: entry)
                .environmentObject(authService)
        }
        .onAppear { loadFeedFromServer() }
        .refreshable { await loadFeedFromServerAsync() }
    }

    private func loadFeedFromServer() {
        Task { await loadFeedFromServerAsync() }
    }

    private func loadFeedFromServerAsync() async {
        guard authService.isAuthenticated else {
            await MainActor.run {
                entries = []
                followedCommentBoostUsernames = []
                feedLoading = false
                feedError = nil
                feedErrorBannerTitle = nil
            }
            return
        }
        await MainActor.run { feedLoading = true; feedError = nil; feedErrorBannerTitle = nil }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        service.setAuthToken(authService.authToken)
        do {
            let clientFollowing = GraphQLClient()
            clientFollowing.setAuthToken(authService.authToken)
            async let postsTask = service.fetchLookbooks()
            async let followedTask = lookbookLoadFollowedUsernamesForFeedComments(authService: authService, graphQLClient: clientFollowing)
            let posts = try await postsTask
            let followedSet = await followedTask
            let localRecords = LookbookFeedStore.load()
            await MainActor.run {
                followedCommentBoostUsernames = followedSet
                entries = lookbookShuffledEntriesFromPosts(posts, localRecords: localRecords)
                feedLoading = false
                feedError = nil
                feedErrorBannerTitle = nil
            }
        } catch {
            await MainActor.run {
                feedLoading = false
                let isCancelled = (error as? CancellationError) != nil
                    || (error as? URLError)?.code == .cancelled
                    || error.localizedDescription.lowercased().contains("cancelled")
                feedError = isCancelled ? nil : L10n.userFacingError(error)
                feedErrorBannerTitle = isCancelled ? nil : L10n.userFacingErrorBannerTitle(error)
            }
        }
    }

    private func feedEmptyPlaceholder(minHeight: CGFloat) -> some View {
        Group {
            if let err = feedError, !err.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    FeedNetworkBannerView(message: err, title: feedErrorBannerTitle) {
                        loadFeedFromServer()
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: max(minHeight, 200))
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(L10n.string("No Lookbook posts yet"))
                        .font(Theme.Typography.title3)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text(L10n.string("Upload from the menu to add your first look."))
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: max(minHeight, 200))
            }
        }
    }

    @ViewBuilder
    private func feedImmersivePagerPage(entry: LookbookEntry, pageHeight: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LookbookScrollImmediateTouchesAnchor()
                .frame(width: 0, height: 0)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                lookbookFeedRow(
                    model: LookbookFeedRowModel(
                        id: "imm-\(lookbookFeedRowStableId(for: entry))",
                        entry: entry
                    ),
                    immersive: true
                )
                Spacer(minLength: 0)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: pageHeight)
            .padding(.bottom, lookbookImmersivePagerInnerBottomInset)
        }
        .frame(maxWidth: .infinity, minHeight: pageHeight, maxHeight: pageHeight)
        .clipped()
        .id(entry.id)
    }

    @ViewBuilder
    private func feedImmersivePagesStack(pageHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                feedImmersivePagerPage(entry: entry, pageHeight: pageHeight)
            }
        }
        .scrollTargetLayout()
    }

    private var feedImmersiveDismissButton: some View {
        Button {
            dismissLookbookFeedImmersive()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.trailing, 12)
    }

    private func feedImmersiveVerticalPager(pageHeight: CGFloat) -> some View {
        Group {
            if immersiveScrollFeelStore.feel == .sticky {
                ScrollView(.vertical, showsIndicators: false) {
                    LookbookScrollImmediateTouchesAnchor()
                        .frame(width: 0, height: 0)
                    feedImmersivePagesStack(pageHeight: pageHeight)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $immersiveScrollTargetId, anchor: .center)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LookbookScrollImmediateTouchesAnchor()
                        .frame(width: 0, height: 0)
                    feedImmersivePagesStack(pageHeight: pageHeight)
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $immersiveScrollTargetId, anchor: .center)
            }
        }
        .id("\(immersiveFeedInitialPostId ?? "lookbook-immersive-feed")-\(immersiveScrollFeelStore.feel.rawValue)")
        .task(id: immersiveFeedInitialPostId) {
            guard let pid = immersiveFeedInitialPostId else {
                await MainActor.run { immersiveScrollTargetId = nil }
                return
            }
            await Task.yield()
            await Task.yield()
            await MainActor.run {
                immersiveScrollTargetId = entries.first { $0.apiPostId.lowercased() == pid.lowercased() }?.id
                    ?? entries.first?.id
            }
        }
        .onChange(of: entries.count) { _, newCount in
            if newCount == 0 {
                immersiveFeedInitialPostId = nil
                immersiveScrollTargetId = nil
            }
        }
    }

    private func lookbookFeedRow(model: LookbookFeedRowModel, immersive: Bool = false) -> some View {
        LookbookFeedRowView(
            entry: model.entry,
            followedCommentBoostUsernames: followedCommentBoostUsernames,
            onCommentsTap: { commentsEntry = $0 },
            onProductTap: { productId in selectedProductId = ProductIdNavigator(id: productId) },
            onPostDeleted: { deleted in
                entries.removeAll { $0.lookbookPostKey == deleted.lookbookPostKey }
            },
            onOpenAnalytics: { analyticsEntry = $0 },
            onLikeTap: { tapped in
                handleLookbookFeedLikeTap(tapped, authService: authService, entries: $entries)
            },
            onPostCaptionUpdated: { updated in
                let k = updated.lookbookPostKey
                if let idx = entries.firstIndex(where: { $0.lookbookPostKey == k }) {
                    entries[idx] = updated
                }
            },
            immersive: immersive
        )
        .padding(.bottom, immersive ? 0 : lookbookSpacing)
    }
}

// MARK: - Single post (deep link / chat) — full Feed row UI, isolated

/// One lookbook post with the same chrome as the main Feed (like, comment, send, save, tags), not the image-only lightbox.
struct LookbookSinglePostFeedPresentedView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var savedLookbookFavorites: SavedLookbookFavoritesStore
    @State private var entries: [LookbookEntry]
    @State private var followedCommentBoostUsernames: Set<String> = []
    @State private var commentsEntry: LookbookEntry?
    @State private var selectedProductId: ProductIdNavigator?
    @State private var analyticsEntry: LookbookEntry?
    private let productService = ProductService()
    let onDismiss: () -> Void

    init(entry: LookbookEntry, onDismiss: @escaping () -> Void) {
        _entries = State(initialValue: [entry])
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LookbookScrollImmediateTouchesAnchor()
                    .frame(width: 0, height: 0)
                LazyVStack(spacing: 0) {
                    ForEach(buildLookbookFeedRows(from: entries)) { model in
                        singlePostRow(model: model)
                    }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Feed"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.Colors.primaryText)
                    }
                    .accessibilityLabel(L10n.string("Back"))
                }
            }
            .sheet(item: $commentsEntry) { entry in
                LookbookCommentsSheet(entry: entry) { newCount in
                    let key = entry.apiPostId.lowercased()
                    if let idx = entries.firstIndex(where: { $0.apiPostId.lowercased() == key }) {
                        var updated = entries[idx]
                        updated.commentsCount = newCount
                        entries[idx] = updated
                    }
                }
                .lookbookCommentsPresentationChrome()
            }
            .navigationDestination(item: $selectedProductId) { nav in
                LookbookProductDetailLoader(productId: nav.id, productService: productService, authService: authService)
            }
            .navigationDestination(item: $analyticsEntry) { entry in
                LookbookAnalyticsView(entry: entry)
                    .environmentObject(authService)
            }
            .task {
                let client = GraphQLClient()
                client.setAuthToken(authService.authToken)
                followedCommentBoostUsernames = await lookbookLoadFollowedUsernamesForFeedComments(
                    authService: authService,
                    graphQLClient: client
                )
            }
        }
    }

    private func singlePostRow(model: LookbookFeedRowModel) -> some View {
        LookbookFeedRowView(
            entry: model.entry,
            followedCommentBoostUsernames: followedCommentBoostUsernames,
            onCommentsTap: { commentsEntry = $0 },
            onProductTap: { productId in selectedProductId = ProductIdNavigator(id: productId) },
            onPostDeleted: { _ in onDismiss() },
            onOpenAnalytics: { analyticsEntry = $0 },
            onLikeTap: { tapped in
                handleLookbookFeedLikeTap(tapped, authService: authService, entries: $entries)
            },
            onPostCaptionUpdated: { updated in
                let k = updated.lookbookPostKey
                if let idx = entries.firstIndex(where: { $0.lookbookPostKey == k }) {
                    entries[idx] = updated
                }
            }
        )
        .padding(.bottom, lookbookSpacing)
    }
}

// MARK: - Explore (style strip + editorial carousels)

private struct LookbookExploreScreenView: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LookbookStyleThumbnailStrip()
                    LookbookHorizontalPortraitSection(
                        title: L10n.string("Explore communities"),
                        subtitle: L10n.string("Curated themes and seller stories to browse."),
                        showSeeAll: true,
                        cards: LookbookFeedAssets.exploreCommunityCards,
                        visibleThumbCount: 2.8,
                        containerWidth: geometry.size.width
                    )
                    LookbookHorizontalPortraitSection(
                        title: L10n.string("Get inspired"),
                        subtitle: L10n.string("Editorial picks and seasonal mood boards."),
                        showSeeAll: false,
                        cards: LookbookFeedAssets.getInspiredCards,
                        visibleThumbCount: 2,
                        containerWidth: geometry.size.width
                    )
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
        }
        .navigationTitle(L10n.string("Explore"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - My items (own posts, list or 3-column grid)

private struct LookbookMyItemsScreenView: View {
    @EnvironmentObject private var authService: AuthService
    @ObservedObject private var immersiveScrollFeelStore = LookbookImmersiveScrollFeelStore.shared
    @State private var entries: [LookbookEntry] = []
    @State private var followedCommentBoostUsernames: Set<String> = []
    @State private var feedLoading = false
    @State private var feedError: String?
    @State private var feedErrorBannerTitle: String?
    @State private var useGrid = false
    @State private var commentsEntry: LookbookEntry?
    /// When set, shows a full-screen vertical pager (Instagram/TikTok-style) starting at this post id.
    @State private var immersiveFeedInitialPostId: String?
    @State private var immersiveScrollTargetId: UUID?
    @State private var pendingMyItemsListScrollRowId: String?
    @State private var myItemsListScrollOffsetY: CGFloat?
    @State private var selectedProductId: ProductIdNavigator?
    @State private var analyticsEntry: LookbookEntry?
    private let productService = ProductService()

    private var myEntries: [LookbookEntry] {
        guard let me = authService.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !me.isEmpty else { return [] }
        return entries.filter { $0.posterUsername.lowercased() == me }
    }

    private var showMyItemsGridListFAB: Bool {
        immersiveFeedInitialPostId == nil && !(feedLoading && entries.isEmpty)
    }

    private var myItemsScrollBottomPadding: CGFloat {
        if immersiveFeedInitialPostId != nil { return Theme.Spacing.xl }
        if !showMyItemsGridListFAB { return Theme.Spacing.xl }
        return Theme.Spacing.xl + 64
    }

    /// Same idea as `lookbookFeedFloatingBarBottomInset`: avoid oversized `safeArea.bottom - 36` on tabbed devices.
    private func lookbookMyItemsFABBottomInset(_ geometry: GeometryProxy) -> CGFloat {
        let s = geometry.safeAreaInsets.bottom
        if s >= 60 {
            return Theme.Spacing.sm + Theme.Spacing.xs
        }
        return min(50, max(Theme.Spacing.xs, s - 36))
    }

    @ViewBuilder
    private func immersivePagerPage(entry: LookbookEntry, pageHeight: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LookbookScrollImmediateTouchesAnchor()
                .frame(width: 0, height: 0)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                lookbookFeedRow(
                    model: LookbookFeedRowModel(
                        id: "imm-\(lookbookFeedRowStableId(for: entry))",
                        entry: entry
                    ),
                    immersive: true
                )
                Spacer(minLength: 0)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: pageHeight)
            .padding(.bottom, lookbookImmersivePagerInnerBottomInset)
        }
        .frame(maxWidth: .infinity, minHeight: pageHeight, maxHeight: pageHeight)
        .clipped()
        .id(entry.id)
    }

    @ViewBuilder
    private func myItemsImmersivePagesStack(pageHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(myEntries) { entry in
                immersivePagerPage(entry: entry, pageHeight: pageHeight)
            }
        }
        .scrollTargetLayout()
    }

    private func dismissMyItemsImmersive() {
        withAnimation(.easeOut(duration: 0.2)) {
            immersiveFeedInitialPostId = nil
            immersiveScrollTargetId = nil
        }
    }

    private func scrollMyItemsListToPendingRowIfNeeded(proxy: ScrollViewProxy) {
        guard let id = pendingMyItemsListScrollRowId else { return }
        pendingMyItemsListScrollRowId = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(id, anchor: .top)
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            proxy.scrollTo(id, anchor: .top)
        }
    }

    private func handleMyItemsListScrollPrefetch(newY: CGFloat) {
        let prev = myItemsListScrollOffsetY ?? newY
        myItemsListScrollOffsetY = newY
        let delta = newY - prev
        guard abs(delta) > 56 else { return }
        let forward = delta > 0
        let slice = myEntries
        Task(priority: .utility) {
            await LookbookFeedImagePrefetchCoordinator.shared.extendForScrollDelta(entries: slice, forward: forward)
        }
    }

    private var immersivePagerDismissButton: some View {
        Button {
            dismissMyItemsImmersive()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.trailing, 12)
    }

    @ViewBuilder
    private func immersiveVerticalPager(pageHeight: CGFloat) -> some View {
        Group {
            if immersiveScrollFeelStore.feel == .sticky {
                ScrollView(.vertical, showsIndicators: false) {
                    LookbookScrollImmediateTouchesAnchor()
                        .frame(width: 0, height: 0)
                    myItemsImmersivePagesStack(pageHeight: pageHeight)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $immersiveScrollTargetId, anchor: .center)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LookbookScrollImmediateTouchesAnchor()
                        .frame(width: 0, height: 0)
                    myItemsImmersivePagesStack(pageHeight: pageHeight)
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $immersiveScrollTargetId, anchor: .center)
            }
        }
        .id("\(immersiveFeedInitialPostId ?? "lookbook-immersive-myitems")-\(immersiveScrollFeelStore.feel.rawValue)")
        .task(id: immersiveFeedInitialPostId) {
            guard let pid = immersiveFeedInitialPostId else {
                await MainActor.run { immersiveScrollTargetId = nil }
                return
            }
            await Task.yield()
            await Task.yield()
            await MainActor.run {
                immersiveScrollTargetId = myEntries.first { $0.apiPostId.lowercased() == pid.lowercased() }?.id
                    ?? myEntries.first?.id
            }
        }
        .onChange(of: myEntries.count) { _, newCount in
            if newCount == 0 {
                immersiveFeedInitialPostId = nil
                immersiveScrollTargetId = nil
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Group {
                        if feedLoading && entries.isEmpty {
                            Group {
                                if useGrid {
                                    LookbookGridShimmerView(
                                        bottomBarPadding: showMyItemsGridListFAB ? 56 : 0
                                    )
                                } else {
                                    LookbookFeedOnlyShimmerView()
                                }
                            }
                        } else if myEntries.isEmpty {
                            myItemsEmpty
                        } else if useGrid {
                            ScrollView {
                                LazyVGrid(columns: LookbookThreeColumnGrid.columns, spacing: LookbookThreeColumnGrid.gutter) {
                                    ForEach(myEntries) { entry in
                                        Button {
                                            HapticManager.tap()
                                            lookbookScheduleFeedImagePrefetchFromGrid(entries: myEntries, centerEntry: entry)
                                            let rowId = lookbookFeedRowStableId(for: entry)
                                            var tx = Transaction()
                                            tx.animation = nil
                                            withTransaction(tx) {
                                                pendingMyItemsListScrollRowId = rowId
                                                useGrid = false
                                            }
                                        } label: {
                                            LookbookSquareGridThumbnail(entry: entry)
                                                .padding(1)
                                                .background(Theme.Colors.background)
                                                .aspectRatio(1, contentMode: .fit)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(2)
                                .padding(.bottom, showMyItemsGridListFAB ? 56 : 0)
                            }
                            .scrollContentBackground(.hidden)
                            .background(Theme.Colors.background)
                        } else {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LookbookScrollImmediateTouchesAnchor()
                                        .frame(width: 0, height: 0)
                                    LazyVStack(spacing: 0) {
                                        ForEach(buildLookbookFeedRows(from: myEntries)) { row in
                                            lookbookFeedRow(model: row)
                                                .id(row.id)
                                        }
                                    }
                                    .padding(.bottom, myItemsScrollBottomPadding)
                                    .lookbookListScrollTargetLayout(feel: immersiveScrollFeelStore.feel)
                                }
                                .id(immersiveScrollFeelStore.feel)
                                .scrollContentBackground(.hidden)
                                .background(Theme.Colors.background)
                                .lookbookListScrollSnap(feel: immersiveScrollFeelStore.feel)
                                .onScrollGeometryChange(for: CGFloat.self) { geo in
                                    -geo.contentOffset.y
                                } action: { _, newY in
                                    handleMyItemsListScrollPrefetch(newY: newY)
                                }
                                .onAppear {
                                    scrollMyItemsListToPendingRowIfNeeded(proxy: proxy)
                                }
                            }
                        }
                    }

                    if immersiveFeedInitialPostId != nil {
                        GeometryReader { geo in
                            let pageHeight = geo.size.height
                            ZStack(alignment: .topTrailing) {
                                Theme.Colors.background.ignoresSafeArea()
                                immersiveVerticalPager(pageHeight: pageHeight)
                                immersivePagerDismissButton
                            }
                        }
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showMyItemsGridListFAB {
                    Button {
                        HapticManager.selection()
                        useGrid.toggle()
                    } label: {
                        Image(systemName: useGrid ? "list.bullet" : "square.grid.3x3")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.Colors.primaryText)
                            .frame(width: 54, height: 54)
                            .glassEffect(.regular.interactive(false), in: .ellipse)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .frame(width: 54, height: 54)
                    .fixedSize()
                    .padding(.trailing, Theme.Spacing.md)
                    .padding(.bottom, lookbookMyItemsFABBottomInset(geometry))
                    .zIndex(1)
                    .accessibilityLabel(useGrid ? L10n.string("List view") : L10n.string("Grid view"))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: immersiveFeedInitialPostId)
        .navigationTitle(L10n.string("My items"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(immersiveFeedInitialPostId != nil)
        .toolbar {
            if immersiveFeedInitialPostId != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.selection()
                        dismissMyItemsImmersive()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.Colors.primaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("Back"))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: MyFavouritesView(lookbookOnly: true)) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .buttonStyle(HapticTapButtonStyle())
                .accessibilityLabel(L10n.string("Favourites"))
            }
        }
        .background {
            LookbookNavigationInteractivePopGate(disablesInteractivePop: immersiveFeedInitialPostId != nil)
        }
        .sheet(item: $commentsEntry) { entry in
            LookbookCommentsSheet(entry: entry) { newCount in
                let key = entry.apiPostId.lowercased()
                if let idx = entries.firstIndex(where: { $0.apiPostId.lowercased() == key }) {
                    var updated = entries[idx]
                    updated.commentsCount = newCount
                    entries[idx] = updated
                }
            }
            .lookbookCommentsPresentationChrome()
        }
        .navigationDestination(item: $selectedProductId) { nav in
            LookbookProductDetailLoader(productId: nav.id, productService: productService, authService: authService)
        }
        .navigationDestination(item: $analyticsEntry) { entry in
            LookbookAnalyticsView(entry: entry)
                .environmentObject(authService)
        }
        .onAppear { loadFeedFromServer() }
        .refreshable { await loadFeedFromServerAsync() }
    }

    private var myItemsEmpty: some View {
        Group {
            if let err = feedError, !err.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    FeedNetworkBannerView(message: err, title: feedErrorBannerTitle) {
                        loadFeedFromServer()
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, Theme.Spacing.xl)
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(L10n.string("No uploads yet"))
                        .font(Theme.Typography.title3)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text(L10n.string("Create a look from Lookbook — it will show up here."))
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, Theme.Spacing.xl)
            }
        }
    }

    private func loadFeedFromServer() {
        Task { await loadFeedFromServerAsync() }
    }

    private func loadFeedFromServerAsync() async {
        guard authService.isAuthenticated else {
            await MainActor.run {
                entries = []
                followedCommentBoostUsernames = []
                feedLoading = false
                feedError = nil
                feedErrorBannerTitle = nil
            }
            return
        }
        await MainActor.run { feedLoading = true; feedError = nil; feedErrorBannerTitle = nil }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        service.setAuthToken(authService.authToken)
        do {
            let clientFollowing = GraphQLClient()
            clientFollowing.setAuthToken(authService.authToken)
            async let postsTask = service.fetchLookbooks()
            async let followedTask = lookbookLoadFollowedUsernamesForFeedComments(authService: authService, graphQLClient: clientFollowing)
            let posts = try await postsTask
            let followedSet = await followedTask
            let localRecords = LookbookFeedStore.load()
            await MainActor.run {
                followedCommentBoostUsernames = followedSet
                entries = lookbookShuffledEntriesFromPosts(posts, localRecords: localRecords)
                feedLoading = false
                feedError = nil
                feedErrorBannerTitle = nil
            }
        } catch {
            await MainActor.run {
                feedLoading = false
                let cancelled = (error as? URLError)?.code == .cancelled
                feedError = cancelled ? nil : L10n.userFacingError(error)
                feedErrorBannerTitle = cancelled ? nil : L10n.userFacingErrorBannerTitle(error)
            }
        }
    }

    private func lookbookFeedRow(model: LookbookFeedRowModel, immersive: Bool = false) -> some View {
        LookbookFeedRowView(
            entry: model.entry,
            followedCommentBoostUsernames: followedCommentBoostUsernames,
            onCommentsTap: { commentsEntry = $0 },
            onProductTap: { productId in selectedProductId = ProductIdNavigator(id: productId) },
            onPostDeleted: { deleted in
                entries.removeAll { $0.lookbookPostKey == deleted.lookbookPostKey }
            },
            onOpenAnalytics: { analyticsEntry = $0 },
            onLikeTap: { tapped in
                handleLookbookFeedLikeTap(tapped, authService: authService, entries: $entries)
            },
            onPostCaptionUpdated: { updated in
                let k = updated.lookbookPostKey
                if let idx = entries.firstIndex(where: { $0.lookbookPostKey == k }) {
                    entries[idx] = updated
                }
            },
            immersive: immersive
        )
        .padding(.bottom, immersive ? 0 : lookbookSpacing)
    }
}

// MARK: - Topic / style lookbook feed (pushed from thumbnails)

private struct LookbookTopicFeedView: View {
    @EnvironmentObject private var authService: AuthService
    let screenTitle: String
    let styleFilter: Set<String>

    @State private var entries: [LookbookEntry] = []
    @State private var followedCommentBoostUsernames: Set<String> = []
    @State private var feedLoading = false
    @State private var feedError: String?
    @State private var feedErrorBannerTitle: String?
    @State private var commentsEntry: LookbookEntry?
    @State private var selectedProductId: ProductIdNavigator?
    @State private var analyticsEntry: LookbookEntry?
    private let productService = ProductService()

    private var filteredEntries: [LookbookEntry] {
        if styleFilter.isEmpty { return entries }
        return entries.filter { entry in
            !Set(entry.styles).isDisjoint(with: styleFilter)
        }
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            Group {
                if feedLoading && entries.isEmpty {
                    LookbookShimmerView()
                } else if entries.isEmpty {
                    topicEmptyPlaceholder(allLoadedEmpty: true)
                } else if filteredEntries.isEmpty {
                    topicEmptyPlaceholder(allLoadedEmpty: false)
                } else {
                    ScrollView {
                        LookbookScrollImmediateTouchesAnchor()
                            .frame(width: 0, height: 0)
                        LazyVStack(spacing: 0) {
                            ForEach(buildLookbookFeedRows(from: filteredEntries)) { row in
                                topicFeedRow(model: row)
                            }
                        }
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Theme.Colors.background)
                }
            }
        }
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $commentsEntry) { entry in
            LookbookCommentsSheet(entry: entry) { newCount in
                let key = entry.apiPostId.lowercased()
                if let idx = entries.firstIndex(where: { $0.apiPostId.lowercased() == key }) {
                    var updated = entries[idx]
                    updated.commentsCount = newCount
                    entries[idx] = updated
                }
            }
            .lookbookCommentsPresentationChrome()
        }
        .navigationDestination(item: $selectedProductId) { nav in
            LookbookProductDetailLoader(productId: nav.id, productService: productService, authService: authService)
        }
        .navigationDestination(item: $analyticsEntry) { entry in
            LookbookAnalyticsView(entry: entry)
                .environmentObject(authService)
        }
        .onAppear { loadFeedFromServer() }
        .refreshable { await loadFeedFromServerAsync() }
    }

    private func topicEmptyPlaceholder(allLoadedEmpty: Bool) -> some View {
        Group {
            if let err = feedError, !err.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    FeedNetworkBannerView(message: err, title: feedErrorBannerTitle) {
                        loadFeedFromServer()
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, Theme.Spacing.xl)
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.secondaryText)
                    if allLoadedEmpty {
                        Text("No lookbooks yet")
                            .font(Theme.Typography.title3)
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("Upload from the menu to add your first look.")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)
                    } else {
                        Text("No lookbooks here yet")
                            .font(Theme.Typography.title3)
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("Nothing matches this topic right now. Check back soon.")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xl)
            }
        }
    }

    private func topicFeedRow(model: LookbookFeedRowModel) -> some View {
        LookbookFeedRowView(
            entry: model.entry,
            followedCommentBoostUsernames: followedCommentBoostUsernames,
            onCommentsTap: { commentsEntry = $0 },
            onProductTap: { productId in selectedProductId = ProductIdNavigator(id: productId) },
            onPostDeleted: { deleted in
                entries.removeAll { $0.lookbookPostKey == deleted.lookbookPostKey }
            },
            onOpenAnalytics: { analyticsEntry = $0 },
            onLikeTap: { tapped in
                handleLookbookFeedLikeTap(tapped, authService: authService, entries: $entries)
            },
            onPostCaptionUpdated: { updated in
                let k = updated.lookbookPostKey
                if let idx = entries.firstIndex(where: { $0.lookbookPostKey == k }) {
                    entries[idx] = updated
                }
            }
        )
        .padding(.bottom, lookbookSpacing)
    }

    private func loadFeedFromServer() {
        Task { await loadFeedFromServerAsync() }
    }

    private func loadFeedFromServerAsync() async {
        guard authService.isAuthenticated else {
            await MainActor.run {
                entries = []
                followedCommentBoostUsernames = []
                feedLoading = false
                feedError = nil
                feedErrorBannerTitle = nil
            }
            return
        }
        await MainActor.run { feedLoading = true; feedError = nil; feedErrorBannerTitle = nil }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        service.setAuthToken(authService.authToken)
        do {
            let clientFollowing = GraphQLClient()
            clientFollowing.setAuthToken(authService.authToken)
            async let postsTask = service.fetchLookbooks()
            async let followedTask = lookbookLoadFollowedUsernamesForFeedComments(authService: authService, graphQLClient: clientFollowing)
            let posts = try await postsTask
            let followedSet = await followedTask
            let localRecords = LookbookFeedStore.load()
            await MainActor.run {
                followedCommentBoostUsernames = followedSet
                entries = lookbookShuffledEntriesFromPosts(posts, localRecords: localRecords)
                feedLoading = false
                feedError = nil
                feedErrorBannerTitle = nil
            }
        } catch {
            await MainActor.run {
                feedLoading = false
                let isCancelled = (error as? CancellationError) != nil
                    || (error as? URLError)?.code == .cancelled
                    || error.localizedDescription.lowercased().contains("cancelled")
                feedError = isCancelled ? nil : L10n.userFacingError(error)
                feedErrorBannerTitle = isCancelled ? nil : L10n.userFacingErrorBannerTitle(error)
            }
        }
    }
}

// MARK: - Lookbooks header & discovery rows (bundled `LookbookFeed` assets)

private struct LookbookBundledPortraitTile: View {
    let resourceName: String
    let width: CGFloat
    var cornerRadius: CGFloat = 10

    private var tileHeight: CGFloat {
        width / LookbookCanonicalAspect.portrait1080x1350.rawValue
    }

    var body: some View {
        Group {
            if let ui = LookbookFeedAssets.uiImage(named: resourceName) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Theme.Colors.secondaryBackground
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
            }
        }
        .frame(width: width, height: tileHeight)
        .clipped()
        .modifier(LookbookTileCornerClip(radius: cornerRadius))
    }
}

/// Square corners by default (IG-style); optional radius for rare cases.
private struct LookbookTileCornerClip: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        if radius <= 0 {
            content
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

/// Discover-style portrait tile: image + dim overlay + title on top (same stacking as `DiscoverView` banners).
private struct LookbookHorizontalPortraitTile: View {
    let card: LookbookHorizontalCard
    let width: CGFloat

    private var tileHeight: CGFloat {
        width / LookbookCanonicalAspect.portrait1080x1350.rawValue
    }

    var body: some View {
        ZStack {
            Group {
                if let ui = LookbookFeedAssets.uiImage(named: card.resourceName) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Theme.Colors.secondaryBackground
                }
            }
            .frame(width: width, height: tileHeight)
            .clipped()

            Color.black.opacity(0.45)
                .frame(width: width, height: tileHeight)

            Text(card.overlayTitle)
                .font(Theme.Typography.title3)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(2)
                .padding(Theme.Spacing.sm)
        }
        .frame(width: width, height: tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct LookbookStyleThumbnailStrip: View {
    private let thumbWidth: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(L10n.string("Explore by style"))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                Text(L10n.string("Tap a look to open posts tagged with that vibe."))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: lookbookThumbInterItem) {
                    ForEach(Array(lookbookStylePillValues.enumerated()), id: \.offset) { index, raw in
                        let resource = LookbookFeedAssets.styleThumbnailResource(styleIndex: index)
                        let label = StyleSelectionView.displayName(for: raw)
                        NavigationLink {
                            LookbookTopicFeedView(
                                screenTitle: label,
                                styleFilter: [raw]
                            )
                        } label: {
                            VStack(spacing: Theme.Spacing.sm) {
                                LookbookBundledPortraitTile(resourceName: resource, width: thumbWidth, cornerRadius: 10)
                                Text(label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.85)
                                    .frame(width: thumbWidth)
                            }
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Theme.Colors.glassBorder.opacity(0.4), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .padding(.bottom, Theme.Spacing.lg)
        .background(Theme.Colors.background)
    }
}

private struct LookbookHorizontalPortraitSection: View {
    let title: String
    var subtitle: String? = nil
    var showSeeAll: Bool = false
    var onSeeAll: (() -> Void)?
    let cards: [LookbookHorizontalCard]
    /// Visible thumbnails across the content width (e.g. 2.8 shows two full + a peek of the third).
    let visibleThumbCount: CGFloat
    let containerWidth: CGFloat

    /// Wider gutter between editorial cards so tiles never read as one strip.
    private var exploreCardGap: CGFloat { Theme.Spacing.md }

    private var contentWidth: CGFloat {
        containerWidth - Theme.Spacing.md * 2
    }

    private var thumbWidth: CGFloat {
        let gap = exploreCardGap
        if visibleThumbCount <= 2.01 {
            return (contentWidth - gap) / visibleThumbCount
        }
        let fullGaps = 2
        return (contentWidth - CGFloat(fullGaps) * gap) / visibleThumbCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer(minLength: Theme.Spacing.sm)
                    if showSeeAll {
                        Button {
                            onSeeAll?()
                        } label: {
                            Text(L10n.string("See all"))
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.primaryColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: exploreCardGap) {
                    ForEach(cards) { card in
                        NavigationLink {
                            LookbookTopicFeedView(screenTitle: card.overlayTitle, styleFilter: card.styleFilter)
                        } label: {
                            LookbookHorizontalPortraitTile(card: card, width: thumbWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.lg)
    }
}

/// Full-bleed dimmed overlay so the feed stays visible; image scales in with a light spring.
struct LookbookTransparentFullscreenOverlay: View {
    let entry: LookbookEntry
    var onDismiss: () -> Void

    @State private var index: Int = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                TabView(selection: $index) {
                    ForEach(Array(entry.imageUrls.enumerated()), id: \.offset) { idx, url in
                        LookbookFullscreenImage(
                            documentImagePath: idx == 0 ? entry.documentImagePath : nil,
                            imageName: entry.imageNames.first ?? "",
                            imageUrl: url
                        )
                        .tag(idx)
                    }
                    if entry.imageUrls.isEmpty {
                        LookbookFullscreenImage(
                            documentImagePath: entry.documentImagePath,
                            imageName: entry.imageNames.first ?? "",
                            imageUrl: nil
                        )
                        .tag(0)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: entry.imageUrls.count > 1 ? .automatic : .never))
                .frame(maxHeight: UIScreen.main.bounds.height * 0.78)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .padding(.trailing, 14)
                }
                Spacer()
            }
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Share sheet (lookbook post menu)
private struct LookbookSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct LookbookActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Loading shimmer for Lookbooks feed (pills + post card placeholders)
private struct LookbookShimmerView: View {
    var body: some View {
        VStack(spacing: 0) {
            stylePillsShimmer
            ForEach(0..<3, id: \.self) { _ in
                LookbookPostCardShimmer()
            }
        }
        .padding(.bottom, Theme.Spacing.xl)
        .shimmering()
    }

    private var stylePillsShimmer: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.Glass.tagCornerRadius)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 72, height: 36)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.background)
    }
}

/// Shimmer for feed-only screens (no style-pill strip).
private struct LookbookFeedOnlyShimmerView: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                LookbookPostCardShimmer()
            }
        }
        .padding(.bottom, Theme.Spacing.xl)
        .shimmering()
    }
}

/// Full-screen placeholder matching `LazyVGrid` lookbook layout: 3 columns, `LookbookThreeColumnGrid.gutter`, 2pt outer padding, 1pt cell inset, white gutters, square tiles.
private struct LookbookGridShimmerView: View {
    /// Enough rows to scroll on tall phones (~7 rows).
    private let placeholderCount = 21
    var bottomBarPadding: CGFloat = 0

    var body: some View {
        ScrollView {
            LazyVGrid(columns: LookbookThreeColumnGrid.columns, spacing: LookbookThreeColumnGrid.gutter) {
                ForEach(0..<placeholderCount, id: \.self) { _ in
                    LookbookGridShimmerTile()
                        .padding(1)
                        .background(Theme.Colors.background)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(2)
            .padding(.bottom, bottomBarPadding)
            .shimmering()
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LookbookGridShimmerTile: View {
    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Rectangle()
                    .fill(Theme.Colors.secondaryBackground)
            }
    }
}

private struct LookbookPostCardShimmer: View {
    private let mediaAspect: CGFloat = lookbookFeedAsyncImagePlaceholderAspect
    private let avatarSize: CGFloat = 40
    /// Matches trailing `…` menu in `LookbookFeedRowView` (44×44 content shape).
    private let menuPlaceholderSide: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: avatarSize, height: avatarSize)
                VStack(alignment: .leading, spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 120, height: 15)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 88, height: 12)
                }
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: menuPlaceholderSide, height: menuPlaceholderSide)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)

            // Full-bleed portrait slot (same layout trick as `mediaBlock` / `Color.clear` + aspect in feed rows — avoids a centred “floating” tile in `LazyVStack`).
            Color.clear
                .aspectRatio(mediaAspect, contentMode: .fit)
                .overlay {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Theme.Colors.secondaryBackground)
                }
                .frame(maxWidth: .infinity)
                .clipped()

            // `LookbookFeedPostActionBar`: like + count, comment icon, send (44), spacer, bookmark (44).
            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: max(4, (Theme.Spacing.md * 3 / 10).rounded())) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 56, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 48, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 20, height: 20)
                }
                .frame(minHeight: 44, alignment: .center)
                Spacer(minLength: Theme.Spacing.sm)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 20, height: 20)
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 6)
            .background(Theme.Colors.background)

            Rectangle()
                .fill(Theme.Colors.glassBorder.opacity(0.35))
                .frame(height: 0.5)
                .padding(.leading, Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .padding(.bottom, lookbookSpacing)
    }
}

// MARK: - Carousel page dots (below media, outside the image)
/// Maps scroll index to one of five slots when `total > 4` (ends are smaller dots).
private enum LookbookCarouselDotMapper {
    static func activeSlot(pageIndex: Int, total: Int) -> Int {
        precondition(total > 4)
        if pageIndex <= 0 { return 0 }
        if pageIndex == 1 { return 1 }
        if pageIndex >= total - 1 { return 4 }
        if pageIndex == total - 2 { return 3 }
        return 2
    }
}

private struct LookbookCarouselPageDots: View {
    let pageIndex: Int
    let totalPages: Int

    private let dotNormal: CGFloat = 6
    private let dotEnd: CGFloat = 4

    private var clampedIndex: Int {
        min(max(pageIndex, 0), max(0, totalPages - 1))
    }

    var body: some View {
        Group {
            if totalPages > 1 {
                HStack(spacing: 6) {
                    if totalPages <= 4 {
                        ForEach(0 ..< totalPages, id: \.self) { i in
                            dotCircle(active: i == clampedIndex, diameter: dotNormal)
                        }
                    } else {
                        ForEach(0 ..< 5, id: \.self) { slot in
                            let active = LookbookCarouselDotMapper.activeSlot(pageIndex: clampedIndex, total: totalPages) == slot
                            let d = (slot == 0 || slot == 4) ? dotEnd : dotNormal
                            dotCircle(active: active, diameter: d)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Image \(clampedIndex + 1) of \(totalPages)")
            }
        }
    }

    private func dotCircle(active: Bool, diameter: CGFloat) -> some View {
        Circle()
            .fill(active ? Theme.primaryColor : Theme.Colors.secondaryText.opacity(0.35))
            .frame(width: diameter, height: diameter)
    }
}

// MARK: - Feed post action bar (like, comment, send, optional remove-from-folder, save)
struct LookbookFeedPostActionBar: View {
    let entry: LookbookEntry
    let currentDisplayImageURL: String?
    let isBookmarked: Bool
    /// When true, heart stays tappable but the numeric like count is hidden (per-post or global lookbook setting).
    var hideLikeCount: Bool = false
    let onLikeTap: () -> Void
    let onCommentsTap: () -> Void
    let onSendTap: () -> Void
    /// When set (e.g. saved-folder feed), shown as the 4th control after send, before the trailing bookmark.
    var onRemoveFromFolderTap: (() -> Void)? = nil
    let onBookmarkTap: () -> Void

    private let actionIconSize: CGFloat = 20
    /// Tighter cluster: ~70% less than `Theme.Spacing.md` between like / comment / send.
    private var actionClusterSpacing: CGFloat {
        max(4, (Theme.Spacing.md * 3 / 10).rounded())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: actionClusterSpacing) {
                LikeButtonView(
                    isLiked: entry.isLiked,
                    likeCount: entry.likesCount,
                    action: onLikeTap,
                    onDarkOverlay: false,
                    heartPointSize: 20,
                    likeCountFormatting: LookbookFeedEngagementCountFormatting.short,
                    showLikeCount: !hideLikeCount
                )
                .padding(.leading, -Theme.Spacing.sm)

                Button {
                    HapticManager.tap()
                    onCommentsTap()
                } label: {
                    Image(systemName: "bubble.right")
                        .font(.system(size: actionIconSize, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainTappableButtonStyle())
                .accessibilityLabel(LookbookFeedEngagementCountFormatting.fullCommentCountPhrase(entry.commentsCount))
                .accessibilityHint(L10n.string("Opens comments"))

                Button {
                    HapticManager.tap()
                    onSendTap()
                } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: actionIconSize, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainTappableButtonStyle())

                if let removeFromFolder = onRemoveFromFolderTap {
                    Button {
                        HapticManager.tap()
                        removeFromFolder()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: actionIconSize, weight: .medium))
                            .foregroundStyle(Theme.Colors.primaryText)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainTappableButtonStyle())
                    .accessibilityLabel(L10n.string("Remove from folder"))
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button {
                HapticManager.tap()
                onBookmarkTap()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: actionIconSize, weight: .medium))
                    .foregroundStyle(isBookmarked ? Theme.primaryColor : Theme.Colors.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainTappableButtonStyle())
            .accessibilityLabel(isBookmarked ? L10n.string("Saved") : L10n.string("Save"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, 0)
        .padding(.bottom, 0)
        .background(Theme.Colors.background)
    }
}

/// Remote lookbook image with tap-to-retry on failure (AsyncImage does not reload unless view identity changes).
private struct LookbookFeedRowRemoteImage: View {
    let url: URL
    /// When nil, the loaded image is not tappable (feed rows: no fullscreen).
    var onSuccessTap: (() -> Void)? = nil

    @State private var reloadNonce = 0
    /// AsyncImage often reports `.failure` when a load is cancelled during `LazyVStack` scroll; auto-retry a few times before asking the user to tap.
    @State private var failureAutoRetryCount = 0
    /// Incremented only when `.success` is shown; delayed retries must not bump `reloadNonce` after a successful load (that was causing infinite reload / perpetual spinner).
    @State private var successGeneration = 0

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                Group {
                    if let tap = onSuccessTap {
                        image
                            .resizable()
                            .scaledToFit()
                            .contentShape(Rectangle())
                            .onTapGesture { tap() }
                    } else {
                        image
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(maxWidth: .infinity)
                .onAppear {
                    failureAutoRetryCount = 0
                    successGeneration += 1
                }
            case .failure:
                reloadPrompt
                    .frame(maxWidth: .infinity)
                    .aspectRatio(lookbookFeedAsyncImagePlaceholderAspect, contentMode: .fit)
                    .onAppear { scheduleFailureAutoRetry() }
            case .empty:
                ZStack {
                    Theme.Colors.secondaryBackground
                    ProgressView()
                        .scaleEffect(0.85)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(lookbookFeedAsyncImagePlaceholderAspect, contentMode: .fit)
                .task {
                    let genWhenEmptyBegan = successGeneration
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    await MainActor.run {
                        guard genWhenEmptyBegan == successGeneration else { return }
                        reloadNonce += 1
                    }
                }
            @unknown default:
                reloadPrompt
                    .frame(maxWidth: .infinity)
                    .aspectRatio(lookbookFeedAsyncImagePlaceholderAspect, contentMode: .fit)
                    .onAppear { scheduleFailureAutoRetry() }
            }
        }
        .id("\(url.absoluteString)-\(reloadNonce)")
        .onChange(of: url) { _, _ in
            failureAutoRetryCount = 0
            successGeneration = 0
        }
    }

    private func scheduleFailureAutoRetry() {
        guard failureAutoRetryCount < 4 else { return }
        failureAutoRetryCount += 1
        let step = failureAutoRetryCount
        let genWhenScheduled = successGeneration
        let delayNs: UInt64 = 380_000_000 + UInt64(step) * 140_000_000
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNs)
            guard genWhenScheduled == successGeneration else { return }
            reloadNonce += 1
        }
    }

    private var reloadPrompt: some View {
        Button {
            HapticManager.tap()
            failureAutoRetryCount = 0
            reloadNonce += 1
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Text(L10n.string("Could not load image"))
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                Text(L10n.string("Tap to reload"))
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.primaryColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.lg)
            .padding(.horizontal, Theme.Spacing.sm)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("Could not load image"))
        .accessibilityHint(L10n.string("Tap to reload"))
    }
}

// MARK: - Lookbook feed caption (chunks + 2-line trim without tail ellipsis)

fileprivate enum LookbookCaptionBodyChunk {
    case plain(String)
    case tag(String)
}

fileprivate func lookbookFeedCaptionBodyChunks(_ caption: String) -> [LookbookCaptionBodyChunk] {
    var chunks: [LookbookCaptionBodyChunk] = []
    var i = caption.startIndex
    while i < caption.endIndex {
        if caption[i] == "#" {
            let start = i
            i = caption.index(after: i)
            while i < caption.endIndex, !caption[i].isWhitespace, caption[i] != "#" {
                i = caption.index(after: i)
            }
            chunks.append(.tag(String(caption[start..<i])))
        } else {
            let start = i
            while i < caption.endIndex, caption[i] != "#" {
                i = caption.index(after: i)
            }
            let plain = String(caption[start..<i])
            if !plain.isEmpty { chunks.append(.plain(plain)) }
        }
    }
    return chunks
}

/// Matches `Theme.primaryColor` (#AB28B2).
fileprivate let lookbookFeedCaptionHashtagUIColor = UIColor(red: 171 / 255, green: 40 / 255, blue: 178 / 255, alpha: 1)

fileprivate func lookbookFeedCaptionParagraphStyle() -> NSParagraphStyle {
    let p = NSMutableParagraphStyle()
    // Slight extra line metrics so emoji aren’t clipped by tight UILabel/Text layout (cap ≤ ~3pt effective slack).
    p.lineSpacing = 3
    return p
}

fileprivate func lookbookFeedFullCaptionMutableAttributed(username: String, captionBody: String) -> NSMutableAttributedString {
    let m = NSMutableAttributedString()
    let bold = UIFont.systemFont(ofSize: 15, weight: .bold)
    let reg = UIFont.systemFont(ofSize: 15, weight: .regular)
    let primary = UIColor.label
    m.append(NSAttributedString(string: username, attributes: [.font: bold, .foregroundColor: primary]))
    m.append(NSAttributedString(string: "  ", attributes: [.font: reg, .foregroundColor: primary]))
    for chunk in lookbookFeedCaptionBodyChunks(captionBody) {
        switch chunk {
        case .plain(let s):
            m.append(NSAttributedString(string: s, attributes: [.font: reg, .foregroundColor: primary]))
        case .tag(let s):
            m.append(NSAttributedString(string: s, attributes: [.font: reg, .foregroundColor: lookbookFeedCaptionHashtagUIColor]))
        }
    }
    let para = lookbookFeedCaptionParagraphStyle()
    m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
    return m
}

/// Trailing space for the grey fold control: intrinsic width at caption font size + ~8pt gap so body text does not touch “...more”.
fileprivate func lookbookFeedCaptionFoldControlTrailingReserve() -> CGFloat {
    let font = UIFont.systemFont(ofSize: 15, weight: .regular)
    let gap: CGFloat = 8
    let wMore = ceil((L10n.string("...more") as NSString).size(withAttributes: [.font: font]).width)
    let wLess = ceil((L10n.string("...less") as NSString).size(withAttributes: [.font: font]).width)
    return max(wMore, wLess) + gap
}

fileprivate func lookbookFeedCaptionBoundingHeight(_ attr: NSAttributedString, width: CGFloat) -> CGFloat {
    guard width > 0, attr.length > 0 else { return 0 }
    let rect = attr.boundingRect(
        with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        context: nil
    )
    return ceil(rect.height)
}

/// True when the full caption lays out as a **single** line at `width` (same fonts / paragraph as feed caption). Short captions then skip “...more”.
fileprivate func lookbookFeedCaptionFitsSingleLine(full: NSAttributedString, width: CGFloat) -> Bool {
    guard width > 1, full.length > 0 else { return false }
    let reg = UIFont.systemFont(ofSize: 15, weight: .regular)
    let oneLineProbe = NSMutableAttributedString(string: "Hg", attributes: [.font: reg])
    let capPara = lookbookFeedCaptionParagraphStyle()
    oneLineProbe.addAttribute(.paragraphStyle, value: capPara, range: NSRange(location: 0, length: oneLineProbe.length))
    let oneLineH = lookbookFeedCaptionBoundingHeight(oneLineProbe, width: width)
    let fullH = lookbookFeedCaptionBoundingHeight(full, width: width)
    return fullH <= oneLineH + 1
}

/// Two-line cap for collapsed feed caption: **full width**, **no** Unicode "…" tail (the separate "...more" control covers overflow).
fileprivate func lookbookFeedTrimCaptionAttributed(username: String, captionBody: String, width: CGFloat, maxLines: Int) -> NSAttributedString {
    let full = lookbookFeedFullCaptionMutableAttributed(username: username, captionBody: captionBody)
    let len = full.length
    guard width > 1, len > 0, maxLines > 0 else { return full }

    let reg = UIFont.systemFont(ofSize: 15, weight: .regular)
    let cal = NSMutableAttributedString()
    for lineIdx in 0..<maxLines {
        if lineIdx > 0 {
            cal.append(NSAttributedString(string: "\n", attributes: [.font: reg]))
        }
        cal.append(NSAttributedString(string: "Hg", attributes: [.font: reg]))
    }
    let capPara = lookbookFeedCaptionParagraphStyle()
    cal.addAttribute(.paragraphStyle, value: capPara, range: NSRange(location: 0, length: cal.length))
    let maxH = lookbookFeedCaptionBoundingHeight(cal, width: width)

    func height(upTo utf16Count: Int) -> CGFloat {
        let n = max(0, min(utf16Count, len))
        guard n > 0 else { return 0 }
        let sub = full.attributedSubstring(from: NSRange(location: 0, length: n))
        return lookbookFeedCaptionBoundingHeight(sub, width: width)
    }

    if height(upTo: len) <= maxH { return full }

    var lo = 0
    var hi = len
    while lo < hi {
        let mid = (lo + hi + 1) / 2
        if height(upTo: mid) <= maxH {
            lo = mid
        } else {
            hi = mid - 1
        }
    }

    var end = lo
    if end < len, end > 0 {
        let ns = full.string as NSString
        var i = end
        let floor = max(0, end - 72)
        while i > floor {
            let ch = ns.character(at: i - 1)
            if ch == 32 || ch == 10 || ch == 13 || ch == 9 || ch == 0x2028 || ch == 0x2029 {
                end = i
                break
            }
            i -= 1
        }
    }

    return full.attributedSubstring(from: NSRange(location: 0, length: end))
}

private final class LookbookFeedCaptionSizingLabel: UILabel {
    // UILabel used with preferredMaxLayoutWidth + sizeThatFits from the representable.
}

/// Collapsed, “read more” caption: measures at proposed width and trims to two lines without an ellipsis run.
private struct LookbookFeedCollapsedCaptionLabel: UIViewRepresentable {
    var username: String
    var captionBody: String
    /// When > 0, text wraps and trims to this width (e.g. row width minus fold control reserve). When0, uses the proposed width from SwiftUI.
    var trimLayoutWidth: CGFloat

    func makeUIView(context: Context) -> LookbookFeedCaptionSizingLabel {
        let l = LookbookFeedCaptionSizingLabel()
        l.numberOfLines = 0
        l.lineBreakMode = .byWordWrapping
        l.setContentCompressionResistancePriority(.required, for: .vertical)
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return l
    }

    func updateUIView(_ uiView: LookbookFeedCaptionSizingLabel, context: Context) {
        let layoutW = trimLayoutWidth > 0 ? trimLayoutWidth : uiView.preferredMaxLayoutWidth
        guard layoutW > 0 else { return }
        uiView.preferredMaxLayoutWidth = layoutW
        uiView.attributedText = lookbookFeedTrimCaptionAttributed(
            username: username,
            captionBody: captionBody,
            width: layoutW,
            maxLines: 2
        )
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LookbookFeedCaptionSizingLabel, context: Context) -> CGSize? {
        let rowW = max(1, proposal.width ?? UIView.layoutFittingExpandedSize.width)
        let layoutW = trimLayoutWidth > 0 ? trimLayoutWidth : rowW
        uiView.preferredMaxLayoutWidth = layoutW
        let t = lookbookFeedTrimCaptionAttributed(username: username, captionBody: captionBody, width: layoutW, maxLines: 2)
        uiView.attributedText = t
        let h = uiView.sizeThatFits(CGSize(width: layoutW, height: UIView.layoutFittingExpandedSize.height)).height
        return CGSize(width: rowW, height: max(1, h))
    }
}

fileprivate struct LookbookFeedCaptionLineWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Feed row (full-width media: natural aspect, no crop; like / comment / send, save trailing)
struct LookbookFeedRowView: View {
    let entry: LookbookEntry
    /// Lowercased usernames; when a comment author is in this set, that comment is preferred for the one-line preview.
    let followedCommentBoostUsernames: Set<String>
    let onCommentsTap: (LookbookEntry) -> Void
    let onProductTap: (String) -> Void
    let onPostDeleted: ((LookbookEntry) -> Void)?
    let onOpenAnalytics: ((LookbookEntry) -> Void)?
    let onLikeTap: (LookbookEntry) -> Void
    /// Remove from the current saved folder only (does not delete the post on the server).
    var onRemoveFromFolder: (() -> Void)? = nil
    /// When set, owner can edit caption; receives merged entry after a successful save.
    var onPostCaptionUpdated: ((LookbookEntry) -> Void)? = nil
    /// Fullscreen grid → pager: suppress avatar `AsyncImage` cross-fade and disambiguate view identity.
    var immersive: Bool = false

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var savedLookbookFavorites: SavedLookbookFavoritesStore
    @EnvironmentObject private var hideLikeCountsStore: LookbookHideLikeCountsStore
    /// Horizontal page for multi-image posts (paged `ScrollView`, not `TabView` — TabView steals taps on the row below).
    @State private var carouselScrollId: Int? = 0
    @State private var sharePayload: LookbookSharePayload?
    @State private var showMutualShareSheet = false
    @State private var shareToChatRecipient: User?
    @State private var showDeletePostConfirm = false
    @State private var deletePostErrorMessage: String?
    @State private var latestCommentPreview: ServerLookbookComment?
    @State private var showSaveFolderSheet = false
    @State private var saveFeedbackToast: String?
    /// Tagged-product pins + thumbnails (upload screen parity); hidden until user taps the grid affordance.
    @State private var revealTaggedProductsOnImage = false
    @State private var showEditPostSheet = false
    @State private var lookbookCaptionExpanded = false
    @State private var lookbookCaptionLineWidth: CGFloat = 0

    private let avatarSize: CGFloat = 40
    private let commentPreviewAvatarSize: CGFloat = 28
    /// Carousel pages share one height so horizontal paging stays aligned (portrait-leaning ratio).
    private let carouselSlotAspect: CGFloat = lookbookFeedAsyncImagePlaceholderAspect

    private func lookbookCommentPreviewAccessibilityLabel(comment c: ServerLookbookComment) -> String {
        let prefix = entry.commentsCount > 0 ? "\(LookbookFeedEngagementCountFormatting.fullCommentCountPhrase(entry.commentsCount)). " : ""
        return "\(prefix)\(c.username): \(c.text)"
    }

    private var lookbookShareURLString: String? {
        let raw = entry.apiPostId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let base = Constants.publicWebItemLinkBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(base)/lookbook/\(raw)"
    }

    private var forwardMessageText: String {
        var parts: [String] = []
        if let c = entry.caption, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(c)
        }
        if let link = lookbookShareURLString, !link.isEmpty {
            parts.append(link)
        } else if let u = entry.imageUrls.first, !u.isEmpty {
            parts.append(u)
        }
        parts.append("@\(entry.posterUsername) on WEARHOUSE")
        return parts.joined(separator: "\n\n")
    }

    /// Structured chat payload so the thread can show a thumbnail + tappable universal link (plain text URLs are not linkified in `Text`).
    private var forwardMessageForChat: String {
        if let json = forwardMessagePayloadJSONString { return json }
        return forwardMessageText
    }

    private var forwardMessagePayloadJSONString: String? {
        guard let link = lookbookShareURLString, !link.isEmpty else { return nil }
        let imageURL = currentDisplayImageURL ?? entry.imageUrls.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let thumbFromEntry = entry.thumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        let thumb: String? = {
            if let t = thumbFromEntry, !t.isEmpty { return t }
            if let full = imageURL, !full.isEmpty, let derived = LookbookCDNThumbnailURL.urlString(forFullImageURL: full) { return derived }
            return nil
        }()
        var dict: [String: Any] = [
            "type": "lookbook_share",
            "url": link,
            "poster_username": entry.posterUsername
        ]
        if let t = thumb, !t.isEmpty { dict["thumbnail_url"] = t }
        if let i = imageURL, !i.isEmpty { dict["image_url"] = i }
        if let c = entry.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty { dict["caption"] = c }
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    private func styleSubtitle(for entry: LookbookEntry) -> String? {
        guard let first = entry.styles.first, !first.isEmpty else { return nil }
        return StyleSelectionView.displayName(for: first)
    }

    private var lookbookFeedPostTimeLabel: String {
        LookbookCommentTimeFormatting.shortRelative(iso: entry.createdAt)
    }

    @ViewBuilder
    private var lookbookFeedPostTimeRow: some View {
        if !lookbookFeedPostTimeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(lookbookFeedPostTimeLabel)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var carouselImageURLs: [String] {
        dedupeOrderedValidLookbookURLs(entry.imageUrls)
    }

    private func openSendForward() {
        guard authService.isAuthenticated else {
            sharePayload = LookbookSharePayload(items: shareItemsForEntry())
            return
        }
        showMutualShareSheet = true
    }

    private var isCurrentUserPost: Bool {
        guard let u = authService.username?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty else { return false }
        return u.caseInsensitiveCompare(entry.posterUsername.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    private var isHidingLikeCountForPost: Bool {
        hideLikeCountsStore.hidesLikeCount(forPostKey: entry.lookbookPostKey)
    }

    private func performDeletePost() {
        Task { @MainActor in
            guard authService.isAuthenticated, onPostDeleted != nil else { return }
            let token = authService.authToken
            let client = GraphQLClient()
            client.setAuthToken(token)
            let service = LookbookService(client: client)
            service.setAuthToken(token)
            do {
                try await service.deleteLookbookPost(postId: entry.apiPostId)
                onPostDeleted?(entry)
            } catch {
                deletePostErrorMessage = L10n.userFacingError(error)
            }
        }
    }

    private var carouselPageIndex: Int {
        carouselScrollId ?? 0
    }

    private var currentDisplayImageURL: String? {
        let urls = carouselImageURLs
        guard !urls.isEmpty else { return nil }
        if urls.count > 1, urls.indices.contains(carouselPageIndex) {
            return urls[carouselPageIndex]
        }
        return urls.first
    }

    private var posterAvatar: some View {
        let trimmed = entry.posterProfilePictureUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Group {
            if let url = URL(string: trimmed), !trimmed.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure, .empty:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .id("lookbook-poster-avatar-\(entry.lookbookImmersiveScrollKey)")
        .transaction { txn in
            if immersive { txn.disablesAnimations = true }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Theme.Colors.secondaryBackground)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Colors.tertiaryText)
            )
    }

    private func refreshLatestCommentPreview() async {
        guard entry.commentsCount > 0 else {
            await MainActor.run { latestCommentPreview = nil }
            return
        }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        guard let list = try? await service.fetchComments(postId: entry.apiPostId), !list.isEmpty else {
            await MainActor.run { latestCommentPreview = nil }
            return
        }
        let pick = LookbookCommentTimeFormatting.prominentFeedPreviewComment(
            in: list,
            followedUsernamesLowercased: followedCommentBoostUsernames
        )
        await MainActor.run { latestCommentPreview = pick }
    }

    @ViewBuilder
    private var latestCommentPreviewSection: some View {
        if let c = latestCommentPreview {
            Button {
                HapticManager.tap()
                onCommentsTap(entry)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    if entry.commentsCount > 0 {
                        Text(LookbookFeedEngagementCountFormatting.fullCommentCountPhrase(entry.commentsCount))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.md)
                    }
                    HStack(alignment: .center, spacing: 8) {
                        LookbookCommentAvatar(profilePictureUrl: c.profilePictureUrl, username: c.username, size: commentPreviewAvatarSize)
                        (Text(c.username).fontWeight(.semibold) + Text(" ") + Text(c.text))
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Colors.primaryText)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(lookbookCommentPreviewAccessibilityLabel(comment: c)))
            .accessibilityHint(L10n.string("Opens comments"))
        }
    }

    private func shareItemsForEntry() -> [Any] {
        var items: [Any] = []
        if let link = lookbookShareURLString, let url = URL(string: link) {
            items.append(url)
        }
        if let u = entry.imageUrls.first, let url = URL(string: u) {
            items.append(url)
        }
        var textParts: [String] = []
        if let c = entry.caption, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textParts.append(c)
        }
        textParts.append("— @\(entry.posterUsername) on WEARHOUSE")
        items.append(textParts.joined(separator: "\n"))
        return items
    }

    var body: some View {
        let styleSub = styleSubtitle(for: entry)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: styleSub == nil ? .center : .top, spacing: Theme.Spacing.sm) {
                posterAvatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.posterUsername)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                    if let sub = styleSub {
                        Text(sub)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
                Spacer(minLength: 0)
                lookbookFeedPostOptionsMenu
                    .padding(.trailing, Theme.Spacing.sm - 2)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, 6)
            .padding(.bottom, 10)

            Rectangle()
                .fill(Theme.Colors.glassBorder.opacity(0.35))
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            lookbookSandboxMediaBlock
                .zIndex(0)
                .clipped()
                .clipShape(Rectangle())

            if carouselImageURLs.count > 1 {
                LookbookCarouselPageDots(pageIndex: carouselPageIndex, totalPages: carouselImageURLs.count)
            }

            LookbookFeedPostActionBar(
                entry: entry,
                currentDisplayImageURL: currentDisplayImageURL,
                isBookmarked: savedLookbookFavorites.isSaved(postId: entry.apiPostId),
                hideLikeCount: isHidingLikeCountForPost,
                onLikeTap: { onLikeTap(entry) },
                onCommentsTap: { onCommentsTap(entry) },
                onSendTap: { openSendForward() },
                onRemoveFromFolderTap: onRemoveFromFolder,
                onBookmarkTap: { showSaveFolderSheet = true }
            )
            .zIndex(20)

            if let cap = entry.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !cap.isEmpty {
                let sub = Theme.Typography.subheadline
                let fullAttr = lookbookFeedFullCaptionMutableAttributed(username: entry.posterUsername, captionBody: cap)
                let w = lookbookCaptionLineWidth
                let trimAttr = w > 0
                    ? lookbookFeedTrimCaptionAttributed(username: entry.posterUsername, captionBody: cap, width: w, maxLines: 2)
                    : fullAttr
                let overflowsTwoLines = w > 0
                    ? trimAttr.length < fullAttr.length
                    : Self.lookbookFeedCaptionLikelyExceedsTwoLines(cap)
                let fitsSingleLine = w > 0 && lookbookFeedCaptionFitsSingleLine(full: fullAttr, width: w)
                let showFoldControl = lookbookCaptionExpanded || (overflowsTwoLines && !fitsSingleLine)
                let foldReserve = (showFoldControl && !lookbookCaptionExpanded) ? lookbookFeedCaptionFoldControlTrailingReserve() : 0
                let collapsedTrimW: CGFloat = {
                    guard foldReserve > 0, w > foldReserve else { return 0 }
                    return w - foldReserve
                }()
                VStack(alignment: .leading, spacing: 4) {
                    ZStack(alignment: .bottomTrailing) {
                        if lookbookCaptionExpanded {
                            (
                                Text(entry.posterUsername)
                                    .font(sub)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Theme.Colors.primaryText)
                                    + Text("  ")
                                    .font(sub)
                                    .foregroundStyle(Theme.Colors.primaryText)
                                    + lookbookFeedStyledCaptionBodyText(cap)
                            )
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            LookbookFeedCollapsedCaptionLabel(
                                username: entry.posterUsername,
                                captionBody: cap,
                                trimLayoutWidth: collapsedTrimW
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if showFoldControl {
                            Button {
                                HapticManager.tap()
                                lookbookCaptionExpanded.toggle()
                            } label: {
                                Text(lookbookCaptionExpanded ? L10n.string("...less") : L10n.string("...more"))
                                    .font(sub)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                                    .padding(.top, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: LookbookFeedCaptionLineWidthKey.self, value: g.size.width)
                        }
                    )
                    .onPreferenceChange(LookbookFeedCaptionLineWidthKey.self) { lookbookCaptionLineWidth = $0 }
                    lookbookFeedPostTimeRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, 3)
                .padding(.bottom, 4)
            } else {
                lookbookFeedPostTimeRow
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, 3)
                    .padding(.bottom, 4)
            }

            latestCommentPreviewSection
        }
        .background(Theme.Colors.background)
        .overlay(alignment: .bottom) {
            if let msg = saveFeedbackToast {
                Text(msg)
                    .font(Theme.Typography.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50)
                    .task(id: msg) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        await MainActor.run { saveFeedbackToast = nil }
                    }
            }
        }
        .sheet(isPresented: $showSaveFolderSheet) {
            LookbookSaveToFolderSheet(entry: entry, imageUrl: currentDisplayImageURL) { addedFolderNames in
                guard !addedFolderNames.isEmpty else { return }
                let joined = addedFolderNames.joined(separator: ", ")
                saveFeedbackToast = String(format: L10n.string("Saved to %@"), joined)
            }
            .environmentObject(savedLookbookFavorites)
        }
        .sheet(item: $sharePayload) { payload in
            LookbookActivityView(activityItems: payload.items)
        }
        .sheet(isPresented: $showMutualShareSheet) {
            SendToUserShareSheet(excludeUsername: entry.posterUsername) { user in
                shareToChatRecipient = user
            }
            .environmentObject(authService)
        }
        .sheet(item: $shareToChatRecipient) { user in
            NavigationStack {
                ChatWithSellerView(
                    seller: user,
                    item: nil,
                    precomposedMessage: nil,
                    autoSendMessageOnReady: forwardMessageForChat,
                    authService: authService
                )
                .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showEditPostSheet) {
            NavigationStack {
                LookbooksUploadView(editingEntry: entry, onEditComplete: { updated in
                    onPostCaptionUpdated?(updated)
                })
                .environmentObject(authService)
            }
        }
        .task(id: "\(entry.lookbookPostKey)-\(entry.commentsCount)-\(lookbookFollowingSetFingerprint(followedCommentBoostUsernames))") {
            await refreshLatestCommentPreview()
        }
        .onChange(of: entry.id) { _, _ in
            carouselScrollId = 0
        }
        .onChange(of: entry.lookbookPostKey) { _, _ in
            revealTaggedProductsOnImage = false
        }
        .onChange(of: entry.caption ?? "") { _, _ in
            lookbookCaptionExpanded = false
        }
        .onChange(of: entry.imageUrls.count) { _, newCount in
            let idx = carouselPageIndex
            if newCount == 0 {
                carouselScrollId = nil
            } else if idx >= newCount {
                carouselScrollId = max(0, newCount - 1)
            }
        }
        .onChange(of: carouselPageIndex) { _, _ in
            revealTaggedProductsOnImage = false
        }
        .alert(L10n.string("Delete this post?"), isPresented: $showDeletePostConfirm) {
            Button(L10n.string("Cancel"), role: .cancel) {}
            Button(L10n.string("Delete"), role: .destructive) {
                performDeletePost()
            }
        } message: {
            Text(L10n.string("This cannot be undone."))
        }
        .alert(L10n.string("Error"), isPresented: Binding(
            get: { deletePostErrorMessage != nil },
            set: { if !$0 { deletePostErrorMessage = nil } }
        )) {
            Button(L10n.string("OK"), role: .cancel) { deletePostErrorMessage = nil }
        } message: {
            Text(deletePostErrorMessage ?? "")
        }
    }

    /// Heuristic: when true, collapsed caption shows a grey “...more” control (2-line cap).
    private static func lookbookFeedCaptionLikelyExceedsTwoLines(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        let lines = t.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count >= 2 { return true }
        return t.count > 88
    }

    /// Body text with `#hashtags` in primary accent; everything else in primary label color.
    private func lookbookFeedStyledCaptionBodyText(_ caption: String) -> Text {
        let font = Theme.Typography.subheadline
        return lookbookFeedCaptionBodyChunks(caption).reduce(Text("")) { acc, chunk in
            switch chunk {
            case .plain(let s):
                return acc + Text(s).font(font).foregroundStyle(Theme.Colors.primaryText)
            case .tag(let s):
                return acc + Text(s).font(font).foregroundStyle(Theme.primaryColor)
            }
        }
    }

    @ViewBuilder
    private var lookbookFeedPostOptionsMenu: some View {
        Menu {
            Button {
                HapticManager.tap()
                sharePayload = LookbookSharePayload(items: shareItemsForEntry())
            } label: {
                Label(L10n.string("Share"), systemImage: "square.and.arrow.up")
            }
            if let link = lookbookShareURLString, !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    HapticManager.tap()
                    UIPasteboard.general.string = link
                } label: {
                    Label(L10n.string("Copy link"), systemImage: "link")
                }
            }
            if isCurrentUserPost, onPostCaptionUpdated != nil {
                Button {
                    HapticManager.tap()
                    showEditPostSheet = true
                } label: {
                    Label(L10n.string("Edit post"), systemImage: "square.and.pencil")
                }
            }
            if isCurrentUserPost, let onOpenAnalytics {
                Button {
                    HapticManager.tap()
                    onOpenAnalytics(entry)
                } label: {
                    Label(L10n.string("Analytics"), systemImage: "chart.bar")
                }
            }
            if isCurrentUserPost {
                Button {
                    HapticManager.tap()
                    hideLikeCountsStore.setHideLikeCount(!isHidingLikeCountForPost, forPostKey: entry.lookbookPostKey)
                } label: {
                    Label(
                        isHidingLikeCountForPost ? L10n.string("Show likes") : L10n.string("Hide likes count"),
                        systemImage: isHidingLikeCountForPost ? "eye" : "eye.slash"
                    )
                }
            }
            if isCurrentUserPost, onPostDeleted != nil {
                Button(role: .destructive) {
                    HapticManager.tap()
                    showDeletePostConfirm = true
                } label: {
                    Label(L10n.string("Delete"), systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryText)
                .rotationEffect(.degrees(90))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .menuActionDismissBehavior(.automatic)
        .accessibilityLabel(L10n.string("More options"))
    }

    @ViewBuilder
    private var lookbookSandboxMediaBlock: some View {
        let urls = carouselImageURLs
        Group {
            if urls.isEmpty {
                lookbookSandboxSingleMedia(urlString: "", documentPath: entry.documentImagePath)
                    .overlay { lookbookFeedTaggedProductsOverlay() }
            } else if urls.count > 1 {
                Color.clear
                    .aspectRatio(carouselSlotAspect, contentMode: .fit)
                    .overlay {
                        GeometryReader { geo in
                            let w = max(1, geo.size.width)
                            let h = max(1, geo.size.height)
                            ZStack(alignment: .bottomTrailing) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 0) {
                                        LookbookScrollImmediateTouchesAnchor()
                                            .frame(width: 0, height: 0)
                                        ForEach(Array(urls.enumerated()), id: \.offset) { idx, urlString in
                                            lookbookSandboxSingleMedia(
                                                urlString: urlString,
                                                documentPath: idx == 0 ? entry.documentImagePath : nil,
                                                carouselPageWidth: w,
                                                carouselPageHeight: h
                                            )
                                            .frame(width: w, height: h)
                                            .clipped()
                                            .id(idx)
                                        }
                                    }
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.paging)
                                .scrollPosition(id: $carouselScrollId, anchor: .leading)
                                .frame(width: w, height: h)
                                .clipped()
                                lookbookFeedTaggedProductsChrome(width: w, height: h, slideIndex: carouselPageIndex)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(Rectangle())
            } else {
                lookbookSandboxSingleMedia(urlString: urls[0], documentPath: entry.documentImagePath)
                    .overlay { lookbookFeedTaggedProductsOverlay() }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Tag coordinates are normalized per carousel slide (`imageIndex`); `slideIndex` is zero-based.
    private func lookbookFeedProductTagPinItems(forSlideIndex slide: Int) -> [(tag: LookbookTagData, snapshot: LookbookProductSnapshot)] {
        guard let tags = entry.tags, !tags.isEmpty else { return [] }
        let snaps = entry.productSnapshots ?? [:]
        let slideTags = tags.filter { $0.imageIndex == slide }
        return slideTags.compactMap { t -> (LookbookTagData, LookbookProductSnapshot)? in
            let pid = t.productId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pid.isEmpty else { return nil }
            if let s = snaps[pid] { return (t, s) }
            if let s = snaps.first(where: { $0.key.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(pid) == .orderedSame })?.value {
                return (t, s)
            }
            let placeholder = LookbookProductSnapshot(productId: pid, title: "\u{00A0}", imageUrl: nil)
            return (t, placeholder)
        }
    }

    private func lookbookFeedTaggedProductsOverlay() -> some View {
        GeometryReader { geo in
            lookbookFeedTaggedProductsChrome(width: geo.size.width, height: geo.size.height, slideIndex: 0)
        }
    }

    @ViewBuilder
    private func lookbookFeedTaggedProductsChrome(width: CGFloat, height: CGFloat, slideIndex: Int) -> some View {
        let w = max(1, width)
        let h = max(1, height)
        let items = lookbookFeedProductTagPinItems(forSlideIndex: slideIndex)
        ZStack {
            Color.clear
                .frame(width: w, height: h)
                .allowsHitTesting(false)
            if revealTaggedProductsOnImage {
                ForEach(items, id: \.tag.clientId) { pair in
                    lookbookFeedExpandedProductTagBadge(tag: pair.tag, snapshot: pair.snapshot, imageWidth: w, imageHeight: h)
                }
            }
        }
        .frame(width: w, height: h)
        .overlay(alignment: .bottomTrailing) {
            if entry.gridThumbnailTaggedProductCount > 0 {
                Button {
                    HapticManager.tap()
                    revealTaggedProductsOnImage.toggle()
                } label: {
                    Image(systemName: revealTaggedProductsOnImage ? "xmark.circle.fill" : "bag.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .padding(9)
                .accessibilityLabel(revealTaggedProductsOnImage ? "Hide product tags" : "Show product tags")
            }
        }
    }

    /// Snapshot image for `AsyncImage` (absolute URL only).
    private func lookbookFeedProductSnapshotImageURL(_ snapshot: LookbookProductSnapshot) -> URL? {
        let raw = snapshot.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty, let u = URL(string: raw), u.scheme != nil else { return nil }
        return u
    }

    /// Same layout as upload tagging: orange anchor + thumbnail + title, positioned so the anchor sits on `(x,y)`.
    private func lookbookFeedExpandedProductTagBadge(
        tag: LookbookTagData,
        snapshot: LookbookProductSnapshot,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> some View {
        let pointerSize: CGFloat = 24
        let thumbSize: CGFloat = 32
        let cardWidth: CGFloat = 100
        let spacing: CGFloat = 6
        let totalWidth = pointerSize + spacing + cardWidth
        let w = max(1, imageWidth)
        let h = max(1, imageHeight)
        return Button {
            HapticManager.tap()
            onProductTap(tag.productId)
        } label: {
            HStack(alignment: .center, spacing: spacing) {
                Circle()
                    .fill(Color.orange.opacity(0.9))
                    .frame(width: pointerSize, height: pointerSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                HStack(spacing: 6) {
                    Group {
                        if let url = lookbookFeedProductSnapshotImageURL(snapshot) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                case .failure, .empty:
                                    Rectangle()
                                        .fill(Theme.Colors.secondaryBackground)
                                        .overlay(Image(systemName: "photo").font(.caption2).foregroundColor(Theme.Colors.secondaryText))
                                @unknown default: EmptyView()
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Theme.Colors.secondaryBackground)
                                .overlay(Image(systemName: "photo").font(.caption2).foregroundColor(Theme.Colors.secondaryText))
                        }
                    }
                    .frame(width: thumbSize, height: thumbSize)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text(snapshot.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.75))
                .cornerRadius(8)
                .frame(width: cardWidth, alignment: .leading)
            }
            .frame(width: totalWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(snapshot.title)
        .position(
            x: w * CGFloat(tag.x) - pointerSize / 2 + totalWidth / 2,
            y: h * CGFloat(tag.y)
        )
    }

    @ViewBuilder
    private func lookbookSandboxSingleMedia(
        urlString: String,
        documentPath: String?,
        carouselPageWidth: CGFloat? = nil,
        carouselPageHeight: CGFloat? = nil
    ) -> some View {
        let isCarousel = carouselPageWidth != nil && carouselPageHeight != nil
        Group {
            if let ui = localDocumentUIImage(documentPath) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else if let url = URL(string: urlString), !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LookbookFeedRowRemoteImage(url: url)
            } else if !entry.imageNames.isEmpty, let ui = UIImage(named: entry.imageNames[0]) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                lookbookSandboxMediaPlaceholder(fixedCarouselSlot: isCarousel)
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(LookbookFeedMediaFrameModifier(carouselW: carouselPageWidth, carouselH: carouselPageHeight))
        .background(Theme.Colors.background)
        .clipped()
        .contentShape(Rectangle())
    }

    private func localDocumentUIImage(_ documentPath: String?) -> UIImage? {
        guard let path = documentPath, !path.isEmpty,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = dir.appending(path: path)
        guard let data = try? Data(contentsOf: url), let ui = UIImage(data: data) else { return nil }
        return ui
    }

    @ViewBuilder
    private func lookbookSandboxMediaPlaceholder(fixedCarouselSlot: Bool) -> some View {
        let base = Theme.Colors.secondaryBackground
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    Text(L10n.string("Could not load image"))
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
        if fixedCarouselSlot {
            base.aspectRatio(lookbookFeedAsyncImagePlaceholderAspect, contentMode: .fit)
        } else {
            base.frame(minHeight: 200)
        }
    }
}

/// Single-image posts use natural height; carousel pages use a fixed `w×h` slot with letterboxing via `scaledToFit`.
private struct LookbookFeedMediaFrameModifier: ViewModifier {
    var carouselW: CGFloat?
    var carouselH: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let w = carouselW, let h = carouselH {
            content.frame(width: w, height: h)
        } else {
            content
        }
    }
}

// MARK: - Loads product by id and presents ItemDetailView (for tagged product tap from lookbook feed)
struct LookbookProductDetailLoader: View {
    let productId: String
    let productService: ProductService
    let authService: AuthService
    @State private var item: Item?
    @State private var failed = false

    var body: some View {
        Group {
            if let item = item {
                ItemDetailView(item: item, authService: authService)
            } else if failed {
                ContentUnavailableView("Product unavailable", systemImage: "bag", description: Text("This item may have been removed."))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let id = Int(productId) else { failed = true; return }
            do {
                let loaded = try await productService.getProduct(id: id)
                await MainActor.run { item = loaded; if loaded == nil { failed = true } }
            } catch {
                await MainActor.run { failed = true }
            }
        }
    }
}

// MARK: - Comments sheet presentation (match `OptionsSheet` Sort / Filter: `navigationDone` + default detents)
extension View {
    func lookbookCommentsPresentationChrome() -> some View {
        presentationDetents([.fraction(0.58), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.Colors.modalSheetBackground)
    }
}

private enum LookbookCommentTimeFormatting {
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parsedDate(from iso: String) -> Date? {
        if let d = isoFrac.date(from: iso) { return d }
        return isoPlain.date(from: iso)
    }

    static func shortRelative(iso: String?) -> String {
        guard let iso, !iso.isEmpty, let date = parsedDate(from: iso) else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }

    /// Newest comment by `createdAt` (replies included); missing dates sort as oldest; stable tie-break on `id`.
    static func mostRecentlyCreatedComment(in comments: [ServerLookbookComment]) -> ServerLookbookComment? {
        comments.max { a, b in
            let da = parsedDate(from: a.createdAt ?? "") ?? .distantPast
            let db = parsedDate(from: b.createdAt ?? "") ?? .distantPast
            if da != db { return da < db }
            return a.id < b.id
        }
    }

    /// Feed preview: prefer a comment from someone the viewer follows (case-insensitive username match); otherwise highest `likes / age` (seconds, floored at 60).
    static func prominentFeedPreviewComment(
        in comments: [ServerLookbookComment],
        followedUsernamesLowercased: Set<String>
    ) -> ServerLookbookComment? {
        guard !comments.isEmpty else { return nil }
        let now = Date()

        func normalizedUser(_ c: ServerLookbookComment) -> String {
            c.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        func ageSeconds(_ c: ServerLookbookComment) -> TimeInterval {
            let d = parsedDate(from: c.createdAt ?? "") ?? .distantPast
            return max(0, now.timeIntervalSince(d))
        }

        func engagementScore(_ c: ServerLookbookComment) -> Double {
            let likes = Double(c.likesCount ?? 0)
            let age = max(ageSeconds(c), 60)
            return likes / age
        }

        func isBetter(_ a: ServerLookbookComment, than b: ServerLookbookComment) -> Bool {
            let sa = engagementScore(a)
            let sb = engagementScore(b)
            if sa != sb { return sa > sb }
            let la = a.likesCount ?? 0
            let lb = b.likesCount ?? 0
            if la != lb { return la > lb }
            let da = parsedDate(from: a.createdAt ?? "") ?? .distantPast
            let db = parsedDate(from: b.createdAt ?? "") ?? .distantPast
            if da != db { return da > db }
            return a.id > b.id
        }

        let fromFollowed = comments.filter { followedUsernamesLowercased.contains(normalizedUser($0)) }
        let pool = fromFollowed.isEmpty ? comments : fromFollowed
        return pool.max { a, b in !isBetter(a, than: b) }
    }
}

private struct LookbookCommentThreadRow: Identifiable {
    let id: String
    let comment: ServerLookbookComment
    let depth: Int
}

/// Nested replies: depth-first under each root (supports reply-to-reply).
private func lookbookThreadedCommentRows(from comments: [ServerLookbookComment]) -> [LookbookCommentThreadRow] {
    func compareCreated(_ a: String?, _ b: String?) -> Bool {
        let da = LookbookCommentTimeFormatting.parsedDate(from: a ?? "") ?? .distantPast
        let db = LookbookCommentTimeFormatting.parsedDate(from: b ?? "") ?? .distantPast
        return da < db
    }

    var byParent: [String: [ServerLookbookComment]] = [:]
    for c in comments {
        let pid = c.parentCommentId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !pid.isEmpty else { continue }
        byParent[pid, default: []].append(c)
    }
    for k in byParent.keys {
        byParent[k]?.sort { compareCreated($0.createdAt, $1.createdAt) }
    }

    func walk(parentId: String?, depth: Int) -> [LookbookCommentThreadRow] {
        let nodes: [ServerLookbookComment]
        if parentId == nil {
            nodes = comments
                .filter { ($0.parentCommentId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty }
                .sorted { compareCreated($0.createdAt, $1.createdAt) }
        } else {
            nodes = byParent[parentId!] ?? []
        }
        var out: [LookbookCommentThreadRow] = []
        for n in nodes {
            out.append(LookbookCommentThreadRow(id: n.id, comment: n, depth: depth))
            out.append(contentsOf: walk(parentId: n.id, depth: depth + 1))
        }
        return out
    }

    return walk(parentId: nil, depth: 0)
}

private struct LookbookCommentAvatar: View {
    let profilePictureUrl: String?
    let username: String
    var size: CGFloat = 32

    var body: some View {
        let trimmed = profilePictureUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Group {
            if let url = URL(string: trimmed), !trimmed.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Theme.Colors.secondaryBackground)
            .overlay(
                Text(String(username.prefix(1)).uppercased())
                    .font(.system(size: max(10, size * 0.34), weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText)
            )
    }
}

struct LookbookCommentsSheet: View {
    let entry: LookbookEntry
    var onCountChanged: ((Int) -> Void)? = nil
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [ServerLookbookComment] = []
    @State private var draft: String = ""
    @State private var loading = false
    @State private var sending = false
    @State private var replyParent: ServerLookbookComment?
    @State private var togglingLikeCommentId: String?
    @State private var deleteConfirmFor: ServerLookbookComment?
    @State private var deletingCommentId: String?

    private let sheetBg = Theme.Colors.modalSheetBackground

    private var threadedRows: [LookbookCommentThreadRow] {
        lookbookThreadedCommentRows(from: comments)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.lg)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        if threadedRows.isEmpty, !loading {
                            Text(L10n.string("No comments yet"))
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, Theme.Spacing.xl)
                        }
                        ForEach(threadedRows) { row in
                            lookbookCommentRow(row)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.md)
                }

                if let parent = replyParent {
                    HStack(spacing: Theme.Spacing.sm) {
                        (Text(L10n.string("Replying to")) + Text(" @\(parent.username)"))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Button(L10n.string("Cancel")) {
                            replyParent = nil
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.primaryColor)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.secondaryBackground.opacity(0.45))
                }

                HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                    TextField(L10n.string("Add a comment"), text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    Button(sending ? "…" : L10n.string("Send")) {
                        sendComment()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                    .foregroundColor(Theme.primaryColor)
                    .font(.system(size: 16, weight: .semibold))
                    .fixedSize()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(sheetBg)
            }
            .background(sheetBg)
            .navigationTitle(L10n.string("Comments"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(sheetBg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done")) { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.primaryColor)
                }
            }
            .confirmationDialog(
                L10n.string("Delete this comment?"),
                isPresented: Binding(
                    get: { deleteConfirmFor != nil },
                    set: { if !$0 { deleteConfirmFor = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n.string("Delete"), role: .destructive) {
                    if let c = deleteConfirmFor {
                        Task { await deleteComment(c) }
                    }
                    deleteConfirmFor = nil
                }
                Button(L10n.string("Cancel"), role: .cancel) {
                    deleteConfirmFor = nil
                }
            } message: {
                Text(L10n.string("This will remove your comment and any replies under it."))
            }
            .task { await loadComments() }
        }
    }

    private func isMine(_ c: ServerLookbookComment) -> Bool {
        guard let me = authService.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !me.isEmpty else {
            return false
        }
        return c.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == me
    }

    @ViewBuilder
    private func lookbookCommentRow(_ row: LookbookCommentThreadRow) -> some View {
        let c = row.comment
        let timeStr = LookbookCommentTimeFormatting.shortRelative(iso: c.createdAt)
        let effectiveDepth = min(row.depth, 2)
        let indent = Theme.Spacing.md + CGFloat(effectiveDepth) * 18
        let liked = c.userLiked ?? false
        let likeCount = c.likesCount ?? 0
        let busyLike = togglingLikeCommentId == c.id

        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            LookbookCommentAvatar(profilePictureUrl: c.profilePictureUrl, username: c.username, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    // Same text style size as comment body (`HashtagColoredText` uses subheadline); weight distinguishes name.
                    Text(c.username)
                        .font(Theme.Typography.body.weight(.semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: Theme.Spacing.sm)
                    if !timeStr.isEmpty {
                        Text(timeStr)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.trailing)
                    }
                }
                HashtagColoredText(text: c.text)
                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    Button {
                        replyParent = c
                    } label: {
                        Text(L10n.string("Reply"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.primaryColor)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await toggleLike(c) }
                    } label: {
                        HStack(spacing: 4) {
                            if busyLike {
                                ProgressView()
                                    .scaleEffect(0.78)
                            } else {
                                Image(systemName: liked ? "heart.fill" : "heart")
                                    .font(.system(size: 14, weight: .semibold))
                                if likeCount > 0 {
                                    Text("\(likeCount)")
                                        .font(.system(size: 13, weight: .medium))
                                }
                            }
                        }
                        .foregroundColor(liked ? Theme.primaryColor : Theme.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(busyLike || !authService.isAuthenticated)

                    if isMine(c) {
                        Button {
                            deleteConfirmFor = c
                        } label: {
                            Text(L10n.string("Delete"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Colors.error)
                        }
                        .buttonStyle(.plain)
                        .disabled(deletingCommentId == c.id)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, indent)
        .padding(.trailing, Theme.Spacing.md)
    }

    private func loadComments() async {
        loading = true
        defer { loading = false }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        if let loaded = try? await service.fetchComments(postId: entry.apiPostId) {
            comments = loaded
            onCountChanged?(loaded.count)
        }
    }

    private func toggleLike(_ c: ServerLookbookComment) async {
        guard authService.isAuthenticated else { return }
        let id = c.id
        await MainActor.run { togglingLikeCommentId = id }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        do {
            let result = try await service.toggleCommentLike(commentId: id)
            await MainActor.run {
                if let idx = comments.firstIndex(where: { $0.id == id }) {
                    let cur = comments[idx]
                    comments[idx] = cur.withLikeUpdate(likesCount: result.likesCount, userLiked: result.liked)
                }
                togglingLikeCommentId = nil
            }
        } catch {
            await MainActor.run { togglingLikeCommentId = nil }
        }
    }

    private func deleteComment(_ c: ServerLookbookComment) async {
        let id = c.id
        await MainActor.run { deletingCommentId = id }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        do {
            _ = try await service.deleteComment(commentId: id)
            await MainActor.run { deletingCommentId = nil }
            await loadComments()
        } catch {
            await MainActor.run { deletingCommentId = nil }
        }
    }

    private func sendComment() {
        var text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parentId = replyParent?.id
        // Reply text is stored as typed; parent author is notified by the server from `parent_comment_id` (no @mention injected).
        if let parent = replyParent {
            let pu = parent.username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pu.isEmpty else { return }
            let mentionPrefix = "@\(pu) "
            if text.lowercased().hasPrefix(mentionPrefix.lowercased()) {
                text = String(text.dropFirst(mentionPrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard !text.isEmpty else { return }
        }

        sending = true
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        Task {
            do {
                let result = try await service.addComment(postId: entry.apiPostId, text: text, parentCommentId: parentId)
                await MainActor.run {
                    draft = ""
                    replyParent = nil
                    comments.append(result.comment)
                    onCountChanged?(result.commentsCount)
                    sending = false
                }
            } catch {
                await MainActor.run { sending = false }
            }
        }
    }
}

// MARK: - Square grid cell (Instagram-style crop; loading/error keep same bounds)
/// Grid-only: load CDN `*_thumbnail` (or `entry.thumbnailUrl`) first for speed; open post still uses full `imageUrls` in the feed row.
private struct LookbookSquareGridRemoteImage: View {
    let fullURLString: String
    let serverThumbnailURL: String?

    @State private var useFullImage = false

    private var thumbnailToTry: String? {
        if let s = serverThumbnailURL?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s }
        return LookbookCDNThumbnailURL.urlString(forFullImageURL: fullURLString)
    }

    private var urlToLoad: URL? {
        let full = fullURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !full.isEmpty else { return nil }
        if useFullImage { return URL(string: full) }
        if let t = thumbnailToTry, t != full, let u = URL(string: t) { return u }
        return URL(string: full)
    }

    var body: some View {
        AsyncImage(url: urlToLoad) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                gridRemoteFailurePlaceholder
                    .onAppear {
                        let full = fullURLString.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !useFullImage, let t = thumbnailToTry, t != full {
                            useFullImage = true
                        }
                    }
            default:
                Rectangle()
                    .fill(Theme.Colors.secondaryBackground)
                    .shimmering()
            }
        }
        .id("\(useFullImage)-\(urlToLoad?.absoluteString ?? "")")
    }

    private var gridRemoteFailurePlaceholder: some View {
        ZStack {
            Theme.Colors.secondaryBackground
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }
}

private struct LookbookSquareGridThumbnail: View {
    let entry: LookbookEntry

    private var taggedProductCount: Int { entry.gridThumbnailTaggedProductCount }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                squareFillContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .overlay(alignment: .bottomTrailing) {
                if taggedProductCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(taggedProductCount)")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.58))
                    .clipShape(Capsule())
                    .padding(5)
                    .allowsHitTesting(false)
                }
            }
            .clipped()
    }

    @ViewBuilder
    private var squareFillContent: some View {
        if let urlString = entry.imageUrls.first, URL(string: urlString) != nil {
            LookbookSquareGridRemoteImage(fullURLString: urlString, serverThumbnailURL: entry.thumbnailUrl)
        } else if let path = entry.documentImagePath,
                  let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: path),
                  let data = try? Data(contentsOf: base),
                  let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let first = entry.imageNames.first {
            Image(first)
                .resizable()
                .scaledToFill()
        } else {
            squarePlaceholder
        }
    }

    private var squarePlaceholder: some View {
        ZStack {
            Theme.Colors.secondaryBackground
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }
}

// MARK: - Thumbnail for search / list (server URL, document image, or asset)
private struct LookbookEntryThumbnail: View {
    let entry: LookbookEntry
    var body: some View {
        Group {
            if let urlString = entry.imageUrls.first, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: Image(systemName: "photo").resizable().scaledToFit().foregroundStyle(Theme.Colors.secondaryText)
                    default: ProgressView()
                    }
                }
            } else if let path = entry.documentImagePath,
               let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: path),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let first = entry.imageNames.first {
                Image(first)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }
}

private struct HashtagColoredText: View {
    let text: String
    @EnvironmentObject private var appRouter: AppRouter

    private var attributed: AttributedString {
        var result = AttributedString(text)
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        if let regex = try? NSRegularExpression(pattern: "#\\w+") {
            for match in regex.matches(in: text, range: full) {
                guard let range = Range(match.range, in: result) else { continue }
                result[range].foregroundColor = Theme.primaryColor
                result[range].font = Theme.Typography.subheadline.weight(.semibold)
            }
        }

        if let regex = try? NSRegularExpression(pattern: "@[A-Za-z0-9_]+") {
            for match in regex.matches(in: text, range: full) {
                guard let range = Range(match.range, in: result) else { continue }
                let token = ns.substring(with: match.range)
                let username = String(token.dropFirst())
                if !username.isEmpty {
                    let enc = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
                    if let url = URL(string: "prelura://user/\(enc)") {
                        result[range].link = url
                    }
                }
                result[range].foregroundColor = Theme.primaryColor
                result[range].font = Theme.Typography.subheadline.weight(.semibold)
            }
        }

        return result
    }

    var body: some View {
        Text(attributed)
            .font(Theme.Typography.subheadline)
            .foregroundColor(Theme.Colors.primaryText)
            .lineLimit(nil)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme?.lowercased() == "prelura",
                   let host = url.host?.lowercased(),
                   host == "user" || host == "profile" {
                    appRouter.handle(url: url)
                    return .handled
                }
                return .systemAction
            })
    }
}

private struct LookbookFullscreenImage: View {
    let documentImagePath: String?
    let imageName: String
    let imageUrl: String?

    @State private var scale: CGFloat = 1
    @State private var anchorScale: CGFloat = 1
    @State private var dragOffset: CGSize = .zero
    @State private var anchorDragOffset: CGSize = .zero

    private var localUIImage: UIImage? {
        if let path = documentImagePath,
           let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: path),
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) { return ui }
        if !imageName.isEmpty, let ui = UIImage(named: imageName) { return ui }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if let ui = localUIImage {
                    Image(uiImage: ui).resizable().scaledToFit()
                } else if let s = imageUrl, let url = URL(string: s) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        case .empty: ProgressView().tint(.white)
                        default:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.7))
                                .padding(80)
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white.opacity(0.7))
                        .padding(80)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(scale)
            .offset(dragOffset)
            .contentShape(Rectangle())
            .highPriorityGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(1, anchorScale * value)
                    }
                    .onEnded { _ in
                        scale = min(max(scale, 1), 6)
                        anchorScale = scale
                        if scale <= 1.01 {
                            dragOffset = .zero
                            anchorDragOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard scale > 1.01 else { return }
                        dragOffset = CGSize(
                            width: anchorDragOffset.width + value.translation.width,
                            height: anchorDragOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        guard scale > 1.01 else { return }
                        anchorDragOffset = dragOffset
                    }
            )
        }
    }
}

// MARK: - Feed search (pushed): accounts, hashtags, products, captions & styles

/// `#word` tokens as they appear in captions (includes `#`).
private func lookbookCaptionHashtagTokens(from caption: String?) -> [String] {
    guard let caption, !caption.isEmpty else { return [] }
    var out: [String] = []
    var i = caption.startIndex
    while i < caption.endIndex {
        if caption[i] == "#" {
            let hashStart = i
            i = caption.index(after: i)
            let bodyStart = i
            while i < caption.endIndex {
                let ch = caption[i]
                if ch.isLetter || ch.isNumber || ch == "_" {
                    i = caption.index(after: i)
                } else {
                    break
                }
            }
            if i > bodyStart {
                out.append(String(caption[hashStart..<i]))
            }
        } else {
            i = caption.index(after: i)
        }
    }
    return out
}

/// Match query against poster username, caption (incl. hashtags), style topics, and tagged product titles.
private func lookbookEntryMatchesContentSearch(_ entry: LookbookEntry, query raw: String) -> Bool {
    let q = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if q.isEmpty { return true }
    let qNoHash = q.hasPrefix("#") ? String(q.dropFirst()) : q
    let poster = entry.posterUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if !poster.isEmpty, poster.contains(q) { return true }
    if let cap = entry.caption, !cap.isEmpty {
        let c = cap.lowercased()
        if c.contains(q) { return true }
        if !qNoHash.isEmpty, c.contains(qNoHash) { return true }
    }
    for style in entry.styles {
        if style.lowercased().contains(q) { return true }
        let display = StyleSelectionView.displayName(for: style).lowercased()
        if display.contains(q) { return true }
        if !qNoHash.isEmpty, display.contains(qNoHash) { return true }
    }
    if let snaps = entry.productSnapshots {
        for snap in snaps.values {
            if snap.title.lowercased().contains(q) { return true }
        }
    }
    return false
}

private struct LookbookFeedSearchGrouped {
    let accounts: [(user: User, entry: LookbookEntry)]
    let hashtags: [(display: String, key: String, count: Int, sample: LookbookEntry)]
    let products: [(snapshot: LookbookProductSnapshot, entry: LookbookEntry)]
    let looks: [LookbookEntry]
}

private func lookbookFeedSearchGrouped(entries: [LookbookEntry], query raw: String) -> LookbookFeedSearchGrouped {
    let q = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if q.isEmpty {
        return LookbookFeedSearchGrouped(accounts: [], hashtags: [], products: [], looks: [])
    }
    let qBody = q.hasPrefix("#") ? String(q.dropFirst()) : q
    guard !qBody.isEmpty else {
        return LookbookFeedSearchGrouped(accounts: [], hashtags: [], products: [], looks: entries.filter { lookbookEntryMatchesContentSearch($0, query: raw) })
    }

    var seenUser = Set<String>()
    var accounts: [(User, LookbookEntry)] = []
    for e in entries {
        let un = e.posterUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !un.isEmpty else { continue }
        if un.lowercased().contains(qBody), seenUser.insert(un.lowercased()).inserted {
            let av = e.posterProfilePictureUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let user = User(username: un, displayName: un, avatarURL: av.isEmpty ? nil : av)
            accounts.append((user, e))
        }
    }

    var tagCount: [String: Int] = [:]
    var tagDisplay: [String: String] = [:]
    var tagSample: [String: LookbookEntry] = [:]
    for e in entries {
        for tok in lookbookCaptionHashtagTokens(from: e.caption) {
            let body = tok.hasPrefix("#") ? String(tok.dropFirst()).lowercased() : tok.lowercased()
            guard !body.isEmpty else { continue }
            guard body.contains(qBody) || qBody.contains(body) || body.hasPrefix(qBody) else { continue }
            let key = body
            tagCount[key, default: 0] += 1
            if tagDisplay[key] == nil {
                tagDisplay[key] = tok.hasPrefix("#") ? tok : "#\(tok)"
            }
            if tagSample[key] == nil {
                tagSample[key] = e
            }
        }
    }
    let hashtags: [(String, String, Int, LookbookEntry)] = tagCount.keys.sorted().compactMap { key in
        guard let c = tagCount[key], let d = tagDisplay[key], let s = tagSample[key] else { return nil }
        return (d, key, c, s)
    }

    var seenPid = Set<String>()
    var products: [(LookbookProductSnapshot, LookbookEntry)] = []
    for e in entries {
        guard let snaps = e.productSnapshots else { continue }
        for snap in snaps.values {
            if snap.title.lowercased().contains(qBody), seenPid.insert(snap.productId).inserted {
                products.append((snap, e))
            }
        }
    }

    let looks = entries.filter { lookbookEntryMatchesContentSearch($0, query: raw) }
    return LookbookFeedSearchGrouped(accounts: accounts, hashtags: hashtags, products: products, looks: looks)
}

private func lookbookSearchSectionHeader(_ title: String) -> some View {
    Text(title)
        .font(Theme.Typography.headline)
        .foregroundStyle(Theme.Colors.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xs)
}

private func lookbookFeedSearchResultTitle(_ entry: LookbookEntry) -> String {
    if let c = entry.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
        return String(c.prefix(120))
    }
    let names = entry.styles.map { StyleSelectionView.displayName(for: $0) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    if !names.isEmpty { return names.joined(separator: " · ") }
    return L10n.string("Lookbook post")
}

private func lookbookFeedSearchResultSubtitle(_ entry: LookbookEntry) -> String? {
    let names = entry.styles.map { StyleSelectionView.displayName(for: $0) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    guard !names.isEmpty else { return nil }
    if let c = entry.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
        return names.joined(separator: " · ")
    }
    return nil
}

private struct LookbookFeedSearchAccountRow: Identifiable {
    let id: String
    let user: User
    let entry: LookbookEntry
}

private struct LookbookFeedSearchHashtagRow: Identifiable {
    let id: String
    let display: String
    let count: Int
    let sample: LookbookEntry
}

private struct LookbookFeedSearchProductRow: Identifiable {
    let id: String
    let snapshot: LookbookProductSnapshot
    let entry: LookbookEntry
}

private struct LookbookFeedSearchView: View {
    let entries: [LookbookEntry]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var searchText: String = ""
    @State private var selectedProduct: ProductIdNavigator?

    private let productService = ProductService()

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var grouped: LookbookFeedSearchGrouped {
        lookbookFeedSearchGrouped(entries: entries, query: searchText)
    }

    private var accountRows: [LookbookFeedSearchAccountRow] {
        grouped.accounts.map { pair in
            LookbookFeedSearchAccountRow(
                id: pair.user.username.lowercased(),
                user: pair.user,
                entry: pair.entry
            )
        }
    }

    private var hashtagRows: [LookbookFeedSearchHashtagRow] {
        grouped.hashtags.map { row in
            LookbookFeedSearchHashtagRow(id: row.key, display: row.display, count: row.count, sample: row.sample)
        }
    }

    private var productRows: [LookbookFeedSearchProductRow] {
        grouped.products.map { pair in
            LookbookFeedSearchProductRow(id: pair.snapshot.productId, snapshot: pair.snapshot, entry: pair.entry)
        }
    }

    private var hasAnyResults: Bool {
        !grouped.accounts.isEmpty || !grouped.hashtags.isEmpty || !grouped.products.isEmpty || !grouped.looks.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HomeFeedSearchField(
                    text: $searchText,
                    onSubmit: { _ in },
                    onAITap: nil,
                    topPadding: Theme.Spacing.xs,
                    placeholderCarousel: [
                        L10n.string("Try a username"),
                        L10n.string("Try a hashtag"),
                        L10n.string("Try a product name"),
                    ]
                )
            }
            .padding(.top, Theme.Spacing.xs)
            .background(Theme.Colors.background)

            if trimmedQuery.isEmpty {
                Spacer(minLength: 0)
                Text(L10n.string("Search this feed by username, hashtag, or product."))
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                Spacer(minLength: 0)
            } else if !hasAnyResults {
                Text(L10n.string("No looks match your search."))
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xl)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if !accountRows.isEmpty {
                            lookbookSearchSectionHeader(L10n.string("Accounts"))
                            ForEach(accountRows) { row in
                                NavigationLink {
                                    UserProfileView(seller: row.user, authService: authService)
                                } label: {
                                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                        LookbookEntryThumbnail(entry: row.entry)
                                            .frame(width: 50, height: 50)
                                            .clipped()
                                            .cornerRadius(8)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("@\(row.user.username)")
                                                .font(Theme.Typography.body)
                                                .foregroundStyle(Theme.Colors.primaryText)
                                                .lineLimit(1)
                                            Text(L10n.string("In this feed"))
                                                .font(Theme.Typography.caption)
                                                .foregroundStyle(Theme.Colors.secondaryText)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                            .padding(.top, 4)
                                    }
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.xs)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !hashtagRows.isEmpty {
                            lookbookSearchSectionHeader(L10n.string("Hashtags"))
                            ForEach(hashtagRows) { row in
                                Button {
                                    searchText = row.display
                                } label: {
                                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                        LookbookEntryThumbnail(entry: row.sample)
                                            .frame(width: 50, height: 50)
                                            .clipped()
                                            .cornerRadius(8)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(row.display)
                                                .font(Theme.Typography.body)
                                                .foregroundStyle(Theme.Colors.primaryText)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            if row.count > 1 {
                                                Text(String(format: L10n.string("In %d looks"), row.count))
                                                    .font(Theme.Typography.caption)
                                                    .foregroundStyle(Theme.Colors.secondaryText)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.xs)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !productRows.isEmpty {
                            lookbookSearchSectionHeader(L10n.string("Products"))
                            ForEach(productRows) { row in
                                Button {
                                    selectedProduct = ProductIdNavigator(id: row.snapshot.productId)
                                } label: {
                                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                        lookbookFeedSearchProductThumb(snapshot: row.snapshot, fallbackEntry: row.entry)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(row.snapshot.title)
                                                .font(Theme.Typography.body)
                                                .foregroundStyle(Theme.Colors.primaryText)
                                                .lineLimit(3)
                                                .multilineTextAlignment(.leading)
                                            Text(L10n.string("Tagged in look"))
                                                .font(Theme.Typography.caption)
                                                .foregroundStyle(Theme.Colors.secondaryText)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                            .padding(.top, 4)
                                    }
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.xs)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !grouped.looks.isEmpty {
                            lookbookSearchSectionHeader(L10n.string("Looks"))
                            ForEach(grouped.looks) { entry in
                                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                    LookbookEntryThumbnail(entry: entry)
                                        .frame(width: 50, height: 50)
                                        .clipped()
                                        .cornerRadius(8)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lookbookFeedSearchResultTitle(entry))
                                            .font(Theme.Typography.body)
                                            .foregroundStyle(Theme.Colors.primaryText)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                        if let sub = lookbookFeedSearchResultSubtitle(entry) {
                                            Text(sub)
                                                .font(Theme.Typography.caption)
                                                .foregroundStyle(Theme.Colors.secondaryText)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.xs)
                            }
                        }
                    }
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Search"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .navigationDestination(item: $selectedProduct) { nav in
            LookbookProductDetailLoader(productId: nav.id, productService: productService, authService: authService)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButtonBar {
                PrimaryGlassButton(L10n.string("Done")) {
                    dismiss()
                }
            }
        }
    }
}

private func lookbookFeedSearchProductThumb(snapshot: LookbookProductSnapshot, fallbackEntry: LookbookEntry) -> some View {
    let trimmed = snapshot.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return Group {
        if !trimmed.isEmpty, let url = URL(string: trimmed) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                case .failure: LookbookEntryThumbnail(entry: fallbackEntry)
                default: ProgressView()
                }
            }
        } else {
            LookbookEntryThumbnail(entry: fallbackEntry)
        }
    }
    .frame(width: 50, height: 50)
    .clipped()
    .cornerRadius(8)
}

extension SavedLookbookPhoto {
    /// Builds the same `LookbookEntry` shape the main feed uses so `LookbookFeedRowView` can render identically.
    func asLookbookEntryForFeed() -> LookbookEntry {
        let u = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let thumb: String? = {
            guard !u.isEmpty, let t = LookbookCDNThumbnailURL.urlString(forFullImageURL: u) else { return nil }
            return t
        }()
        let tid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedId = LookbookPostIdFormatting.graphQLUUIDString(from: tid)
        let stableUUID = UUID(uuidString: normalizedId) ?? UUID(uuidString: tid) ?? UUID()
        return LookbookEntry(
            id: stableUUID,
            serverPostId: tid,
            imageNames: [],
            documentImagePath: nil,
            imageUrl: u,
            thumbnailUrl: thumb,
            posterUsername: posterUsername,
            posterProfilePictureUrl: posterProfilePictureUrl,
            caption: caption,
            createdAt: nil,
            likesCount: likesCount ?? 0,
            isLiked: isLiked ?? false,
            commentsCount: commentsCount ?? 0,
            productLinkClicks: 0,
            shopLinkClicks: 0,
            styles: styles ?? [],
            serverTaggedProductCount: nil,
            tags: nil,
            productSnapshots: nil
        )
    }
}

extension LookbookEntry: Equatable {
    static func == (lhs: LookbookEntry, rhs: LookbookEntry) -> Bool {
        lhs.id == rhs.id
            && lhs.likesCount == rhs.likesCount
            && lhs.isLiked == rhs.isLiked
            && lhs.commentsCount == rhs.commentsCount
    }
}

extension LookbookEntry: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(likesCount)
        hasher.combine(isLiked)
        hasher.combine(commentsCount)
    }
}

#if DEBUG
struct LookbookView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LookbookView()
                .environmentObject(AuthService())
                .environmentObject(LookbookHideLikeCountsStore.shared)
        }
    }
}
#endif
