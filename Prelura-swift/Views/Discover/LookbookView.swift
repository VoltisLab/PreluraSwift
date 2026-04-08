//
//  LookbookView.swift
//  Prelura-swift
//
//  Instagram-style feed: full-width images, scrollable, poster, comments (tappable), style filters.
//

import SwiftUI
import Shimmer
import UIKit
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
    let caption: String?
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

    init(id: UUID? = nil, serverPostId: String? = nil, imageNames: [String], documentImagePath: String? = nil, imageUrl: String? = nil, thumbnailUrl: String? = nil, posterUsername: String, posterProfilePictureUrl: String? = nil, caption: String? = nil, commentsCount: Int, productLinkClicks: Int = 0, shopLinkClicks: Int = 0, styles: [String], tags: [LookbookTagData]? = nil, productSnapshots: [String: LookbookProductSnapshot]? = nil) {
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
        self.commentsCount = commentsCount
        self.productLinkClicks = productLinkClicks
        self.shopLinkClicks = shopLinkClicks
        self.styles = styles
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
        self.caption = serverPost.caption
        self.commentsCount = serverPost.commentsCount ?? 0
        self.productLinkClicks = serverPost.productLinkClicks ?? 0
        self.shopLinkClicks = serverPost.shopLinkClicks ?? 0
        self.styles = localRecord?.styles ?? []
        self.tags = localRecord?.tags
        self.productSnapshots = localRecord?.productSnapshots
    }
}

/// Vertical rhythm between major feed blocks (slightly looser than before).
private let lookbookSpacing: CGFloat = 16
/// Horizontal gap between carousel thumbnails (was `sm`; nudge wider).
private let lookbookThumbInterItem: CGFloat = Theme.Spacing.sm + 4
private let lookbookTopId = "lookbook_top"

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

// MARK: - One feed row per post (`LookbookFeedRowModel.id` is stable per post; counts refresh via `entry` updates)

private struct LookbookFeedRowModel: Identifiable {
    let id: String
    let entry: LookbookEntry
}

/// Stable per-post id for `ForEach` / `.id`. Do **not** bake like or comment counts into this — that recreates the whole row
/// (and any `UIViewRepresentable` like the heart) on every count change, which breaks taps.
private func lookbookFeedRowStableId(for entry: LookbookEntry) -> String {
    let k = entry.lookbookPostKey
    if !k.isEmpty { return k }
    return entry.id.uuidString
}

private func buildLookbookFeedRows(from list: [LookbookEntry]) -> [LookbookFeedRowModel] {
    list.map { entry in
        LookbookFeedRowModel(id: lookbookFeedRowStableId(for: entry), entry: entry)
    }
}

/// Style raw values for filter pills — same as StyleSelectionView (uploads). Subset used for display.
private let lookbookStylePillValues: [String] = [
    "CASUAL", "VINTAGE", "STREETWEAR", "MINIMALIST", "BOHO", "CHIC", "FORMAL_WEAR",
    "PARTY_DRESS", "LOUNGEWEAR", "ACTIVEWEAR", "Y2K", "DRESSES_GOWNS", "DENIM_JEANS",
    "SUMMER_STYLES", "WINTER_ESSENTIALS", "ATHLEISURE", "DATE_NIGHT", "VACATION_RESORT_WEAR"
]

private struct ProductIdNavigator: Identifiable, Hashable {
    let id: String
}

