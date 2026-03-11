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
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel: FilteredProductsViewModel
    @State private var showSortSheet = false
    @State private var showFilterSheet = false
    
    let title: String
    let filterType: ProductFilterType
    
    init(title: String, filterType: ProductFilterType, authService: AuthService? = nil) {
        self.title = title
        self.filterType = filterType
        _viewModel = StateObject(wrappedValue: FilteredProductsViewModel(filterType: filterType, authService: authService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (same position as all app bar icons/back buttons)
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Theme.primaryColor)
                        .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HapticTapButtonStyle())
                Spacer()
                Text(title)
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                Color.clear.frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
            }
            .padding(.horizontal, Theme.AppBar.horizontalPadding)
            .padding(.vertical, Theme.AppBar.verticalPadding)
            .background(Theme.Colors.background)
            .overlay(ContentDivider(), alignment: .bottom)
            
            // Search Bar (same position as feed / discover / inbox)
            DiscoverSearchField(
                text: Binding(get: { viewModel.searchText }, set: { viewModel.searchText = $0 }),
                placeholder: L10n.string("Search items, brands or styles"),
                showClearButton: true,
                onClear: { viewModel.searchText = "" },
                topPadding: Theme.Spacing.xs
            )
            .padding(.trailing, Theme.Spacing.sm)

            // Filter / Sort row
            HStack(spacing: Theme.Spacing.md) {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                        Text(L10n.string("Filter"))
                            .font(Theme.Typography.subheadline)
                    }
                    .foregroundColor(Theme.Colors.primaryText)
                }
                .buttonStyle(HapticTapButtonStyle())
                Button(action: { showSortSheet = true }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.system(size: 16))
                        Text(L10n.string(viewModel.sortOption.rawValue))
                            .font(Theme.Typography.subheadline)
                    }
                    .foregroundColor(Theme.Colors.primaryText)
                }
                .buttonStyle(HapticTapButtonStyle())
                Spacer()
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
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if authService.isAuthenticated {
                viewModel.updateAuthToken(authService.authToken)
            }
            viewModel.loadData()
        }
        .onChange(of: authService.authToken) { oldToken, newToken in
            if authService.isAuthenticated {
                viewModel.updateAuthToken(newToken)
            }
        }
        .sheet(isPresented: $showSortSheet) { filteredProductsSortSheet }
        .sheet(isPresented: $showFilterSheet) { filteredProductsFilterSheet }
    }

    private var filteredProductsSortSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FilteredProductsSortOption.allCases, id: \.self) { option in
                        Button(action: {
                            viewModel.sortOption = option
                            showSortSheet = false
                        }) {
                            HStack {
                                Text(L10n.string(option.rawValue))
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.primaryColor)
                                }
                            }
                        }
                        .buttonStyle(HapticTapButtonStyle())
                    }
                    .listRowBackground(Theme.Colors.background)
                }
                Section {
                    Button(action: {
                        viewModel.sortOption = .relevance
                        showSortSheet = false
                    }) {
                        Text(L10n.string("Clear"))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Theme.Colors.background)
                    Divider()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Theme.Colors.background)
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.md, bottom: 0, trailing: Theme.Spacing.md))
                    Color.clear
                        .frame(height: 50)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Theme.Colors.background)
                }
            }
            .scrollDisabled(true)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Sort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSortSheet = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.background)
    }

    private var filteredProductsFilterSheet: some View {
        NavigationStack {
            List {
                Section(header: Text(L10n.string("Condition"))) {
                    ForEach(profileConditionOptions, id: \.raw) { option in
                        Button(action: {
                            viewModel.filterCondition = viewModel.filterCondition == option.raw ? nil : option.raw
                        }) {
                            HStack {
                                Text(L10n.string(option.display))
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if viewModel.filterCondition == option.raw {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.primaryColor)
                                }
                            }
                        }
                        .buttonStyle(HapticTapButtonStyle())
                    }
                    .listRowBackground(Theme.Colors.background)
                }
                Section(header: Text(L10n.string("Price range"))) {
                    HStack(spacing: Theme.Spacing.sm) {
                        SettingsTextField(
                            placeholder: L10n.string("Min. Price"),
                            text: Binding(get: { viewModel.filterMinPrice }, set: { viewModel.filterMinPrice = $0 })
                        )
                        .keyboardType(.decimalPad)
                        SettingsTextField(
                            placeholder: L10n.string("Max. Price"),
                            text: Binding(get: { viewModel.filterMaxPrice }, set: { viewModel.filterMaxPrice = $0 })
                        )
                        .keyboardType(.decimalPad)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Theme.Colors.background)
                }
                Section {
                    Button(action: {
                        viewModel.filterCondition = nil
                        viewModel.filterMinPrice = ""
                        viewModel.filterMaxPrice = ""
                        showFilterSheet = false
                    }) {
                        Text(L10n.string("Clear"))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Theme.Colors.background)
                    Divider()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Theme.Colors.background)
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.md, bottom: 0, trailing: Theme.Spacing.md))
                    Color.clear
                        .frame(height: 50)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Theme.Colors.background)
                }
            }
            .scrollDisabled(true)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showFilterSheet = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.background)
    }
}
