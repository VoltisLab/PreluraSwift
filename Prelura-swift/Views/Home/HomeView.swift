import SwiftUI
import Shimmer

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var bellUnreadStore: BellUnreadStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var tabCoordinator: TabCoordinator
    @StateObject private var viewModel = HomeViewModel()
    @State private var showAIChat: Bool = false
    @State private var showGuestSignInPrompt: Bool = false
    /// Programmatic push avoids `NavigationLink` in the toolbar, which often skips redraws for the red dot.
    @State private var showNotificationsList: Bool = false
    private let homeAISearch = AISearchService()

    let categories = ["All", "Women", "Men", "Boys", "Girls", "Toddlers"]

    private let topId = "home_top"
    /// Band for “at top” when the feed is one continuous `ScrollView` (anchor sits just below the search header).
    private static let feedScrollTopSnap: CGFloat = 12
    /// Cap horizontal chip `ScrollView` height so category pills don’t expand vertically in the header.
    private static let categoryChipScrollMaxHeight: CGFloat = 44
    /// Scrollable tail so the last grid row can sit above the floating tab bar + home indicator (see `contentMargins` note on `ScrollView`).
    private static let feedScrollBottomClearance: CGFloat = 112
    /// Space below category chips before Featured / grid (was xs and felt cramped against “Featured”).
    private static let chipRowBottomSpacing: CGFloat = Theme.Spacing.md

    var body: some View {
        homeChromeAndLifecycle
    }

    private var homeNavChromeStack: some View {
        homeMainContent
            .background(Theme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    WearhouseWordmarkView(style: .toolbar)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 0) {
                        Button {
                            showAIChat = true
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.system(size: Theme.SearchField.iconPointSize, weight: .medium))
                                .foregroundStyle(Theme.primaryColor)
                                .frame(width: 36, height: Theme.SearchField.trailingActionSlotHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(HapticTapButtonStyle())
                        .accessibilityLabel(L10n.string("AI"))
                        homeNotificationsBellLink
                    }
                }
            }
            // Same system search as Debug (`appStandardSearchable` → `navigationBarDrawer`); smooth nav-bar transitions are handled by SwiftUI, not a custom toolbar field.
            .appStandardSearchable(
                text: $viewModel.searchText,
                prompt: Text(L10n.string("Search items, brands or styles"))
            )
            .onSubmit(of: .search) {
                let q = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let parsed = homeAISearch.parse(query: q)
                viewModel.searchWithParsed(parsed)
            }
            .onChange(of: viewModel.searchText) { old, new in
                if new.isEmpty && !old.isEmpty {
                    viewModel.reloadFeedAfterSearchEmptied()
                }
            }
            .preluraNavigationBarChrome()
    }

    private var homeChromeAndLifecycle: some View {
        homeNavChromeStack
            .onAppear {
                StartupTiming.mark("HomeView.onAppear")
                tabCoordinator.homeSameTabTapHandler = {
                    if !viewModel.searchText.isEmpty {
                        viewModel.searchText = ""
                        return true
                    }
                    return false
                }
                viewModel.updateAuthToken(authService.isGuestMode ? nil : authService.authToken)
                bellUnreadStore.scheduleRefresh(authService: authService)
            }
            .onChange(of: authService.isGuestMode) { _, _ in
                viewModel.updateAuthToken(authService.isGuestMode ? nil : authService.authToken)
                if authService.isGuestMode { viewModel.loadData() }
                bellUnreadStore.scheduleRefresh(authService: authService)
            }
            .onChange(of: authService.authToken) { _, _ in
                if !authService.isGuestMode { viewModel.updateAuthToken(authService.authToken) }
                bellUnreadStore.scheduleRefresh(authService: authService)
            }
            .onChange(of: tabCoordinator.inboxListRefreshNonce) { _, _ in
                bellUnreadStore.scheduleRefresh(authService: authService)
            }
            .onReceive(NotificationCenter.default.publisher(for: .wearhouseInAppNotificationsDidChange)) { _ in
                bellUnreadStore.scheduleRefresh(authService: authService)
            }
            .onChange(of: tabCoordinator.selectedTab) { _, tab in
                if tab == 0 {
                    bellUnreadStore.scheduleRefresh(authService: authService)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    bellUnreadStore.scheduleRefresh(authService: authService)
                }
            }
            .navigationDestination(isPresented: $showNotificationsList) {
                NotificationsListView()
                    .environmentObject(authService)
                    .environmentObject(bellUnreadStore)
            }
            .background(
                NavigationLink(destination: AIChatView(viewModel: viewModel).environmentObject(authService), isActive: $showAIChat) {
                    EmptyView()
                }
                .hidden()
            )
            .fullScreenCover(isPresented: $showGuestSignInPrompt) {
                GuestSignInPromptView()
                    .wearhouseSheetContentColumnIfWide()
            }
    }

    /// Search, closest-match hint, and category chips - part of the main vertical scroll (no overlay `ZStack`: that layout caused scroll clipping glitches and stray text fragments above the grid).
    @ViewBuilder
    private var homePinnedHeader: some View {
        VStack(spacing: 0) {
            if let hint = viewModel.searchClosestMatchHint {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.primaryColor)
                    Text(hint)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            categoryFiltersSection
        }
        .padding(.top, 0)
        .background(Theme.Colors.background)
    }

    @ViewBuilder
    private var homeMainContent: some View {
        if viewModel.isLoading {
            FeedShimmerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 1).id(topId)
                        homePinnedHeader
                        featuredSection
                        productGridSection
                        Color.clear.frame(height: Self.feedScrollBottomClearance)
                    }
                }
                .background(Theme.Colors.background)
                .contentMargins(.top, 0, for: .scrollContent)
                .scrollBounceBehavior(.always, axes: .vertical)
                .refreshable {
                    await viewModel.refreshAsync()
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    -geo.contentOffset.y
                } action: { _, scrollMinY in
                    tabCoordinator.reportAtTop(tab: 0, isAtTop: scrollMinY > -Self.feedScrollTopSnap)
                }
                .overlay {
                    if let err = viewModel.errorMessage, !err.isEmpty {
                        Group {
                            if viewModel.errorBannerTitle != nil {
                                VStack {
                                    Spacer()
                                    FeedErrorSnackbarView(onTryAgain: {
                                        Task { await viewModel.refreshAsync() }
                                    })
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.bottom, 28)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else {
                                FeedNetworkBannerView(message: err, title: nil) {
                                    Task { await viewModel.refreshAsync() }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: viewModel.errorMessage)
                .onAppear {
                    tabCoordinator.reportAtTop(tab: 0, isAtTop: true)
                    tabCoordinator.registerScrollToTop(tab: 0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(topId, anchor: .top)
                        }
                    }
                    tabCoordinator.registerRefresh(tab: 0) {
                        Task { await viewModel.refreshAsync() }
                    }
                }
            }
        }
    }

    private var homeNotificationsBellLink: some View {
        Button {
            showNotificationsList = true
        } label: {
            HomeToolbarNotificationBellVisual(unreadCount: bellUnreadStore.unreadCount)
                .contentShape(Rectangle())
        }
        .buttonStyle(HapticTapButtonStyle())
        .accessibilityLabel(L10n.string("Notifications"))
        .accessibilityValue(
            bellUnreadStore.unreadCount > 0
                ? String(format: "%d unread", bellUnreadStore.unreadCount)
                : ""
        )
    }

    // MARK: - Category Filters
    private var categoryFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                ForEach(categories, id: \.self) { category in
                    CategoryFilterButton(
                        title: L10n.string(category),
                        isSelected: viewModel.selectedCategory == category,
                        action: {
                            viewModel.filterByCategory(category)
                        }
                    )
                }
            }
            .padding(.leading, Theme.Spacing.md)
            .padding(.trailing, Theme.Spacing.xl)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxHeight: Self.categoryChipScrollMaxHeight, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 0)
        .padding(.bottom, Self.chipRowBottomSpacing)
    }

    @ViewBuilder
    private func homeProductCore(item: Item, trackLoadMore: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            NavigationLink(value: AppRoute.itemDetail(item)) {
                HomeItemCard(item: item, onLikeTap: nil, hideLikeButton: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .buttonStyle(PlainTappableButtonStyle())
            VStack(spacing: 0) {
                Color.clear.frame(height: 28)
                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        Spacer()
                        LikeButtonView(isLiked: item.isLiked, likeCount: item.likeCount, action: {
                            if authService.isGuestMode { showGuestSignInPrompt = true }
                            else { viewModel.toggleLike(productId: item.productId ?? "") }
                        })
                        .padding(Theme.Spacing.xs)
                    }
                }
                .aspectRatio(1.0/1.3, contentMode: .fit)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .allowsHitTesting(true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // Stable identity: including like state forced `LazyVGrid` to destroy/recreate cells and redraw strikethrough/text outside clips while scrolling.
        .id(item.id)
        .onAppear {
            guard trackLoadMore else { return }
            if item.id == viewModel.filteredItems.suffix(4).first?.id {
                viewModel.loadMore()
            }
        }
    }

    // MARK: - Featured (staff-curated)
    private var featuredSection: some View {
        Group {
            if !viewModel.featuredItems.isEmpty && viewModel.searchText.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Text(L10n.string("Featured"))
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primaryText)
                        Spacer(minLength: 0)
                        NavigationLink {
                            FeaturedSeeAllView()
                                .environmentObject(authService)
                        } label: {
                            Text(L10n.string("See all"))
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.primaryColor)
                        }
                        .buttonStyle(HapticTapButtonStyle())
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: Theme.Spacing.sm) {
                            ForEach(viewModel.featuredItems) { item in
                                homeProductCore(item: item, trackLoadMore: false)
                                    .frame(width: 168)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, Theme.Spacing.sm)
            }
        }
    }
    
    // MARK: - Product Grid
    private var productGridSection: some View {
        LazyVGrid(
            columns: WearhouseLayoutMetrics.productGridColumns(
                horizontalSizeClass: horizontalSizeClass,
                spacing: Theme.Spacing.sm
            ),
            alignment: .leading,
            spacing: Theme.Spacing.md,
            pinnedViews: []
        ) {
            let trimmedQuery = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if viewModel.filteredItems.isEmpty && !viewModel.isLoading && !trimmedQuery.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Text(String(format: L10n.string("No results for \"%@\""), trimmedQuery))
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                    Text(L10n.string("Pull down to refresh"))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    Button {
                        Task { await viewModel.refreshAsync() }
                    } label: {
                        Text(L10n.string("Try again"))
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
                .gridCellColumns(WearhouseLayoutMetrics.productGridColumnCount(horizontalSizeClass: horizontalSizeClass))
            }

            ForEach(viewModel.filteredItems) { item in
                homeProductCore(item: item, trackLoadMore: true)
            }

            // Loading indicator at bottom
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .gridCellColumns(WearhouseLayoutMetrics.productGridColumnCount(horizontalSizeClass: horizontalSizeClass))
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, 0)
        .padding(.bottom, Theme.Spacing.md)
    }
}

