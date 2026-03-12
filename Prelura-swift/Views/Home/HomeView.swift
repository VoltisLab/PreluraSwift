import SwiftUI
import Shimmer

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var tabCoordinator: TabCoordinator
    @StateObject private var viewModel = HomeViewModel()
    @State private var searchText: String = ""
    @State private var scrollPosition: String? = "home_top"
    @State private var showAIChat: Bool = false

    let categories = ["All", "Women", "Men", "Kids", "Toddlers"]

    private let topId = "home_top"

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.filteredItems.isEmpty {
                FeedShimmerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 1).id(topId)
                            FeedSearchField(
                                text: $searchText,
                                placeholder: L10n.string("Search items, brands or colours"),
                                onSubmit: { viewModel.searchWithParsed($0) },
                                onAITap: { showAIChat = true },
                                topPadding: Theme.Spacing.xs
                            )

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
                            productGridSection
                        }
                    }
                    .scrollPosition(id: $scrollPosition, anchor: .top)
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
        .onChange(of: scrollPosition) { _, new in
            tabCoordinator.reportAtTop(tab: 0, isAtTop: new == topId)
        }
        .background(Theme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(viewModel.isLoading && viewModel.filteredItems.isEmpty)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image("PreluraLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 26)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: Theme.Spacing.sm) {
                    NavigationLink(destination: NotificationsListView()) {
                        Image(systemName: "bell")
                            .foregroundColor(Theme.Colors.primaryText)
                            .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HapticTapButtonStyle())
                }
            }
        }
        .refreshable {
            await viewModel.refreshAsync()
        }
        .background(
            NavigationLink(destination: AIChatView(viewModel: viewModel).environmentObject(authService), isActive: $showAIChat) {
                EmptyView()
            }
            .hidden()
        )
    }

    // MARK: - Category Filters
    private var categoryFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
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
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
    
    // MARK: - Product Grid
    private var productGridSection: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm)
            ],
            alignment: .leading,
            spacing: Theme.Spacing.md,
            pinnedViews: []
        ) {
            ForEach(viewModel.filteredItems) { item in
                ZStack(alignment: .topLeading) {
                    NavigationLink(value: AppRoute.itemDetail(item)) {
                        HomeItemCard(item: item, onLikeTap: nil, hideLikeButton: true)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .buttonStyle(PlainButtonStyle())
                    // Like button outside NavigationLink so taps go to button; overlay aligned over image (seller row then image)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 28)
                        VStack(spacing: 0) {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: { viewModel.toggleLike(productId: item.productId ?? "") }) {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: item.isLiked ? "heart.fill" : "heart")
                                            .font(.system(size: 14, weight: .medium))
                                        Text("\(item.likeCount)")
                                            .font(Theme.Typography.caption)
                                    }
                                    .foregroundColor(item.isLiked ? .red : .white)
                                    .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .padding(.vertical, 6)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.like() }))
                                .padding(Theme.Spacing.xs)
                            }
                        }
                        .aspectRatio(1.0/1.3, contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .allowsHitTesting(true)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .id("\(item.id)-\(item.isLiked)-\(item.likeCount)")
                .onAppear {
                    // Load more when the last few items appear
                    if item.id == viewModel.filteredItems.suffix(4).first?.id {
                        viewModel.loadMore()
                    }
                }
            }
            
            // Loading indicator at bottom
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .gridCellColumns(2)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }
}

// MARK: - Home Item Card
struct HomeItemCard: View {
    let item: Item
    var onLikeTap: (() -> Void)? = nil
    /// When true, the like overlay is hidden (caller draws it outside NavigationLink so it's tappable).
    var hideLikeButton: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
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
            .padding(.bottom, Theme.Spacing.xs * 1.5)
            
            // Image with like count overlay - fixed size container
            GeometryReader { geometry in
                let imageWidth = geometry.size.width
                let imageHeight = imageWidth * 1.3 // 1:1.3 width:height ratio
                
                ZStack(alignment: .bottomTrailing) {
                    // Background container - fixed size
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
                    
                    // Product Image - fixed size container; retries once on load failure (e.g. in chat)
                    RetryAsyncImage(
                        url: item.imageURLs.first.flatMap { URL(string: $0) },
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
                    
                    if !hideLikeButton {
                        likeButtonContent
                    }
                }
            }
            .aspectRatio(1.0/1.3, contentMode: .fit)
            
            // Product details section with consistent spacing
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Brand (purple)
                if let brand = item.brand {
                    Text(brand)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                        .padding(.top, Theme.Spacing.sm)
                }
                
                // Title
                Text(item.title)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
                
                // Condition
                Text(item.formattedCondition)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                // Price
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
            }
        }
    }
    
    @ViewBuilder
    private var likeButtonContent: some View {
        Button(action: { onLikeTap?() }) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: item.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .medium))
                Text("\(item.likeCount)")
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(item.isLiked ? .red : .white)
            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.like() }))
        .padding(Theme.Spacing.xs)
    }
}

#Preview {
    HomeView(tabCoordinator: TabCoordinator())
        .preferredColorScheme(.dark)
}