/// Lookbooks entry: choose Feed, Explore, or My items (onboarding on first open).
struct LookbookView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var showLookbooksOnboarding = false
    @State private var didScheduleLookbooksOnboarding = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                LookbooksHubBannerRow(
                    kind: .feed,
                    title: L10n.string("Feed"),
                    subtitle: L10n.string("Latest looks from people you follow and the community.")
                ) {
                    LookbookFeedScreenView()
                }
                LookbooksHubBannerRow(
                    kind: .explore,
                    title: L10n.string("Explore"),
                    subtitle: L10n.string("Browse by style, communities, and editorial picks.")
                ) {
                    LookbookExploreScreenView()
                }
                LookbooksHubBannerRow(
                    kind: .myItems,
                    title: L10n.string("My items"),
                    subtitle: L10n.string("Your uploads — switch between feed and a 3-column grid.")
                ) {
                    LookbookMyItemsScreenView()
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Lookbook"))
        .navigationBarTitleDisplayMode(.inline)
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

private enum LookbookHubBannerKind {
    case feed, explore, myItems

    fileprivate var symbol: String {
        switch self {
        case .feed: return "rectangle.stack"
        case .explore: return "sparkles.rectangle.stack"
        case .myItems: return "person.crop.square"
        }
    }

    fileprivate var accent: Color {
        switch self {
        case .feed: return Theme.primaryColor
        case .explore: return Color(red: 0.58, green: 0.38, blue: 0.98)
        case .myItems: return Color(red: 0.98, green: 0.48, blue: 0.42)
        }
    }
}

private struct LookbooksHubBannerRow<Destination: View>: View {
    let kind: LookbookHubBannerKind
    let title: String
    let subtitle: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    kind.accent.opacity(0.65),
                                    kind.accent.opacity(0.22),
                                    Theme.Colors.tertiaryBackground.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.45), kind.accent.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    Image(systemName: kind.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: kind.accent.opacity(0.55), radius: 8, x: 0, y: 3)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius, style: .continuous)
                    .fill(Theme.Colors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.glassBorder.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feed (posts only)

private struct LookbookFeedScreenView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [LookbookEntry] = []
    @State private var feedLoading = false
    @State private var feedError: String?
    @State private var feedErrorBannerTitle: String?
    @State private var scrollPosition: String? = lookbookTopId
    @State private var showSearchSheet: Bool = false
    @State private var searchText: String = ""
    @State private var commentsEntry: LookbookEntry?
    @State private var fullScreenEntry: LookbookEntry?
    @State private var selectedProductId: ProductIdNavigator?
    @State private var analyticsEntry: LookbookEntry?
    private let productService = ProductService()

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ScrollView {
                    LookbookScrollImmediateTouchesAnchor()
                        .frame(width: 0, height: 0)
                    LazyVStack(spacing: 0) {
                        Color.clear.frame(height: 1).id(lookbookTopId)

                        if feedLoading && entries.isEmpty {
                            LookbookFeedOnlyShimmerView()
                        } else if entries.isEmpty {
                            feedEmptyPlaceholder(minHeight: geometry.size.height - 120)
                        } else {
                            ForEach(buildLookbookFeedRows(from: entries)) { row in
                                lookbookFeedRow(model: row)
                            }
                        }
                    }
                    .padding(.bottom, Theme.Spacing.xl)
                }
                .scrollPosition(id: $scrollPosition, anchor: .top)
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.background)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let entry = fullScreenEntry {
                LookbookTransparentFullscreenOverlay(entry: entry) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        fullScreenEntry = nil
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .center)),
                    removal: .opacity
                ))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: fullScreenEntry?.id)
        .navigationTitle(L10n.string("Feed"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .accessibilityLabel(L10n.string("Back"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.sm) {
                    NavigationLink(destination: LookbooksUploadView()) {
                        GlassIconView(icon: "plus.circle", iconColor: Theme.Colors.primaryText, iconSize: 20)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                    GlassIconButton(
                        icon: "magnifyingglass",
                        iconColor: Theme.Colors.primaryText,
                        iconSize: 20,
                        action: { showSearchSheet = true }
                    )
                }
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
            .presentationDetents([.fraction(0.44), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(22)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: $showSearchSheet) {
            LookbookSearchSheet(searchText: $searchText, entries: entries)
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
            let posts = try await service.fetchLookbooks()
            let localRecords = LookbookFeedStore.load()
            await MainActor.run {
                entries = posts.map { post in
                    LookbookEntry(from: post, localRecord: localRecords.first { r in r.id == post.id || r.imagePath == post.imageUrl })
                }
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
            if let err = feedError, !err.isEmpty {
                FeedNetworkBannerView(message: err, title: feedErrorBannerTitle) {
                    loadFeedFromServer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: max(minHeight, 200))
    }

    private func lookbookFeedRow(model: LookbookFeedRowModel) -> some View {
        LookbookFeedRowView(
            entry: model.entry,
            onCommentsTap: { commentsEntry = $0 },
            onImageTap: { tapped in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    fullScreenEntry = tapped
                }
            },
            onProductTap: { productId in selectedProductId = ProductIdNavigator(id: productId) },
            onPostDeleted: { deleted in
                entries.removeAll { $0.lookbookPostKey == deleted.lookbookPostKey }
            },
            onOpenAnalytics: { analyticsEntry = $0 }
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
    @State private var entries: [LookbookEntry] = []
    @State private var feedLoading = false
    @State private var feedError: String?
    @State private var feedErrorBannerTitle: String?
    @State private var useGrid = false
    @State private var commentsEntry: LookbookEntry?
    /// When set, shows a full-screen vertical pager (Instagram/TikTok-style) starting at this post id.
    @State private var immersiveFeedInitialPostId: String?
    @State private var immersiveScrollTargetId: UUID?
    @State private var selectedProductId: ProductIdNavigator?
    @State private var analyticsEntry: LookbookEntry?
    private let productService = ProductService()

    private var myEntries: [LookbookEntry] {
        guard let me = authService.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !me.isEmpty else { return [] }
        return entries.filter { $0.posterUsername.lowercased() == me }
    }

    /// Profile grid: small spacing between cells; page background matches the main Feed (`Theme.Colors.background`).
    private static let gridGutter: CGFloat = 2
    private static let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: gridGutter),
        GridItem(.flexible(), spacing: gridGutter),
        GridItem(.flexible(), spacing: gridGutter)
    ]

    /// One fullscreen page: full-width media like the main feed; inner scroll only when the post is taller than the viewport (centers short posts).
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
        }
        .frame(maxWidth: .infinity, minHeight: pageHeight, maxHeight: pageHeight)
        .id(entry.id)
    }

    private var immersivePagerDismissButton: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                immersiveFeedInitialPostId = nil
                immersiveScrollTargetId = nil
            }
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
        ScrollView(.vertical, showsIndicators: false) {
            LookbookScrollImmediateTouchesAnchor()
                .frame(width: 0, height: 0)
            VStack(spacing: 0) {
                ForEach(myEntries) { entry in
                    immersivePagerPage(entry: entry, pageHeight: pageHeight)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $immersiveScrollTargetId, anchor: .center)
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
        ZStack {
            Group {
                if feedLoading && entries.isEmpty {
                    LookbookFeedOnlyShimmerView()
                } else if myEntries.isEmpty {
                    myItemsEmpty
                } else if useGrid {
                    ScrollView {
                        LazyVGrid(columns: Self.gridColumns, spacing: Self.gridGutter) {
                            ForEach(myEntries) { entry in
                                Button {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                        immersiveFeedInitialPostId = entry.apiPostId
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
                    }
                    .scrollContentBackground(.hidden)
                    .background(Theme.Colors.background)
                } else {
                    ScrollView {
                        LookbookScrollImmediateTouchesAnchor()
                            .frame(width: 0, height: 0)
                        LazyVStack(spacing: 0) {
                            ForEach(buildLookbookFeedRows(from: myEntries)) { row in
                                lookbookFeedRow(model: row)
                            }
                        }
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Theme.Colors.background)
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
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)),
                    removal: .opacity
                ))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: immersiveFeedInitialPostId)
        .navigationTitle(L10n.string("My items"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        useGrid.toggle()
                    } label: {
                        Image(systemName: useGrid ? "list.bullet" : "square.grid.3x3")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    .accessibilityLabel(useGrid ? L10n.string("List view") : L10n.string("Grid view"))
                    NavigationLink(destination: LookbooksUploadView()) {
                        GlassIconView(icon: "plus.circle", iconColor: Theme.Colors.primaryText, iconSize: 20)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                }
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
            .presentationDetents([.fraction(0.44), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(22)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
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
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.secondaryText)
            Text(L10n.string("No uploads yet"))
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.primaryText)
            Text(L10n.string("Post a look from the plus button — it will show up here."))
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            if let err = feedError, !err.isEmpty {
                FeedNetworkBannerView(message: err, title: feedErrorBannerTitle) {
                    loadFeedFromServer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Theme.Spacing.xl)
    }

    private func loadFeedFromServer() {
        Task { await loadFeedFromServerAsync() }
    }

    private func loadFeedFromServerAsync() async {
        guard authService.isAuthenticated else {
            await MainActor.run { entries = []; feedLoading = false; feedError = nil; feedErrorBannerTitle = nil }
            return
        }
        await MainActor.run { feedLoading = true; feedError = nil; feedErrorBannerTitle = nil }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        service.setAuthToken(authService.authToken)
        do {
            let posts = try await service.fetchLookbooks()
            let localRecords = LookbookFeedStore.load()
            await MainActor.run {
                entries = posts.map { post in
                    LookbookEntry(from: post, localRecord: localRecords.first { r in r.id == post.id || r.imagePath == post.imageUrl })
                }
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
            onCommentsTap: { commentsEntry = $0 },
            onImageTap: { tapped in
                guard !immersive else { return }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    immersiveFeedInitialPostId = tapped.apiPostId
                }
            },
            onProductTap: { productId in selectedProductId = ProductIdNavigator(id: productId) },
            onPostDeleted: { deleted in
                entries.removeAll { $0.lookbookPostKey == deleted.lookbookPostKey }
            },
            onOpenAnalytics: { analyticsEntry = $0 }
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
    @State private var feedLoading = false
    @State private var feedError: String?
    @State private var feedErrorBannerTitle: String?
    @State private var commentsEntry: LookbookEntry?
    @State private var fullScreenEntry: LookbookEntry?
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

            if let entry = fullScreenEntry {
                LookbookTransparentFullscreenOverlay(entry: entry) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        fullScreenEntry = nil
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .center)),
                    removal: .opacity
                ))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: fullScreenEntry?.id)
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
            .presentationDetents([.fraction(0.44), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(22)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
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
            if let err = feedError, !err.isEmpty {
                FeedNetworkBannerView(message: err, title: feedErrorBannerTitle) {
                    loadFeedFromServer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xl)
    }

    private func topicFeedRow(model: LookbookFeedRowModel) -> some View {
        LookbookFeedRowView(
            entry: model.entry,
            onCommentsTap: { commentsEntry = $0 },
            onImageTap: { tapped in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    fullScreenEntry = tapped
                }
            },
            onProductTap: { productId in selectedProductId = ProductIdNavigator(id: productId) },
            onPostDeleted: { deleted in
                entries.removeAll { $0.lookbookPostKey == deleted.lookbookPostKey }
            },
            onOpenAnalytics: { analyticsEntry = $0 }
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
            let posts = try await service.fetchLookbooks()
            let localRecords = LookbookFeedStore.load()
            await MainActor.run {
                entries = posts.map { post in
                    LookbookEntry(from: post, localRecord: localRecords.first { r in r.id == post.id || r.imagePath == post.imageUrl })
                }
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
                        .padding(.horizontal, Theme.Spacing.md)
                        .tag(idx)
                    }
                    if entry.imageUrls.isEmpty {
                        LookbookFullscreenImage(
                            documentImagePath: entry.documentImagePath,
                            imageName: entry.imageNames.first ?? "",
                            imageUrl: nil
                        )
                        .padding(.horizontal, Theme.Spacing.md)
                        .tag(0)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: entry.imageUrls.count > 1 ? .automatic : .never))
                .frame(maxHeight: UIScreen.main.bounds.height * 0.78)
            }
            .allowsHitTesting(true)

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

private struct LookbookPostCardShimmer: View {
    private let mediaAspect: CGFloat = 4 / 5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 120, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 80, height: 11)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)

            RoundedRectangle(cornerRadius: 0)
                .fill(Theme.Colors.secondaryBackground)
                .aspectRatio(mediaAspect, contentMode: .fit)
                .frame(maxWidth: .infinity)

            HStack(spacing: Theme.Spacing.md) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 48, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 24, height: 16)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 56, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 22, height: 16)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            Divider().background(Theme.Colors.glassBorder.opacity(0.5)).padding(.leading, Theme.Spacing.md)
        }
        .padding(.bottom, lookbookSpacing)
    }
}

// MARK: - Feed row (sandbox-style: full-width 4:5 media, comment / send / save — no like control)
private struct LookbookFeedRowView: View {
    let entry: LookbookEntry
    let onCommentsTap: (LookbookEntry) -> Void
    let onImageTap: (LookbookEntry) -> Void
    let onProductTap: (String) -> Void
    let onPostDeleted: ((LookbookEntry) -> Void)?
    let onOpenAnalytics: ((LookbookEntry) -> Void)?

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var savedLookbookFavorites: SavedLookbookFavoritesStore
    /// Horizontal page for multi-image posts (paged `ScrollView`, not `TabView` — TabView steals taps on the row below).
    @State private var carouselScrollId: Int? = 0
    @State private var sharePayload: LookbookSharePayload?
    @State private var showMutualShareSheet = false
    @State private var shareToChatRecipient: User?

    private let actionIconSize: CGFloat = 20
    private let likeCountSize: CGFloat = 14
    private let avatarSize: CGFloat = 40
    /// Edge-to-edge slot; matches debug feed sandbox (~4:5 portrait).
    private let mediaAspect: CGFloat = 4 / 5

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

    private func styleSubtitle(for entry: LookbookEntry) -> String? {
        guard let first = entry.styles.first, !first.isEmpty else { return nil }
        return StyleSelectionView.displayName(for: first)
    }

    private func openSendForward() {
        guard authService.isAuthenticated else {
            sharePayload = LookbookSharePayload(items: shareItemsForEntry())
            return
        }
        showMutualShareSheet = true
    }

    private var carouselPageIndex: Int {
        carouselScrollId ?? 0
    }

    private var currentDisplayImageURL: String? {
        let urls = entry.imageUrls
        guard !urls.isEmpty else { return nil }
        if urls.count > 1, urls.indices.contains(carouselPageIndex) {
            return urls[carouselPageIndex]
        }
        return urls.first
    }

    private var isPhotoFavorited: Bool {
        savedLookbookFavorites.isSaved(postId: entry.apiPostId)
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
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
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
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)

            lookbookSandboxMediaBlock
                .zIndex(0)
                .clipped()
                .clipShape(Rectangle())

            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                Button {
                    HapticManager.tap()
                    onCommentsTap(entry)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: actionIconSize, weight: .medium))
                            .foregroundStyle(Theme.Colors.primaryText)
                        Text("\(entry.commentsCount)")
                            .font(.system(size: likeCountSize, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.primaryText)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainTappableButtonStyle())

                Button {
                    HapticManager.tap()
                    openSendForward()
                } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: actionIconSize, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainTappableButtonStyle())

                Spacer(minLength: Theme.Spacing.sm)

                Button {
                    HapticManager.tap()
                    _ = savedLookbookFavorites.toggle(entry: entry, imageUrl: currentDisplayImageURL)
                } label: {
                    Image(systemName: isPhotoFavorited ? "bookmark.fill" : "bookmark")
                        .font(.system(size: actionIconSize, weight: .medium))
                        .foregroundStyle(isPhotoFavorited ? Theme.primaryColor : Theme.Colors.primaryText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainTappableButtonStyle())
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            .background(Theme.Colors.background)
            .zIndex(2)

            Rectangle()
                .fill(Theme.Colors.glassBorder.opacity(0.35))
                .frame(height: 0.5)
                .padding(.leading, Theme.Spacing.md)
        }
        .sheet(item: $sharePayload) { payload in
            LookbookActivityView(activityItems: payload.items)
        }
        .sheet(isPresented: $showMutualShareSheet) {
            LookbookSendToShareSheet(excludePosterUsername: entry.posterUsername) { user in
                shareToChatRecipient = user
            }
            .environmentObject(authService)
        }
        .sheet(item: $shareToChatRecipient) { user in
            NavigationStack {
                ChatWithSellerView(
                    seller: user,
                    item: nil,
                    precomposedMessage: forwardMessageText,
                    authService: authService
                )
                .environmentObject(authService)
            }
        }
        .onChange(of: entry.id) { _, _ in
            carouselScrollId = 0
        }
        .onChange(of: entry.imageUrls.count) { _, newCount in
            let idx = carouselPageIndex
            if newCount == 0 {
                carouselScrollId = nil
            } else if idx >= newCount {
                carouselScrollId = max(0, newCount - 1)
            }
        }
    }

    @ViewBuilder
    private var lookbookSandboxMediaBlock: some View {
        let urls = dedupeOrderedValidLookbookURLs(entry.imageUrls)
        if urls.isEmpty {
            // Local document, bundled name, or empty — `lookbookSandboxSingleMedia` resolves each case.
            lookbookSandboxSingleMedia(urlString: "", documentPath: entry.documentImagePath)
        } else if urls.count > 1 {
            Color.clear
                .aspectRatio(mediaAspect, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        let w = max(1, geo.size.width)
                        let h = max(1, geo.size.height)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                LookbookScrollImmediateTouchesAnchor()
                                    .frame(width: 0, height: 0)
                                ForEach(Array(urls.enumerated()), id: \.offset) { idx, urlString in
                                    lookbookSandboxSingleMedia(
                                        urlString: urlString,
                                        documentPath: idx == 0 ? entry.documentImagePath : nil
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
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(Rectangle())
        } else {
            lookbookSandboxSingleMedia(urlString: urls[0], documentPath: entry.documentImagePath)
        }
    }

    @ViewBuilder
    private func lookbookSandboxSingleMedia(urlString: String, documentPath: String?) -> some View {
        Group {
            if let ui = localDocumentUIImage(documentPath) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: urlString), !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        lookbookSandboxMediaPlaceholder
                    case .empty:
                        lookbookSandboxMediaPlaceholder
                            .overlay { ProgressView().scaleEffect(0.7) }
                    @unknown default:
                        lookbookSandboxMediaPlaceholder
                    }
                }
            } else if !entry.imageNames.isEmpty, let ui = UIImage(named: entry.imageNames[0]) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                lookbookSandboxMediaPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(mediaAspect, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            onImageTap(entry)
        }
    }

    private func localDocumentUIImage(_ documentPath: String?) -> UIImage? {
        guard let path = documentPath, !path.isEmpty,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = dir.appending(path: path)
        guard let data = try? Data(contentsOf: url), let ui = UIImage(data: data) else { return nil }
        return ui
    }

    private var lookbookSandboxMediaPlaceholder: some View {
        Theme.Colors.secondaryBackground
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
    }
}

