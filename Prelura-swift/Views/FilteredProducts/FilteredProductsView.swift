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
    /// Try Cart: free search, add to bag only (offers disabled).
    case tryCartSearch
    /// Shop All with Try Cart behavior but **style locked to Vintage**; gender pills only (All, Women, Men).
    case shopAllVintageLocked
    /// Shop by style: style filter via toolbar "Styles" modal (no category pills).
    case shopByStyle
}

extension ProductFilterType {
    /// Shop All flows that use the floating bag, debounced search, and category pills row 1.
    var isShopAllWithBag: Bool {
        switch self {
        case .tryCartSearch, .shopAllVintageLocked: return true
        default: return false
        }
    }
}

/// One active modal (sort / filter / styles). Avoids stacking multiple `.sheet` presentations.
enum FilteredProductsActiveSheet: Identifiable, Equatable {
    case sort
    case filter
    case styles
    var id: Self { self }
}

struct FilteredProductsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel: FilteredProductsViewModel
    @State private var activeSheet: FilteredProductsActiveSheet?
    @State private var tryCartSearchTask: Task<Void, Never>?
    @EnvironmentObject private var shopAllBag: ShopAllBagStore
    @State private var showGuestSignInPrompt: Bool = false
    @State private var showTryCartOnboarding: Bool = false
    /// Avoid re-presenting Try Cart intro when `onAppear` runs again (e.g. back from item detail).
    @State private var didScheduleTryCartOnboardingThisVisit: Bool = false
    /// Try Cart: when on, grid + detail use the shared bag (toolbar bag on Shop All). Defaults on for Shop All so Add to bag is visible immediately.
    @State private var shopAllBagToolbarActive: Bool
    @State private var showProductsTopChrome = true
    @State private var lastProductsScrollMinY: CGFloat = 0
    @State private var productsHeaderHeight: CGFloat = 0

    private let productsScrollSpace = "filteredProductsScroll"

    /// Match `HomeView` category strip rhythm: no extra top gap under `.searchable`, tight stack, minimal gap before grid.
    private static let filterPageChipTopInset: CGFloat = 0
    private static let filterPageChipBottomInset: CGFloat = Theme.Spacing.sm
    private static let filterPageNestedRowVerticalInset: CGFloat = Theme.Spacing.xs
    private static let filterPageFilterRowTopInset: CGFloat = Theme.Spacing.xs
    private static let filterPageFilterRowBottomInset: CGFloat = 0
    /// Last grid row clears the floating Shopping bag + home indicator (Try Cart / Retro only).
    private static let shopAllScrollBottomClearance: CGFloat = 112

    let title: String
    let filterType: ProductFilterType
    /// When false, item detail shows only Buy now (no Send an offer). Used for Try Cart.
    let offersAllowed: Bool
    /// When false, hide floating Shopping bag bar (e.g. Shop by style). When nil, use (filterType == .tryCartSearch). Grid uses the same bag controls as Favourites when bag mode is on.
    var showAddToBag: Bool? = nil

    /// Try Cart (or explicit flag): floating bag + pass `shopAllBag` into item detail for optional toolbar cart mode.
    private var tryCartShoppingEnabled: Bool {
        showAddToBag ?? filterType.isShopAllWithBag
    }

    private var isVintageRetroShop: Bool {
        filterType == .shopAllVintageLocked
    }

    private var vintageToolbarLabelColor: Color {
        colorScheme == .dark ? .white : Theme.Colors.primaryText
    }

    private var filterSortRowLabelColor: Color {
        if isVintageRetroShop { return vintageToolbarLabelColor }
        return Theme.Colors.secondaryText
    }

    @ViewBuilder
    private var filterSortRowBackground: some View {
        if isVintageRetroShop {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                .fill(Theme.Colors.secondaryBackground)
        }
    }

    @ViewBuilder
    private var filterSortRowOverlay: some View {
        if isVintageRetroShop {
            RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.22), lineWidth: 1)
        } else {
            EmptyView()
        }
    }

    init(title: String, filterType: ProductFilterType, authService: AuthService? = nil, offersAllowed: Bool = true, showAddToBag: Bool? = nil) {
        self.title = title
        self.filterType = filterType
        self.offersAllowed = offersAllowed
        self.showAddToBag = showAddToBag
        _viewModel = StateObject(wrappedValue: FilteredProductsViewModel(filterType: filterType, authService: authService))
        let bagModeDefault = showAddToBag ?? filterType.isShopAllWithBag
        _shopAllBagToolbarActive = State(initialValue: bagModeDefault)
    }

    private func likeAction(for item: Item) -> () -> Void {
        return { [self] in
            if authService.isGuestMode { showGuestSignInPrompt = true }
            else { viewModel.toggleLike(productId: item.productId ?? "") }
        }
    }

    @ViewBuilder
    private var productGridContent: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            FeedShimmerView()
        } else if viewModel.items.isEmpty {
            Group {
                if let err = viewModel.errorMessage, !err.isEmpty {
                    VStack {
                        Spacer()
                        FeedNetworkBannerView(message: err, title: viewModel.errorBannerTitle) {
                            viewModel.loadData()
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
                }
            }
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
                        let bagMode = tryCartShoppingEnabled && shopAllBagToolbarActive
                        let inBag = shopAllBag.items.contains(where: { $0.id == item.id })
                        NavigationLink(destination: ItemDetailView(
                            item: item,
                            authService: authService,
                            offersAllowed: offersAllowed,
                            shopAllBag: bagMode ? shopAllBag : nil,
                            activateShopBagActionsInitially: bagMode
                        )) {
                            HomeItemCard(
                                item: item,
                                onLikeTap: likeAction(for: item),
                                showAddToBag: bagMode,
                                onAddToBag: bagMode
                                    ? {
                                        if !shopAllBag.items.contains(where: { $0.id == item.id }) {
                                            shopAllBag.add(item)
                                        }
                                    }
                                    : nil,
                                isInBag: inBag,
                                onRemove: bagMode ? { shopAllBag.remove(item) } : nil,
                                addToBagChromeStyle: isVintageRetroShop ? .retroCompactLightOutline : .standard
                            )
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .buttonStyle(PlainTappableButtonStyle())
                        .onAppear {
                            if item.id == viewModel.filteredItems.suffix(4).first?.id {
                                viewModel.loadMore()
                            }
                        }
                    }
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
                .padding(.top, 0)
                .padding(.bottom, (tryCartShoppingEnabled && shopAllBagToolbarActive) ? Self.shopAllScrollBottomClearance : 0)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollMinYPreferenceKey.self,
                            value: geo.frame(in: .named(productsScrollSpace)).minY
                        )
                    }
                )
            }
            // Header chrome lives outside this ScrollView; system scroll content margins would stack with
            // the grid's horizontal padding and make products look more inset than search/filter (Shop All).
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .contentMargins(.top, 0, for: .scrollContent)
            .coordinateSpace(name: productsScrollSpace)
            .refreshable {
                await viewModel.refreshAsync()
            }
        }
    }

    /// Search, category/style pills, and filter/sort row — slides off-screen when scrolling down the grid.
    @ViewBuilder
    private var filteredProductsFixedHeader: some View {
        VStack(spacing: 0) {
            // Shop by style: pill tags under search bar for style filters.
            // Selected style is shown before "All" so the active filter stays visible without horizontal scrolling.
            if case .shopByStyle = filterType {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            if let selectedRaw = viewModel.selectedStyle {
                                shopByStylePill(for: selectedRaw)
                                    .id(Self.shopByStyleChipScrollId(selectedRaw))
                            }
                            PillTag(
                                title: L10n.string("All"),
                                isSelected: viewModel.selectedStyle == nil,
                                accentWhenUnselected: true,
                                action: {
                                    viewModel.selectedStyle = nil
                                    viewModel.loadData()
                                }
                            )
                            .id(Self.shopByStyleAllChipScrollId)
                            ForEach(Self.styleFilterOptionsExcludingSelected(viewModel.selectedStyle), id: \.self) { raw in
                                shopByStylePill(for: raw)
                                    .id(Self.shopByStyleChipScrollId(raw))
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    .padding(.top, Self.filterPageChipTopInset)
                    .padding(.bottom, Self.filterPageChipBottomInset)
                    .onChange(of: viewModel.selectedStyle) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if let raw = newValue {
                                proxy.scrollTo(Self.shopByStyleChipScrollId(raw), anchor: .leading)
                            } else {
                                proxy.scrollTo(Self.shopByStyleAllChipScrollId, anchor: .leading)
                            }
                        }
                    }
                }
                // Horizontal `ScrollView` in a top `ZStack` otherwise expands vertically to fill the screen,
                // inflating header height measurement and leaving empty space above the grid.
                .fixedSize(horizontal: false, vertical: true)
            }

            // Shop All: Row 1 = category pills. Full hierarchy (rows 2–3) only for standard Try Cart Shop All.
            if filterType.isShopAllWithBag {
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            PillTag(
                                title: L10n.string("All"),
                                isSelected: viewModel.selectedParentCategory == nil,
                                accentWhenUnselected: true,
                                showShadow: !isVintageRetroShop,
                                unselectedOutlineOnRichBackground: isVintageRetroShop,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        viewModel.selectShopAllAll()
                                    }
                                }
                            )
                            if case .tryCartSearch = filterType {
                                ForEach(["Women", "Men", "Boys", "Girls", "Toddlers"], id: \.self) { category in
                                    PillTag(
                                        title: L10n.string(category),
                                        isSelected: viewModel.selectedParentCategory == category,
                                        accentWhenUnselected: true,
                                        showShadow: !isVintageRetroShop,
                                        unselectedOutlineOnRichBackground: isVintageRetroShop,
                                        action: {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                viewModel.selectShopAllMain(category)
                                            }
                                        }
                                    )
                                }
                            } else if case .shopAllVintageLocked = filterType {
                                ForEach(["Women", "Men"], id: \.self) { category in
                                    PillTag(
                                        title: L10n.string(category),
                                        isSelected: viewModel.selectedParentCategory == category,
                                        accentWhenUnselected: true,
                                        showShadow: !isVintageRetroShop,
                                        unselectedOutlineOnRichBackground: isVintageRetroShop,
                                        action: {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                viewModel.selectShopAllMain(category)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    .padding(.top, Self.filterPageChipTopInset)
                    .padding(.bottom, Self.filterPageChipBottomInset)
                    .fixedSize(horizontal: false, vertical: true)

                    // Row 2: subcategories (Try Cart Shop All only)
                    if case .tryCartSearch = filterType, viewModel.selectedParentCategory != nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(viewModel.shopAllSubCategories, id: \.id) { sub in
                                    PillTag(
                                        title: sub.name,
                                        isSelected: viewModel.selectedSubCategory?.id == sub.id,
                                        accentWhenUnselected: true,
                                        action: {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                viewModel.selectShopAllSub(sub)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                        .padding(.vertical, Self.filterPageNestedRowVerticalInset)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }

                    // Row 3: sub-subcategories (Try Cart Shop All only)
                    if case .tryCartSearch = filterType,
                       viewModel.selectedSubCategory != nil,
                       !viewModel.shopAllSubSubCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(viewModel.shopAllSubSubCategories, id: \.id) { subSub in
                                    PillTag(
                                        title: subSub.name,
                                        isSelected: viewModel.selectedCategoryId == Int(subSub.id),
                                        accentWhenUnselected: true,
                                        action: {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                viewModel.selectShopAllSubSub(subSub)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                        .padding(.vertical, Self.filterPageNestedRowVerticalInset)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedParentCategory)
                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedSubCategory?.id)
                .animation(.easeInOut(duration: 0.25), value: viewModel.shopAllSubSubCategories.count)
            }

            // Pill tags for main categories (Women, Men, Boys, Girls): Condition, Style, Colour, Price
            if case .byParentCategory = filterType {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        PillTag(
                            title: L10n.string("Condition"),
                            isSelected: viewModel.filterCondition != nil,
                            accentWhenUnselected: true,
                            action: { activeSheet = .filter }
                        )
                        PillTag(
                            title: L10n.string("Style"),
                            isSelected: false,
                            accentWhenUnselected: true,
                            action: { activeSheet = .filter }
                        )
                        PillTag(
                            title: L10n.string("Colour"),
                            isSelected: false,
                            accentWhenUnselected: true,
                            action: { activeSheet = .filter }
                        )
                        PillTag(
                            title: L10n.string("Price"),
                            isSelected: !viewModel.filterMinPrice.isEmpty || !viewModel.filterMaxPrice.isEmpty,
                            accentWhenUnselected: true,
                            action: { activeSheet = .filter }
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .padding(.top, Self.filterPageChipTopInset)
                .padding(.bottom, Self.filterPageChipBottomInset)
                .fixedSize(horizontal: false, vertical: true)
            }

            // Filter / Sort row (grey pills, no shadow; Retro = hairline border on gradient)
            HStack {
                Button(action: { activeSheet = .filter }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14))
                        Text(L10n.string("Filter"))
                            .font(Theme.Typography.subheadline)
                    }
                    .foregroundColor(filterSortRowLabelColor)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(filterSortRowBackground)
                    .overlay(filterSortRowOverlay)
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))

                Spacer()

                Button(action: { activeSheet = .sort }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(L10n.string(viewModel.sortOption.rawValue))
                            .font(Theme.Typography.subheadline)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(filterSortRowLabelColor)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(filterSortRowBackground)
                    .overlay(filterSortRowOverlay)
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Self.filterPageFilterRowTopInset)
            .padding(.bottom, Self.filterPageFilterRowBottomInset)
            .background(isVintageRetroShop ? Color.clear : Theme.Colors.background)
        }
    }

    /// Placeholder before `GeometryReader` measures the real header (wrong default caused a gap under the filter row or clipped the first grid row).
    private var fallbackProductsHeaderHeight: CGFloat {
        switch filterType {
        case .shopAllVintageLocked: return 96
        case .tryCartSearch: return 132
        case .shopByStyle: return 100
        case .byParentCategory: return 124
        case .onSale, .shopBargains, .recentlyViewed, .brandsYouLove, .byBrand, .bySize:
            /// Filter + sort row only (~52–58pt); keep modest until measured (intrinsic height used once `fixedSize` fixes GeometryReader).
            return 58
        }
    }

    private var resolvedProductsHeaderHeight: CGFloat {
        productsHeaderHeight > 8 ? productsHeaderHeight : fallbackProductsHeaderHeight
    }

    /// When collapsing chrome hides the overlay, drop this to 0 so we do not keep a tall empty band above the grid (feed keeps header inside `ScrollView` instead).
    private var headerSpacerHeight: CGFloat {
        showProductsTopChrome ? resolvedProductsHeaderHeight : 0
    }

    private var filteredProductsRootStack: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: headerSpacerHeight)
                    .animation(.spring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.12), value: showProductsTopChrome)
                productGridContent
            }

            filteredProductsFixedHeader
                /// Prevent the header from receiving the full ZStack height; otherwise `GeometryReader` reports ~screen height and the top spacer leaves a huge gap under Filter/Sort.
                .fixedSize(horizontal: false, vertical: true)
                .background(isVintageRetroShop ? Color.clear : Theme.Colors.background)
                .offset(y: showProductsTopChrome ? 0 : -resolvedProductsHeaderHeight)
                .allowsHitTesting(showProductsTopChrome)
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: FilteredProductsHeaderHeightKey.self, value: g.size.height)
                    }
                )
        }
        .onPreferenceChange(FilteredProductsHeaderHeightKey.self) { productsHeaderHeight = $0 }
        .onPreferenceChange(ScrollMinYPreferenceKey.self) { minY in
            CollapsingScrollChrome.updateVisibility(
                scrollMinY: minY,
                lastY: &lastProductsScrollMinY,
                isVisible: $showProductsTopChrome
            )
        }
    }

    var body: some View {
        Group {
            if isVintageRetroShop {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                    filteredProductsRootStack
                        .background(
                            VintageShopAnimatedBackground(animationDate: context.date)
                                .ignoresSafeArea()
                        )
                        .toolbarBackground(
                            LinearGradient(
                                colors: VintageShopBannerGradient.colors(at: context.date, colorScheme: colorScheme),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            for: .navigationBar
                        )
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarColorScheme(colorScheme, for: .navigationBar)
                        .tint(colorScheme == .dark ? Color.white : Theme.primaryColor)
                }
            } else {
                filteredProductsRootStack
                    .background(Theme.Colors.background)
                    .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .toolbar(.hidden, for: .tabBar)
        .searchable(
            text: Binding(get: { viewModel.searchText }, set: { viewModel.searchText = $0 }),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(tryCartShoppingEnabled ? "Search anything to add to bag" : L10n.string("Search items, brands or styles"))
        )
        .onAppear {
            if authService.isAuthenticated {
                viewModel.updateAuthToken(authService.authToken)
            }
            viewModel.loadData()
            scheduleTryCartOnboardingIfNeeded()
        }
        .onChange(of: viewModel.searchText) { _, _ in
            if filterType.isShopAllWithBag {
                tryCartSearchTask?.cancel()
                tryCartSearchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        viewModel.loadData()
                    }
                }
            }
            if case .shopByStyle = filterType {
                tryCartSearchTask?.cancel()
                tryCartSearchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        viewModel.loadData()
                    }
                }
            }
        }
        .onChange(of: authService.authToken) { oldToken, newToken in
            if authService.isAuthenticated {
                viewModel.updateAuthToken(newToken)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wearhouseRecentlyViewedDidUpdate)) { _ in
            if case .recentlyViewed = filterType {
                viewModel.loadData()
            }
        }
        .onChange(of: viewModel.selectedParentCategory) { _, _ in
            if filterType.isShopAllWithBag {
                viewModel.loadData()
            }
        }
        .toolbar {
            if case .shopByStyle = filterType {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("Styles")) {
                        activeSheet = .styles
                    }
                    .foregroundColor(Theme.Colors.primaryText)
                }
            }
            if tryCartShoppingEnabled {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        shopAllBagToolbarActive.toggle()
                    } label: {
                        Image(systemName: shopAllBagToolbarActive ? "bag.fill" : "bag")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(
                                shopAllBagToolbarActive
                                    ? Theme.primaryColor
                                    : (isVintageRetroShop ? vintageToolbarLabelColor : Theme.Colors.primaryText)
                            )
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainTappableButtonStyle())
                    .accessibilityLabel("Toggle shopping bag mode")

                    NavigationLink(destination: MyFavouritesView(fromShopAll: true)) {
                        Image(systemName: "heart")
                            .foregroundColor(isVintageRetroShop ? vintageToolbarLabelColor : Theme.Colors.primaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainTappableButtonStyle())
                }
            }
        }
        // Keep navigation bar visible so system `.searchable` matches Debug (drawer animation); only the filter header offsets with scroll.
        .toolbar(.visible, for: .navigationBar)
        .onChange(of: viewModel.items.isEmpty) { _, empty in
            if empty { showProductsTopChrome = true }
        }
        .overlay(alignment: .bottom) {
            if tryCartShoppingEnabled {
                shopAllFloatingBar
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .sort:
                filteredProductsSortSheet
            case .filter:
                filteredProductsFilterSheet
            case .styles:
                stylesSheetContent
            }
        }
        .fullScreenCover(isPresented: $showGuestSignInPrompt) { GuestSignInPromptView() }
        .overlay {
            if showTryCartOnboarding {
                TryCartOnboardingPopupOverlay(onComplete: finishTryCartOnboarding)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(900)
            }
        }
    }

    private func scheduleTryCartOnboardingIfNeeded() {
        guard case .tryCartSearch = filterType else { return }
        guard !didScheduleTryCartOnboardingThisVisit else { return }
        guard AppBannerPolicy.shouldPresent(.tryCartShopAllIntro) else { return }
        didScheduleTryCartOnboardingThisVisit = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.easeOut(duration: 0.22)) {
                showTryCartOnboarding = true
            }
        }
    }

    private func finishTryCartOnboarding() {
        if !AppBannerPolicy.forceShowTryCartShopAllIntroEveryTime {
            AppBannerPolicy.markSeen(.tryCartShopAllIntro)
        }
        withAnimation(.easeOut(duration: 0.2)) {
            showTryCartOnboarding = false
        }
    }

    /// Multi-buy style: floating primary-colour glassy pill (bag icon + "Shopping bag" + total).
    private var shopAllFloatingBar: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                GlassEffectContainer(spacing: 0) {
                    NavigationLink(destination: ShopAllBagView(store: shopAllBag).environmentObject(authService)) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(L10n.string("Shopping bag"))
                                .font(Theme.Typography.headline)
                            Spacer(minLength: 0)
                            Text(shopAllBag.formattedTotal)
                                .font(Theme.Typography.headline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                        .glassEffect(.clear.tint(Theme.primaryColor), in: .rect(cornerRadius: 30))
                        .glassEffectTransition(.materialize)
                    }
                    .buttonStyle(PlainTappableButtonStyle())
                }
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, 15)
        }
        .allowsHitTesting(true)
    }

    /// Same hairline as `ContentDivider` (1 device pixel) so sort/filter sheets match profile and forms.
    private var optionDivider: some View {
        ContentDivider()
            .padding(.horizontal, Theme.Spacing.md)
    }

    private var filteredProductsSortSheet: some View {
        OptionsSheet(title: L10n.string("Sort"), onDismiss: { activeSheet = nil }, useCustomCornerRadius: false, chromeStyle: .navigationDone) {
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
                        activeSheet = nil
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static let shopByStyleAllChipScrollId = "shopByStyleAll"

    private static func shopByStyleChipScrollId(_ raw: String) -> String {
        "shopByStyle-\(raw)"
    }

    /// Remaining style pills after moving the selected one before "All" (avoids duplicate chips).
    private static func styleFilterOptionsExcludingSelected(_ selected: String?) -> [String] {
        guard let selected else { return styleFilterOptions }
        return styleFilterOptions.filter { $0 != selected }
    }

    @ViewBuilder
    private func shopByStylePill(for raw: String) -> some View {
        let displayName = StyleSelectionView.displayName(for: raw)
        PillTag(
            title: displayName,
            isSelected: viewModel.selectedStyle == raw,
            accentWhenUnselected: true,
            action: {
                viewModel.selectedStyle = raw
                viewModel.loadData()
            }
        )
    }

    /// Style filter options (StyleEnum raw values; same set as StyleSelectionView in SellView).
    private static let styleFilterOptions: [String] = [
        "WORKWEAR", "WORKOUT", "CASUAL", "PARTY_DRESS", "PARTY_OUTFIT", "FORMAL_WEAR", "EVENING_WEAR",
        "WEDDING_GUEST", "LOUNGEWEAR", "VACATION_RESORT_WEAR", "FESTIVAL_WEAR", "ACTIVEWEAR", "NIGHTWEAR",
        "VINTAGE", "Y2K", "BOHO", "MINIMALIST", "GRUNGE", "CHIC", "STREETWEAR", "PREPPY", "RETRO",
        "COTTAGECORE", "GLAM", "SUMMER_STYLES", "WINTER_ESSENTIALS", "SPRING_FLORALS", "AUTUMN_LAYERS",
        "RAINY_DAY_WEAR", "DENIM_JEANS", "DRESSES_GOWNS", "JACKETS_COATS", "KNITWEAR_SWEATERS",
        "SKIRTS_SHORTS", "SUITS_BLAZERS", "TOPS_BLOUSES", "SHOES_FOOTWEAR", "TRAVEL_FRIENDLY",
        "MATERNITY_WEAR", "ATHLEISURE", "ECO_FRIENDLY", "FESTIVAL_READY", "DATE_NIGHT", "ETHNIC_WEAR",
        "OFFICE_PARTY_OUTFIT", "COCKTAIL_ATTIRE", "PROM_DRESSES", "MUSIC_CONCERT_WEAR", "OVERSIZED",
        "SLIM_FIT", "RELAXED_FIT", "CHRISTMAS", "SCHOOL_UNIFORMS"
    ]

    private var stylesSheetContent: some View {
        OptionsSheet(title: L10n.string("Styles"), onDismiss: { activeSheet = nil }, useCustomCornerRadius: false, chromeStyle: .navigationDone) {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Self.styleFilterOptions, id: \.self) { raw in
                            Button(action: {
                                viewModel.selectedStyle = viewModel.selectedStyle == raw ? nil : raw
                            }) {
                                HStack {
                                    Text(StyleSelectionView.displayName(for: raw))
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.primaryText)
                                    Spacer()
                                    if viewModel.selectedStyle == raw {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Theme.primaryColor)
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md)
                            }
                            .buttonStyle(HapticTapButtonStyle())
                            if raw != Self.styleFilterOptions.last {
                                optionDivider
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                optionDivider
                VStack(spacing: Theme.Spacing.sm) {
                    BorderGlassButton(L10n.string("Clear")) {
                        viewModel.selectedStyle = nil
                        viewModel.loadData()
                        activeSheet = nil
                    }
                    PrimaryGlassButton(L10n.string("Apply")) {
                        viewModel.loadData()
                        activeSheet = nil
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.vertical, Theme.Spacing.md)
        }
    }

    private var filteredProductsFilterSheet: some View {
        OptionsSheet(title: L10n.string("Filter"), onDismiss: { activeSheet = nil }, useCustomCornerRadius: false, chromeStyle: .navigationDone) {
            ScrollView {
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
                        text: PriceFieldFilter.binding(get: { viewModel.filterMinPrice }, set: { viewModel.filterMinPrice = $0 }),
                        keyboardType: .decimalPad,
                        bordered: true
                    )
                    .onChange(of: viewModel.filterMinPrice) { _, newValue in
                        let sanitized = PriceFieldFilter.sanitizePriceInput(newValue)
                        if sanitized != newValue { viewModel.filterMinPrice = sanitized }
                    }
                    SettingsTextField(
                        placeholder: L10n.string("Max. Price"),
                        text: PriceFieldFilter.binding(get: { viewModel.filterMaxPrice }, set: { viewModel.filterMaxPrice = $0 }),
                        keyboardType: .decimalPad,
                        bordered: true
                    )
                    .onChange(of: viewModel.filterMaxPrice) { _, newValue in
                        let sanitized = PriceFieldFilter.sanitizePriceInput(newValue)
                        if sanitized != newValue { viewModel.filterMaxPrice = sanitized }
                    }
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
                        activeSheet = nil
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
                }
                .padding(.vertical, Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
