import SwiftUI
import PhotosUI

// MARK: - Profile sort (matches Flutter userProductSort / Enum$SortEnum)
enum ProfileSortOption: String, CaseIterable {
    case relevance = "Relevance"
    case newestFirst = "Newest First"
    case priceAsc = "Price Ascending"
    case priceDesc = "Price Descending"
}

// MARK: - Condition filter options (raw API values; display names match Item.formattedCondition). Shared with UserProfileView.
let profileConditionOptions: [(raw: String, display: String)] = [
    ("EXCELLENT_CONDITION", "Excellent Condition"),
    ("GOOD_CONDITION", "Good Condition"),
    ("BRAND_NEW_WITH_TAGS", "Brand New With Tags"),
    ("BRAND_NEW_WITHOUT_TAGS", "Brand new Without Tags"),
    ("HEAVILY_USED", "Heavily Used")
]

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var tabCoordinator: TabCoordinator
    @StateObject private var viewModel: ProfileViewModel
    @State private var scrollPosition: String? = "profile_top"
    @State private var isMultiBuyEnabled: Bool = false
    @State private var selectedBrand: String? = nil
    @State private var expandedCategories: Bool = false
    @State private var selectedCategory: String? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @State private var isVacationMode: Bool = false
    @State private var profileSort: ProfileSortOption = .newestFirst
    @State private var filterCondition: String? = nil
    @State private var filterMinPrice: String = ""
    @State private var filterMaxPrice: String = ""
    @State private var showSortSheet: Bool = false
    @State private var showFilterSheet: Bool = false
    @State private var showPriceFilterSheet: Bool = false

    private let topId = "profile_top"
    
    init(tabCoordinator: TabCoordinator) {
        self.tabCoordinator = tabCoordinator
        _viewModel = StateObject(wrappedValue: ProfileViewModel(authService: nil))
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.isLoading && viewModel.user == nil {
                        ProfileShimmerView()
                    } else {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 1).id(topId)
                            profileSection
                            
                            // Bio/Welcome Message
                            if let bio = viewModel.user?.bio {
                                bioSection(bio)
                            }
                            
                            // User Statistics (5 columns)
                            userStatsSection
                            
                            // Categories, Multi-buy, Top Brands, Filter/Sort
                            filtersSection
                            
                            // Items Grid
                            itemsGridSection
                        }
                    }
                }
                .scrollPosition(id: $scrollPosition, anchor: .top)
                .onAppear {
                    tabCoordinator.reportAtTop(tab: 4, isAtTop: true)
                    tabCoordinator.registerScrollToTop(tab: 4) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(topId, anchor: .top)
                        }
                    }
                    tabCoordinator.registerRefresh(tab: 4) {
                        Task { await viewModel.refreshAsync() }
                    }
                }
            }
            .onChange(of: scrollPosition) { _, new in
                tabCoordinator.reportAtTop(tab: 4, isAtTop: new == topId)
            }
            .background(Theme.Colors.background)
            .refreshable {
                await viewModel.refreshAsync()
            }
        }
        .navigationTitle(viewModel.user?.username ?? L10n.string("Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(value: AppRoute.menu(MenuContext(
                        listingCount: viewModel.user?.listingsCount ?? 0,
                        isMultiBuyEnabled: viewModel.user?.isMultibuyEnabled ?? isMultiBuyEnabled,
                        isVacationMode: viewModel.user?.isVacationMode ?? isVacationMode,
                        isStaff: viewModel.user?.isStaff ?? false
                    ))) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(Theme.Colors.primaryText)
                            .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        .onAppear {
            if profileImage == nil, let saved = viewModel.loadLocalProfileImage() {
                profileImage = saved
            }
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
        .onChange(of: viewModel.user?.username) { _, _ in
            if let u = viewModel.user {
                isMultiBuyEnabled = u.isMultibuyEnabled
                isVacationMode = u.isVacationMode
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .preluraUserProfileDidUpdate)) { _ in
            viewModel.refresh()
        }
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Profile Avatar (70px) with upload capability
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Group {
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    } else if let user = viewModel.user, let avatarURL = user.avatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Theme.primaryColor)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 35))
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Theme.primaryColor)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 35))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            .onChange(of: selectedPhoto) { oldValue, newItem in
                Task {
                    if let newItem = newItem,
                       let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            profileImage = image
                            viewModel.uploadProfileImage(image)
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isUploadingProfilePhoto {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }
            .alert("Profile photo", isPresented: Binding(
                get: { viewModel.profilePhotoUploadError != nil },
                set: { if !$0 { viewModel.profilePhotoUploadError = nil } }
            )) {
                Button("OK") { viewModel.profilePhotoUploadError = nil }
            } message: {
                if let err = viewModel.profilePhotoUploadError {
                    Text(err)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Username
                Text(viewModel.user?.username ?? "")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                // Rating with count
                HStack(spacing: Theme.Spacing.xs) {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.yellow)
                        }
                    }
                    Text("(\(viewModel.user?.reviewCount ?? 0))")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                }
                
                // Location
                if let location = viewModel.user?.location {
                    Text(location)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }
    
    // MARK: - Bio Section
    private func bioSection(_ bio: String) -> some View {
        Text(bio)
            .font(Theme.Typography.subheadline)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
    }
    
    // MARK: - User Stats Section (scrollable)
    private var userStatsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
                StatColumn(value: "\(viewModel.user?.listingsCount ?? 0)", label: L10n.string("Listings"))
                if let u = viewModel.user {
                    NavigationLink(destination: FollowingListView(username: u.username)) {
                        StatColumn(value: "\(u.followingsCount)", label: L10n.string("Followings"))
                    }
                    .buttonStyle(.plain)
                    NavigationLink(destination: FollowersListView(username: u.username)) {
                        StatColumn(value: "\(u.followersCount)", label: L10n.string("Followers"))
                    }
                    .buttonStyle(.plain)
                } else {
                    StatColumn(value: "\(viewModel.user?.followingsCount ?? 0)", label: L10n.string("Followings"))
                    StatColumn(value: "\(viewModel.user?.followersCount ?? 0)", label: L10n.string("Followers"))
                }
                NavigationLink(value: AppRoute.reviews(username: viewModel.user?.username ?? "", rating: viewModel.user?.rating ?? 5.0)) {
                    StatColumn(value: "\(viewModel.user?.reviewCount ?? 0)", label: L10n.string("Reviews"))
                }
                .buttonStyle(HapticTapButtonStyle())
                StatColumn(value: viewModel.user?.locationAbbreviation ?? L10n.string("N/A"), label: L10n.string("Location"))
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.md)
        .overlay(ContentDivider(), alignment: .bottom)
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(spacing: 0) {
            // Categories (Expandable)
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        expandedCategories.toggle()
                    }
                }) {
                    HStack {
                        Text(L10n.string("Categories"))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        Spacer()
                        Image(systemName: expandedCategories ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.toggle() }))
                
                // Expanded categories list (standard spacing: Theme.Spacing)
                if expandedCategories {
                    VStack(spacing: 0) {
                        ForEach(viewModel.categoriesWithCounts, id: \.name) { category in
                            Button(action: {
                                selectedCategory = selectedCategory == category.name ? nil : category.name
                                // TODO: Filter items by category
                            }) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.Colors.secondaryText)
                                    
                                    Text(category.name)
                                        .font(Theme.Typography.subheadline)
                                        .foregroundColor(Theme.Colors.primaryText)
                                    
                                    Text("(\(category.count) \(category.count == 1 ? L10n.string("item") : L10n.string("items"))")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                    
                                    Spacer(minLength: Theme.Spacing.md)
                                    
                                    Image(systemName: selectedCategory == category.name ? "checkmark.square" : "square")
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedCategory == category.name ? Theme.primaryColor : Theme.Colors.secondaryText)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md)
                            }
                            .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
                            
                            if category.name != viewModel.categoriesWithCounts.last?.name {
                                ContentDivider()
                                    .padding(.leading, Theme.Spacing.md)
                            }
                        }
                    }
                }
            }
            .overlay(ContentDivider(), alignment: .bottom)
            
            // Multi-buy Toggle
            HStack {
                Text(L10n.string("Multi-buy:"))
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
                Toggle("", isOn: $isMultiBuyEnabled)
                    .tint(Theme.primaryColor)
                    .frame(width: 50)
                    .onChange(of: isMultiBuyEnabled) { _, _ in HapticManager.toggle() }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .overlay(ContentDivider(), alignment: .bottom)
            
            // Top Brands (same component and placement as Home filter tags)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(L10n.string("Top brands"))
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.topBrands, id: \.self) { brand in
                            BrandFilterPill(
                                brand: brand,
                                isSelected: selectedBrand == brand,
                                action: { selectedBrand = selectedBrand == brand ? nil : brand }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
            
            // Filter and Sort (matches Flutter FilterAndSort: bottom sheets + Clear)
            HStack {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14))
                        Text(L10n.string("Filter"))
                            .font(Theme.Typography.subheadline)
                    }
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
                .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
                
                Spacer()
                
                Button(action: { showSortSheet = true }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(L10n.string(profileSort.rawValue))
                            .font(Theme.Typography.subheadline)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
                .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .sheet(isPresented: $showSortSheet) { profileSortSheet }
        .sheet(isPresented: $showFilterSheet) { profileFilterSheet }
        .sheet(isPresented: $showPriceFilterSheet) { profilePriceFilterSheet }
    }
    
    // MARK: - Sort sheet (Flutter: Sort bottom sheet – Relevance, Newest First, Price Asc/Desc, Clear)
    private var profileSortSheet: some View {
        NavigationStack {
            List {
                ForEach(ProfileSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        profileSort = option
                        showSortSheet = false
                    }) {
                        HStack {
                            Text(L10n.string(option.rawValue))
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if profileSort == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.primaryColor)
                            }
                        }
                    }
                    .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
                }
                Section {
                    Button(role: .destructive, action: {
                        profileSort = .relevance
                        showSortSheet = false
                    }) {
                        Text(L10n.string("Clear"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.destructive() }))
                }
            }
            .navigationTitle(L10n.string("Sort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) { showSortSheet = false }
                        .buttonStyle(HapticTapButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Filter sheet (Flutter: Filter types – Condition, Price; exclude Category/Brand)
    private var profileFilterSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(profileConditionOptions, id: \.raw) { option in
                        Button(action: {
                            filterCondition = filterCondition == option.raw ? nil : option.raw
                        }) {
                            HStack {
                                Text(L10n.string(option.display))
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if filterCondition == option.raw {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.primaryColor)
                                }
                            }
                        }
                        .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
                    }
                } header: { Text(L10n.string("Condition")) }
                Section {
                    Button(action: { showFilterSheet = false; showPriceFilterSheet = true }) {
                        HStack {
                            Text(L10n.string("Price"))
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if !filterMinPrice.isEmpty || !filterMaxPrice.isEmpty {
                                Text([filterMinPrice, filterMaxPrice].filter { !$0.isEmpty }.joined(separator: " – "))
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }
                    .buttonStyle(HapticTapButtonStyle())
                } header: { Text(L10n.string("Price range")) }
                Section {
                    Button(role: .destructive, action: {
                        filterCondition = nil
                        filterMinPrice = ""
                        filterMaxPrice = ""
                        showFilterSheet = false
                    }) {
                        Text(L10n.string("Clear"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.destructive() }))
                }
            }
            .navigationTitle(L10n.string("Filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) { showFilterSheet = false }
                        .buttonStyle(HapticTapButtonStyle())
                }
            }
        }
    }
    
    private var profilePriceFilterSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.string("Min. Price"), text: $filterMinPrice)
                        .keyboardType(.decimalPad)
                    TextField(L10n.string("Max. Price"), text: $filterMaxPrice)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Button(L10n.string("Clear")) {
                        filterMinPrice = ""
                        filterMaxPrice = ""
                        showPriceFilterSheet = false
                    }
                    .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.secondaryAction() }))
                    Button(L10n.string("Apply")) {
                        showPriceFilterSheet = false
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.primaryAction() }))
                }
            }
            .navigationTitle(L10n.string("Price"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) { showPriceFilterSheet = false }
                        .buttonStyle(HapticTapButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Items Grid Section (category + brand + filter + sort, matching Flutter)
    private var itemsGridSection: some View {
        var items = viewModel.userItems
        
        if let selectedBrand = selectedBrand {
            items = items.filter { $0.brand == selectedBrand }
        }
        if let selectedCategory = selectedCategory {
            items = items.filter {
                ($0.categoryName ?? $0.category.name) == selectedCategory
            }
        }
        if let cond = filterCondition {
            items = items.filter { $0.condition.uppercased() == cond.uppercased() }
        }
        let minP = Double(filterMinPrice.replacingOccurrences(of: ",", with: "."))
        let maxP = Double(filterMaxPrice.replacingOccurrences(of: ",", with: "."))
        if let min = minP, min > 0 {
            items = items.filter { $0.price >= min }
        }
        if let max = maxP, max > 0 {
            items = items.filter { $0.price <= max }
        }
        switch profileSort {
        case .relevance:
            break
        case .newestFirst:
            items = items.sorted { $0.createdAt > $1.createdAt }
        case .priceAsc:
            items = items.sorted { $0.price < $1.price }
        case .priceDesc:
            items = items.sorted { $0.price > $1.price }
        }
        
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm)
            ],
            spacing: Theme.Spacing.md
        ) {
            ForEach(items) { item in
                NavigationLink(value: AppRoute.itemDetail(item)) {
                    WardrobeItemCard(item: item, onLikeTap: { viewModel.toggleLike(productId: item.productId ?? "") })
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }
}

// MARK: - Supporting Views

struct StatColumn: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text(label)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(minWidth: 80)
    }
}

struct BrandButton: View {
    let brand: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PillTag(
            title: brand,
            isSelected: isSelected,
            accentWhenUnselected: true,
            icon: "message.fill",
            action: action
        )
    }
}

struct WardrobeItemCard: View {
    let item: Item
    var onLikeTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
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
                    Button(action: { onLikeTap?() }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: item.isLiked ? "heart.fill" : "heart")
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
                    .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.like() }))
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
}

#Preview {
    ProfileView(tabCoordinator: TabCoordinator())
        .preferredColorScheme(.dark)
}