// MARK: - Loads product by id and presents ItemDetailView (for tagged product tap from lookbook feed)
private struct LookbookProductDetailLoader: View {
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

// MARK: - Send lookbook post (recent chats, followers, user search)
private struct LookbookSendToShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    /// Omits this username from suggestions (e.g. post author).
    var excludePosterUsername: String?
    let onPick: (User) -> Void

    @State private var recentUsers: [User] = []
    @State private var followerUsers: [User] = []
    @State private var loading = true
    @State private var errorText: String?
    @State private var searchQuery: String = ""
    @State private var searchResults: [User] = []
    @State private var searchLoading = false
    @State private var searchTask: Task<Void, Never>?

    private let userService = UserService()

    private var meLower: String {
        (authService.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var excludeLower: String {
        (excludePosterUsername ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Prelura Support / similar handles must not receive lookbook forwards from any user.
    private func isBlockedPreluraSupportRecipient(_ user: User) -> Bool {
        let u = user.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !u.isEmpty else { return false }
        let compact = u.replacingOccurrences(of: "_", with: "")
        return compact == "prelurasupport"
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorText, !err.isEmpty {
                    Text(err)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        Section {
                            TextField(L10n.string("Search username"), text: $searchQuery)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                                .onSubmit { Task { await runSearchNow() } }
                        }
                        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                            Section(L10n.string("Search results")) {
                                if searchLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                } else if searchResults.isEmpty {
                                    Text(L10n.string("No users found"))
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                } else {
                                    ForEach(searchResults) { user in
                                        userRow(user)
                                    }
                                }
                            }
                        } else {
                            if !recentUsers.isEmpty {
                                Section(L10n.string("Recent")) {
                                    ForEach(recentUsers) { user in
                                        userRow(user)
                                    }
                                }
                            }
                            if !followerUsers.isEmpty {
                                Section(L10n.string("Followers")) {
                                    ForEach(followerUsers) { user in
                                        userRow(user)
                                    }
                                }
                            }
                            if recentUsers.isEmpty && followerUsers.isEmpty {
                                ContentUnavailableView(
                                    L10n.string("No recipients yet"),
                                    systemImage: "person.crop.circle.badge.questionmark",
                                    description: Text(L10n.string("Message someone, get followers, or search by username."))
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Send to"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Close")) { dismiss() }
                }
            }
            .onChange(of: searchQuery) { _, _ in scheduleSearch() }
            .onDisappear { searchTask?.cancel() }
            .task { await loadRecipients() }
        }
    }

    @ViewBuilder
    private func userRow(_ user: User) -> some View {
        Button {
            guard !isBlockedPreluraSupportRecipient(user) else { return }
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onPick(user)
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                avatar(for: user)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                    Text("@\(user.username)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainTappableButtonStyle())
    }

    @ViewBuilder
    private func avatar(for user: User) -> some View {
        let trimmed = user.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let url = URL(string: trimmed), !trimmed.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Circle().fill(Theme.Colors.secondaryBackground)
                }
            }
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Theme.Colors.secondaryBackground)
                .overlay(
                    Text(String(user.username.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.secondaryText)
                )
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            searchResults = []
            searchLoading = false
            return
        }
        searchLoading = true
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            let latest = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard latest.count >= 2 else {
                searchResults = []
                searchLoading = false
                return
            }
            await runSearch(query: latest)
        }
    }

    @MainActor
    private func runSearchNow() async {
        let latest = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard latest.count >= 2 else {
            searchResults = []
            searchLoading = false
            return
        }
        await runSearch(query: latest)
    }

    @MainActor
    private func runSearch(query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            searchLoading = false
            return
        }
        userService.updateAuthToken(authService.authToken)
        searchLoading = true
        do {
            let found = try await userService.searchUsers(search: query)
            let filtered = found.filter { u in
                let ul = u.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !ul.isEmpty else { return false }
                if isBlockedPreluraSupportRecipient(u) { return false }
                if ul == meLower { return false }
                if !excludeLower.isEmpty, ul == excludeLower { return false }
                return true
            }
            searchResults = filtered
            searchLoading = false
        } catch {
            searchResults = []
            searchLoading = false
        }
    }

    @MainActor
    private func loadRecipients() async {
        guard let me = authService.username?.trimmingCharacters(in: .whitespacesAndNewlines), !me.isEmpty else {
            loading = false
            errorText = L10n.string("Sign in to share.")
            return
        }
        let chat = ChatService()
        chat.updateAuthToken(authService.authToken)
        userService.updateAuthToken(authService.authToken)
        do {
            async let convsTask = chat.getConversations()
            async let followersTask = userService.getFollowers(username: me, pageNumber: 1, pageCount: 200)
            let (convs, followers) = try await (convsTask, followersTask)

            let sortedConvs = convs.sorted { a, b in
                let da = a.lastMessageTime ?? .distantPast
                let db = b.lastMessageTime ?? .distantPast
                return da > db
            }
            var recentOrdered: [User] = []
            var seenRecent = Set<String>()
            for c in sortedConvs {
                let u = c.recipient
                let key = u.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if key.isEmpty || key == meLower { continue }
                if !excludeLower.isEmpty, key == excludeLower { continue }
                if isBlockedPreluraSupportRecipient(u) { continue }
                guard !seenRecent.contains(key) else { continue }
                seenRecent.insert(key)
                recentOrdered.append(u)
                if recentOrdered.count >= 50 { break }
            }

            let sortedFollowers = followers.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            var followerOrdered: [User] = []
            var seenFollow = seenRecent
            for u in sortedFollowers {
                let key = u.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if key.isEmpty || key == meLower { continue }
                if !excludeLower.isEmpty, key == excludeLower { continue }
                if isBlockedPreluraSupportRecipient(u) { continue }
                guard !seenFollow.contains(key) else { continue }
                seenFollow.insert(key)
                followerOrdered.append(u)
            }

            recentUsers = recentOrdered
            followerUsers = followerOrdered
            loading = false
            errorText = nil
        } catch {
            loading = false
            errorText = L10n.userFacingError(error)
        }
    }
}

