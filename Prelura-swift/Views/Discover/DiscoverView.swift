import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel: DiscoverViewModel
    @State private var searchText: String = ""
    @State private var selectedBrand: String? = nil
    
    init() {
        // Initialize with nil, will be updated in onAppear
        _viewModel = StateObject(wrappedValue: DiscoverViewModel(authService: nil))
    }
    
    let brands = ["New Look", "Nike", "Next", "adidas", "Bo", "Ralph Lauren", "Prettylittlething", "River Island", "Zara", "H&M", "ASOS", "Topshop", "Mango", "Bershka", "Pull & Bear", "Stradivarius", "Massimo Dutti", "COS", "Arket", "Weekday"]
    
    // Category image URLs - these should come from API in real app
    let categoryImages: [String: String] = [
        "Women": "https://i.pravatar.cc/150?img=47",
        "Men": "https://i.pravatar.cc/150?img=12",
        "Boys": "https://i.pravatar.cc/150?img=33",
        "Girls": "https://i.pravatar.cc/150?img=20"
    ]
    
    var body: some View {
        GeometryReader { geometry in
                ScrollView {
                    if viewModel.isLoading && viewModel.discoverItems.isEmpty {
                        DiscoverShimmerView()
                            .frame(width: geometry.size.width)
                    } else {
                        VStack(spacing: 0) {
                            DiscoverSearchField(
                                text: $searchText,
                                placeholder: "Search members",
                                topPadding: Theme.Spacing.xs
                            )
                            .padding(.trailing, Theme.Spacing.sm)
                            VStack(spacing: 0) {
                                brandFiltersSection
                                SectionDivider()
                                categoryCirclesSection
                                SectionDivider()
                                recentlyViewedSection
                                SectionDivider()
                                brandsYouLoveSection
                                SectionDivider()
                                topShopsSection
                                SectionDivider()
                                shopBargainsSection
                                SectionDivider()
                                onSaleSection
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.top, Theme.Spacing.sm)
                            .padding(.bottom, Theme.Spacing.lg)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Theme.Spacing.md) {
                        Button(action: {}) {
                            Image(systemName: "heart")
                        }
                        Button(action: {}) {
                            Image(systemName: "bell")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshAsync()
            }
        .onAppear {
            if authService.isAuthenticated {
                viewModel.updateAuthToken(authService.authToken)
                viewModel.refresh()
            }
        }
        .onChange(of: authService.isAuthenticated) { oldValue, isAuthenticated in
            if isAuthenticated {
                viewModel.updateAuthToken(authService.authToken)
                viewModel.refresh()
            }
        }
        .onChange(of: authService.authToken) { oldToken, newToken in
            // Update token and refresh when token changes
            if authService.isAuthenticated {
                viewModel.updateAuthToken(newToken)
                viewModel.refresh()
            }
        }
    }
    
    // MARK: - Brand Filters (2 rows, up to 20 items)
    private var brandFiltersSection: some View {
        let brandsToShow = Array(brands.prefix(20))
        let firstRow = Array(brandsToShow.prefix(10))
        let secondRow = Array(brandsToShow.suffix(from: min(10, brandsToShow.count)))
        
        return VStack(spacing: Theme.Spacing.sm) {
            // First row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(firstRow, id: \.self) { brand in
                        BrandFilterPill(
                            brand: brand,
                            isSelected: selectedBrand == brand,
                            action: {
                                selectedBrand = selectedBrand == brand ? nil : brand
                            }
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            
            // Second row (if needed)
            if !secondRow.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(secondRow, id: \.self) { brand in
                            BrandFilterPill(
                                brand: brand,
                                isSelected: selectedBrand == brand,
                                action: {
                                    selectedBrand = selectedBrand == brand ? nil : brand
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
            }
        }
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.sm)
    }
    
    // MARK: - Category Circles
    private var categoryCirclesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.lg) {
                ForEach(["Women", "Men", "Boys", "Girls"], id: \.self) { category in
                    CategoryCircle(
                        category: category,
                        imageURL: categoryImages[category]
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.md)
    }
    
    // MARK: - Recently Viewed Section (Products)
    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Recently viewed")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Spacer()
                
                NavigationLink(destination: FilteredProductsView(title: "Recently viewed", filterType: .recentlyViewed, authService: authService)) {
                    Text("See All")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.recentlyViewedItems) { item in
                        NavigationLink(value: AppRoute.itemDetail(item)) {
                            DiscoverItemCard(item: item)
                                .frame(width: 160)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
    
    // MARK: - Brands You Love Section
    private var brandsYouLoveSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Brands You Love")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    Text("Recommended from your favorite brands")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                NavigationLink(destination: FilteredProductsView(title: "Brands You Love", filterType: .brandsYouLove, authService: authService)) {
                    Text("See All")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.brandsYouLoveItems) { item in
                        NavigationLink(value: AppRoute.itemDetail(item)) {
                            DiscoverItemCard(item: item)
                                .frame(width: 160)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
    
    // MARK: - Top Shops Section
    private var topShopsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Top Shops")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text("Buy from trusted and popular vendors")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.topShops) { shop in
                        VStack(spacing: Theme.Spacing.xs) {
                            // Shop avatar
                            if let avatarURL = shop.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        Circle()
                                            .fill(Theme.primaryColor)
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                ProgressView()
                                                    .tint(.white)
                                            )
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Theme.primaryColor)
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                Text(String(shop.username.prefix(1)).uppercased())
                                                    .font(.system(size: 32, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    @unknown default:
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Theme.primaryColor)
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                Text(String(shop.username.prefix(1)).uppercased())
                                                    .font(.system(size: 32, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.primaryColor)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(String(shop.username.prefix(1)).uppercased())
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            Text(shop.username)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
    
    // MARK: - Shop Bargains Section
    private var shopBargainsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Shop Bargains")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    Text("Steals under £15")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                NavigationLink(destination: FilteredProductsView(title: "Shop Bargains", filterType: .shopBargains, authService: authService)) {
                    Text("See All")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.shopBargainsItems) { item in
                        NavigationLink(value: AppRoute.itemDetail(item)) {
                            DiscoverItemCard(item: item)
                                .frame(width: 160)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
    
    // MARK: - On Sale Section
    private var onSaleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("On Sale")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    Text("Discounted items")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                NavigationLink(destination: FilteredProductsView(title: "On Sale", filterType: .onSale, authService: authService)) {
                    Text("See All")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.onSaleItems) { item in
                        NavigationLink(value: AppRoute.itemDetail(item)) {
                            DiscoverItemCard(item: item)
                                .frame(width: 160)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
    
}

// MARK: - Supporting Views

struct BrandFilterPill: View {
    let brand: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PillTag(title: brand, isSelected: isSelected, accentWhenUnselected: true, action: action)
    }
}

struct CategoryCircle: View {
    let category: String
    let imageURL: String?
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // Circular image - using URL if available
            if let imageURL = imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    Group {
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 85, height: 85)
                                .overlay(
                                    ProgressView()
                                        .tint(Theme.primaryColor)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 85, height: 85)
                                .clipShape(Circle())
                        case .failure:
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 85, height: 85)
                                .overlay(
                                    Image(systemName: categoryIcon(for: category))
                                        .font(.system(size: 24))
                                        .foregroundColor(Theme.primaryColor)
                                )
                        @unknown default:
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 85, height: 85)
                                .overlay(
                                    Image(systemName: categoryIcon(for: category))
                                        .font(.system(size: 24))
                                        .foregroundColor(Theme.primaryColor)
                                )
                        }
                    }
                }
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            } else {
                Circle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 85, height: 85)
                    .overlay(
                        Image(systemName: categoryIcon(for: category))
                            .font(.system(size: 24))
                            .foregroundColor(Theme.primaryColor)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
            
            Text(category)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.primaryText)
        }
        .frame(width: 80)
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Women": return "person.fill"
        case "Men": return "person.fill"
        case "Boys": return "person.2.fill"
        case "Girls": return "person.2.fill"
        default: return "person.fill"
        }
    }
}

struct DiscoverItemCard: View {
    let item: Item
    
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
                                .fill(Theme.primaryColor)
                                .overlay(
                                    Text(String((item.seller.username.isEmpty ? "U" : item.seller.username).prefix(1)).uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                )
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
            
            // Image with like count overlay - matching feed/profile design
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
                    
                    // Product Image - fixed size container to prevent movement
                    Group {
                        if let firstImageURL = item.imageURLs.first, let url = URL(string: firstImageURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(Theme.primaryColor.opacity(0.5))
                                        .frame(width: imageWidth, height: imageHeight)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: imageWidth, height: imageHeight)
                                        .clipped()
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(Theme.primaryColor.opacity(0.5))
                                        .frame(width: imageWidth, height: imageHeight)
                                @unknown default:
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(Theme.primaryColor.opacity(0.5))
                                        .frame(width: imageWidth, height: imageHeight)
                                }
                            }
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.primaryColor.opacity(0.5))
                                .frame(width: imageWidth, height: imageHeight)
                        }
                    }
                    .frame(width: imageWidth, height: imageHeight)
                    .clipped()
                    .cornerRadius(8)
                    
                    // Like count overlay - tappable
                    Button(action: {
                        // TODO: Handle like action
                    }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("\(item.likeCount)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(Theme.Spacing.xs)
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
                        Text("\(discount)%")
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
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.sm)
        }
    }
}

// MARK: - Section Divider
private struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.glassBorder)
            .frame(height: 0.5)
            .padding(.vertical, Theme.Spacing.lg)
    }
}

#Preview {
    DiscoverView()
        .preferredColorScheme(.dark)
}