// MARK: - Home Item Card
struct HomeItemCard: View {
    let item: Item
    var onLikeTap: (() -> Void)? = nil
    /// When true, the product image uses a 1:1 slot (e.g. Favourites grid). Default is a slightly taller portrait slot. Ignored when `naturalThumbnailAspect` is true.
    var squareImageSlot: Bool = false
    /// When true, thumbnail uses full cell width and keeps the image aspect ratio (e.g. Favourites → Products).
    var naturalThumbnailAspect: Bool = false
    /// When true, the like overlay is hidden (caller draws it outside NavigationLink so it's tappable).
    var hideLikeButton: Bool = false
    /// When true, show "Add to bag" / "Remove" (secondary border). Tap adds via onAddToBag or removes via onRemove.
    var showAddToBag: Bool = false
    var onAddToBag: (() -> Void)? = nil
    /// When true, show "Remove" instead of "Add to bag" and call onRemove.
    var isInBag: Bool = false
    var onRemove: (() -> Void)? = nil
    /// Shop All Retro: shorter white-outline control aligned with filter row height.
    var addToBagChromeStyle: BorderGlassButton.ChromeStyle = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Seller info (avatar + username) above image
            HStack(spacing: Theme.Spacing.xs) {
                // Avatar
                if let avatarURL = item.seller.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .shimmering()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Circle()
                                .fill(Theme.primaryColor)
                                .overlay(
                                    Text(String((item.seller.username.isEmpty ? "U" : item.seller.username).prefix(1)).uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        @unknown default:
                            Circle()
                                .fill(Theme.primaryColor)
                                .overlay(
                                    Text(String((item.seller.username.isEmpty ? "U" : item.seller.username).prefix(1)).uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Theme.primaryColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(String((item.seller.username.isEmpty ? "U" : item.seller.username).prefix(1)).uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                // Username
                Text(item.seller.username.isEmpty ? "User" : item.seller.username)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.xs)
            
            // Image: avoid a bare `GeometryReader` as the grid cell’s main flexible child (it confuses `LazyVGrid` sizing and can cause scroll clipping glitches). Resolve size from a fixed aspect-ratio slot, then measure inside the overlay - unless we preserve listing aspect ratio at full width (`naturalThumbnailAspect`).
            Group {
                if naturalThumbnailAspect {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if item.isMysteryBox {
                                MysteryBoxAnimatedMediaView()
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            } else {
                                RetryAsyncImage(
                                    url: item.thumbnailURLForChrome.flatMap { URL(string: $0) },
                                    width: 1,
                                    height: 1,
                                    cornerRadius: 0,
                                    fillsFixedFrame: false,
                                    placeholder: {
                                        ImageShimmerPlaceholderFilled(cornerRadius: 0)
                                    },
                                    failurePlaceholder: {
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(Theme.primaryColor.opacity(0.5))
                                    }
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Theme.primaryColor.opacity(0.3),
                                                    Theme.primaryColor.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                            }
                        }
                        if !hideLikeButton {
                            likeButtonContent
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .compositingGroup()
                    .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
                } else {
                    Color.clear
                        .aspectRatio(squareImageSlot ? 1.0 : 1.0 / 1.3, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            GeometryReader { geometry in
                                let imageWidth = geometry.size.width
                                let imageHeight = geometry.size.height
                                ZStack(alignment: .bottomTrailing) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Theme.primaryColor.opacity(0.3),
                                                    Theme.primaryColor.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: imageWidth, height: imageHeight)
                                    Group {
                                        if item.isMysteryBox {
                                            MysteryBoxAnimatedMediaView()
                                                .frame(width: imageWidth, height: imageHeight)
                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        } else {
                                            RetryAsyncImage(
                                                url: item.thumbnailURLForChrome.flatMap { URL(string: $0) },
                                                width: imageWidth,
                                                height: imageHeight,
                                                cornerRadius: 8,
                                                placeholder: {
                                                    ImageShimmerPlaceholderFilled(cornerRadius: 8)
                                                        .frame(width: imageWidth, height: imageHeight)
                                                },
                                                failurePlaceholder: {
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(Theme.primaryColor.opacity(0.5))
                                                        .frame(width: imageWidth, height: imageHeight)
                                                }
                                            )
                                        }
                                    }
                                    if !hideLikeButton {
                                        likeButtonContent
                                    }
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .compositingGroup()
                        .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
                }
            }
            
            // Product details - tight to image (spacing was visually too large)
            VStack(alignment: .leading, spacing: 4) {
                // Brand (purple)
                if let brandLine = item.brandLineForProductGrid(multipleBrandsLabel: L10n.string("Multiple brands")) {
                    Text(brandLine)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                        .padding(.top, 4)
                }
                
                // Title
                Text(item.title)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
                    .padding(.top, item.brandLineForProductGrid(multipleBrandsLabel: L10n.string("Multiple brands")) == nil ? 4 : 0)
                
                // Condition
                Text(item.formattedCondition)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                // Price (clipped row: strikethrough decoration can paint slightly outside the line’s bounds during scroll)
                HStack(spacing: Theme.Spacing.xs) {
                    if let originalPrice = item.originalPrice {
                        Text(item.formattedOriginalPrice)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .strikethrough()
                    }
                    
                    Text(item.formattedPrice)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    if let discount = item.discountPercentage {
                        Text("\(discount)% Off")
                            .font(Theme.Typography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
            
            if showAddToBag {
                if isInBag, let onRemove = onRemove {
                    BorderGlassButton(L10n.string("Remove"), icon: "minus.circle", chromeStyle: addToBagChromeStyle, layout: .compact, action: onRemove)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xs)
                } else if let onAddToBag = onAddToBag {
                    BorderGlassButton(L10n.string("Add to bag"), icon: "bag.badge.plus", chromeStyle: addToBagChromeStyle, layout: .compact, action: onAddToBag)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xs)
                }
            }
        }
    }
    
    @ViewBuilder
    private var likeButtonContent: some View {
        LikeButtonView(isLiked: item.isLiked, likeCount: item.likeCount, action: { onLikeTap?() })
            .padding(Theme.Spacing.xs)
    }
}

#Preview {
    HomeView(tabCoordinator: TabCoordinator())
        .environmentObject(AuthService())
        .environmentObject(BellUnreadStore())
        .preferredColorScheme(.dark)
}