// MARK: - Comments sheet
struct LookbookCommentsSheet: View {
    let entry: LookbookEntry
    var onCountChanged: ((Int) -> Void)? = nil
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [ServerLookbookComment] = []
    @State private var draft: String = ""
    @State private var loading = false
    @State private var sending = false

    var body: some View {
            VStack(spacing: 0) {
            HStack {
                Text(L10n.string("Comments"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                Button(L10n.string("Done")) { dismiss() }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.primaryColor)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xs)

                if loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.lg)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        ForEach(comments) { c in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Circle()
                                    .fill(Theme.Colors.secondaryBackground)
                                    .frame(width: 32, height: 32)
                                    .overlay(Text(String(c.username.prefix(1)).uppercased())
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.secondaryText))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.username)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.Colors.primaryText)
                                    HashtagColoredText(text: c.text)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.md)
                }

            HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
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
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background)
        }
        .background(Theme.Colors.background)
            .task { await loadComments() }
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

    private func sendComment() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        Task {
            do {
                let result = try await service.addComment(postId: entry.apiPostId, text: text)
                await MainActor.run {
                    draft = ""
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
                ZStack {
                    Theme.Colors.secondaryBackground
                    ProgressView()
                }
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

    /// Tags with a local product snapshot count as tagged products.
    private var taggedProductCount: Int {
        guard let tags = entry.tags, let snaps = entry.productSnapshots else { return 0 }
        let ids = tags.map(\.productId).filter { snaps[$0] != nil }
        return Set(ids).count
    }

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

    private var attributed: AttributedString {
        var result = AttributedString(text)
        let pattern = "#\\w+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if let range = Range(match.range, in: result) {
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

// MARK: - Search sheet (filter by search text in username/caption)
struct LookbookSearchSheet: View {
    @Binding var searchText: String
    let entries: [LookbookEntry]
    @Environment(\.dismiss) private var dismiss

    private var filteredBySearch: [LookbookEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return entries }
        return entries.filter { $0.posterUsername.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.secondaryText)
                    TextField(L10n.string("Search lookbooks"), text: $searchText)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .autocorrectionDisabled()
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(10)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)

                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(filteredBySearch) { entry in
                            HStack(spacing: Theme.Spacing.sm) {
                                LookbookEntryThumbnail(entry: entry)
                                    .frame(width: 50, height: 50)
                                    .clipped()
                                    .cornerRadius(8)
                                Text(entry.posterUsername)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                    }
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done")) { dismiss() }
                        .foregroundColor(Theme.primaryColor)
                }
            }
        }
    }
}

extension LookbookEntry: Equatable {
    static func == (lhs: LookbookEntry, rhs: LookbookEntry) -> Bool { lhs.id == rhs.id }
}

extension LookbookEntry: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#if DEBUG
struct LookbookView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LookbookView()
                .environmentObject(AuthService())
        }
    }
}
#endif
