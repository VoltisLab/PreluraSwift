import SwiftUI

enum ProductFilterType: Equatable {
    case onSale
    case shopBargains
    case recentlyViewed
    case brandsYouLove
    case byBrand(brandName: String)
    case bySize(sizeName: String)
    /// Discover category: Men, Women, Boys, Girls (parent category filter).
    case byParentCategory(categoryName: String)
}

struct FilteredProductsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel: FilteredProductsViewModel
    @StateObject private var searchHistoryService = SearchHistoryService()
    @State private var showSortSheet = false
    @State private var showFilterSheet = false
    @State private var userSearchHistory: [SearchHistoryItem] = []
    @State private var recommendedSearchHistory: [SearchHistoryItem] = []

    let title: String
    let filterType: ProductFilterType

    init(title: String, filterType: ProductFilterType, authService: AuthService? = nil) {
        self.title = title
        self.filterType = filterType
        _viewModel = StateObject(wrappedValue: FilteredProductsViewModel(filterType: filterType, authService: authService))
    }

    private var showSearchHistory: Bool {
        viewModel.searchText.isEmpty && authService.isAuthenticated && !authService.isGuestMode
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar (same position as feed / discover / inbox)
            DiscoverSearchField(
                text: Binding(get: { viewModel.searchText }, set: { viewModel.searchText = $0 }),
                placeholder: L10n.string("Search items, brands or styles"),
                showClearButton: true,
                onClear: { viewModel.searchText = "" },
                topPadding: Theme.Spacing.xs
            )
            .padding(.trailing, Theme.Spacing.sm)

            // Search history (recent + recommended) when search is empty and user is logged in
            if showSearchHistory && (!userSearchHistory.isEmpty || !recommendedSearchHistory.isEmpty) {
                searchHistorySection
            }

            // Pill tags for main categories (Women, Men, Boys, Girls): Condition, Style, Colour, Price
            if case .byParentCategory = filterType {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        PillTag(
                            title: L10n.string("Condition"),
                            isSelected: viewModel.filterCondition != nil,
                            accentWhenUnselected: true,
                            action: { showFilterSheet = true }
                        )
                        PillTag(
                            title: L10n.string("Style"),
                            isSelected: false,
                            accentWhenUnselected: true,
                            action: { showFilterSheet = true }
                        )
                        PillTag(
                            title: L10n.string("Colour"),
                            isSelected: false,
                            accentWhenUnselected: true,
                            action: { showFilterSheet = true }
                        )
                        PillTag(
                            title: L10n.string("Price"),
                            isSelected: !viewModel.filterMinPrice.isEmpty || !viewModel.filterMaxPrice.isEmpty,
                            accentWhenUnselected: true,
                            action: { showFilterSheet = true }
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .padding(.vertical, Theme.Spacing.sm)
            }

            // Filter / Sort row (grey pills, no shadow)
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
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                            .fill(Theme.Colors.secondaryBackground)
                    )
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))

                Spacer()

                Button(action: { showSortSheet = true }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(L10n.string(viewModel.sortOption.rawValue))
                            .font(Theme.Typography.subheadline)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                            .fill(Theme.Colors.secondaryBackground)
                    )
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background)

            // Product Grid
            if viewModel.isLoading && viewModel.items.isEmpty {
                FeedShimmerView()
            } else if viewModel.items.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()
                    Image(systemName: "bag")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(L10n.string("No products found"))
                        .font(Theme.Typography.title3)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Theme.Spacing.sm),
                            GridItem(.flexible(), spacing: Theme.Spacing.sm)
                        ],
                        spacing: Theme.Spacing.md
                    ) {
                        ForEach(viewModel.filteredItems) { item in
                            NavigationLink(destination: ItemDetailView(item: item, authService: authService)) {
                                HomeItemCard(item: item)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onAppear {
                                // Load more when near the end
                                if item.id == viewModel.filteredItems.suffix(4).first?.id {
                                    viewModel.loadMore()
                                }
                            }
                        }
                        
                        // Loading indicator
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
                .refreshable {
                    await viewModel.refreshAsync()
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if authService.isAuthenticated {
                viewModel.updateAuthToken(authService.authToken)
            }
            if !authService.isGuestMode {
                searchHistoryService.updateAuthToken(authService.authToken)
                loadSearchHistory()
            }
            viewModel.loadData()
        }
        .onChange(of: authService.authToken) { oldToken, newToken in
            if authService.isAuthenticated {
                viewModel.updateAuthToken(newToken)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .preluraRecentlyViewedDidUpdate)) { _ in
            if case .recentlyViewed = filterType {
                viewModel.loadData()
            }
        }
        .sheet(isPresented: $showSortSheet) { filteredProductsSortSheet }
        .sheet(isPresented: $showFilterSheet) { filteredProductsFilterSheet }
    }

    private var searchHistorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if !userSearchHistory.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(L10n.string("Recent"))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding(.horizontal, Theme.Spacing.md)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(userSearchHistory) { item in
                                HStack(spacing: 4) {
                                    Button(action: {
                                        viewModel.searchText = item.query
                                    }) {
                                        Text(item.query)
                                            .font(Theme.Typography.subheadline)
                                            .foregroundColor(Theme.Colors.primaryText)
                                            .lineLimit(1)
                                            .padding(.horizontal, Theme.Spacing.sm)
                                            .padding(.vertical, Theme.Spacing.xs)
                                    }
                                    .buttonStyle(HapticTapButtonStyle())
                                    .background(Theme.Colors.secondaryBackground)
                                    .cornerRadius(16)
                                    Button(action: { deleteSearchHistoryItem(item) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(Theme.Colors.secondaryText)
                                    }
                                    .buttonStyle(HapticTapButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }
            }
            if !recommendedSearchHistory.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(L10n.string("Recommended"))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding(.horizontal, Theme.Spacing.md)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(recommendedSearchHistory) { item in
                                Button(action: {
                                    viewModel.searchText = item.query
                                }) {
                                    Text(item.query)
                                        .font(Theme.Typography.subheadline)
                                        .foregroundColor(Theme.Colors.primaryText)
                                        .lineLimit(1)
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, Theme.Spacing.xs)
                                }
                                .buttonStyle(HapticTapButtonStyle())
                                .background(Theme.Colors.secondaryBackground)
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
    }

    private func loadSearchHistory() {
        Task {
            do {
                let list = try await searchHistoryService.getUserSearchHistory(searchType: "PRODUCT")
                await MainActor.run { userSearchHistory = list }
            } catch {
                // Best-effort
            }
        }
        Task {
            do {
                let list = try await searchHistoryService.getRecommendedSearchHistory(searchType: "PRODUCT")
                await MainActor.run { recommendedSearchHistory = list }
            } catch {
                // Best-effort
            }
        }
    }

    private func deleteSearchHistoryItem(_ item: SearchHistoryItem) {
        Task {
            do {
                _ = try await searchHistoryService.deleteSearchHistory(searchId: item.id, clearAll: false)
                await MainActor.run {
                    userSearchHistory.removeAll { $0.id == item.id }
                }
            } catch {
                // Best-effort
            }
        }
    }

    private var optionDivider: some View {
        Rectangle()
            .fill(Theme.Colors.glassBorder)
            .frame(height: 0.5)
            .padding(.horizontal, Theme.Spacing.md)
    }

    private var filteredProductsSortSheet: some View {
        OptionsSheet(title: L10n.string("Sort"), onDismiss: { showSortSheet = false }, detents: [.height(380)], useCustomCornerRadius: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(FilteredProductsSortOption.allCases.enumerated()), id: \.offset) { index, option in
                    Button(action: { viewModel.sortOption = option }) {
                        HStack {
                            Text(L10n.string(option.rawValue))
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.primaryColor)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                    if index < FilteredProductsSortOption.allCases.count - 1 { optionDivider }
                }
                optionDivider
                VStack(spacing: Theme.Spacing.sm) {
                    BorderGlassButton(L10n.string("Clear")) {
                        viewModel.sortOption = .relevance
                    }
                    PrimaryGlassButton(L10n.string("Apply")) {
                        showSortSheet = false
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
            .background(
                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                    .fill(Theme.Colors.background)
            )
        }
    }

    private var filteredProductsFilterSheet: some View {
        OptionsSheet(title: L10n.string("Filter"), onDismiss: { showFilterSheet = false }, detents: [.height(580)], useCustomCornerRadius: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.string("Condition"))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
                ForEach(profileConditionOptions, id: \.raw) { option in
                    Button(action: {
                        viewModel.filterCondition = viewModel.filterCondition == option.raw ? nil : option.raw
                    }) {
                        HStack {
                            Text(L10n.string(option.display))
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if viewModel.filterCondition == option.raw {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.primaryColor)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                    optionDivider
                }
                Text(L10n.string("Price range"))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                HStack(spacing: Theme.Spacing.sm) {
                    SettingsTextField(
                        placeholder: L10n.string("Min. Price"),
                        text: Binding(get: { viewModel.filterMinPrice }, set: { viewModel.filterMinPrice = $0 }),
                        bordered: true
                    )
                    .keyboardType(.decimalPad)
                    SettingsTextField(
                        placeholder: L10n.string("Max. Price"),
                        text: Binding(get: { viewModel.filterMaxPrice }, set: { viewModel.filterMaxPrice = $0 }),
                        bordered: true
                    )
                    .keyboardType(.decimalPad)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                optionDivider
                VStack(spacing: Theme.Spacing.sm) {
                    BorderGlassButton(L10n.string("Clear")) {
                        viewModel.filterCondition = nil
                        viewModel.filterMinPrice = ""
                        viewModel.filterMaxPrice = ""
                    }
                    PrimaryGlassButton(L10n.string("Apply")) {
                        showFilterSheet = false
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
            }
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
            .background(
                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                    .fill(Theme.Colors.background)
            )
        }
    }
}
