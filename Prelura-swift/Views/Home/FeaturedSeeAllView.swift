import SwiftUI

/// Full staff-curated featured grid; top banner matches Discover Try Cart strip (150pt hero + dim overlay) with WEARHOUSE artwork.
struct FeaturedSeeAllView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var items: [Item] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showGuestSignInPrompt = false

    private let productService = ProductService()
    private static let bottomClearance: CGFloat = 112

    var body: some View {
        Group {
            if isLoading {
                FeedShimmerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        featuredHeroBanner
                        if let err = errorMessage, !err.isEmpty {
                            FeedNetworkBannerView(message: err, onTryAgain: {
                                Task { await load() }
                            })
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.top, Theme.Spacing.md)
                        }
                        featuredGrid
                        Color.clear.frame(height: Self.bottomClearance)
                    }
                }
                .background(Theme.Colors.background)
            }
        }
        .navigationTitle(L10n.string("Featured"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Colors.background)
        .preluraNavigationBarChrome()
        .task {
            productService.updateAuthToken(authService.isGuestMode ? nil : authService.authToken)
            await load()
        }
        .refreshable { await load() }
        .onChange(of: authService.isGuestMode) { _, _ in
            productService.updateAuthToken(authService.isGuestMode ? nil : authService.authToken)
        }
        .onChange(of: authService.authToken) { _, _ in
            if !authService.isGuestMode { productService.updateAuthToken(authService.authToken) }
        }
        .fullScreenCover(isPresented: $showGuestSignInPrompt) {
            GuestSignInPromptView()
                .wearhouseSheetContentColumnIfWide()
        }
    }

    /// Same dimensions and treatment as `DiscoverView.tryCartBanner` (image fill150pt +40% black scrim); static artwork instead of typewriter.
    private var featuredHeroBanner: some View {
        ZStack {
            Image("FeaturedWearhouseBanner")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()
            Color.black.opacity(0.4)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var featuredGrid: some View {
        LazyVGrid(
            columns: WearhouseLayoutMetrics.productGridColumns(
                horizontalSizeClass: horizontalSizeClass,
                spacing: Theme.Spacing.sm
            ),
            alignment: .leading,
            spacing: Theme.Spacing.md,
            pinnedViews: []
        ) {
            ForEach(items) { item in
                featuredProductCell(item: item)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }

    @ViewBuilder
    private func featuredProductCell(item: Item) -> some View {
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
                            else { toggleLike(productId: item.productId ?? "") }
                        })
                        .padding(Theme.Spacing.xs)
                    }
                }
                .aspectRatio(1.0 / 1.3, contentMode: .fit)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .allowsHitTesting(true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .id(item.id)
    }

    private func toggleLike(productId: String) {
        guard !productId.isEmpty, let idx = items.firstIndex(where: { $0.productId == productId }) else { return }
        let item = items[idx]
        let newLiked = !item.isLiked
        let optimistic = item.with(likeCount: max(0, item.likeCount + (newLiked ? 1 : -1)), isLiked: newLiked)
        items[idx] = optimistic
        Task {
            do {
                let result = try await productService.toggleLike(productId: productId, isLiked: newLiked)
                await MainActor.run {
                    guard let i = items.firstIndex(where: { $0.productId == productId }) else { return }
                    let count = result.likeCount ?? optimistic.likeCount
                    items[i] = item.with(likeCount: count, isLiked: result.isLiked)
                }
            } catch {
                await MainActor.run {
                    errorMessage = L10n.userFacingError(error)
                }
            }
        }
    }

    private func load() async {
        await MainActor.run { isLoading = true }
        productService.updateAuthToken(authService.isGuestMode ? nil : authService.authToken)
        do {
            let raw = try await productService.getDiscoverFeaturedProducts()
            await MainActor.run {
                items = HomeViewModel.allFeaturedItems(from: raw)
                isLoading = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = L10n.userFacingError(error)
                isLoading = false
            }
        }
    }
}
