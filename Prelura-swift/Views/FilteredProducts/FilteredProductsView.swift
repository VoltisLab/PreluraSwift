import SwiftUI

enum ProductFilterType: Equatable {
    case onSale
    case shopBargains
    case recentlyViewed
    case brandsYouLove
    case byBrand(brandName: String)
    case bySize(sizeName: String)
}

struct FilteredProductsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel: FilteredProductsViewModel
    @State private var searchText: String = ""
    
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
                .buttonStyle(.plain)
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
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
            
            // Search Bar (DiscoverSearchField – 30pt)
            DiscoverSearchField(
                text: $searchText,
                placeholder: "Search for items",
                onChange: { viewModel.searchText = $0 },
                showClearButton: true,
                onClear: { viewModel.searchText = "" }
            )
            
            // Product Grid
            if viewModel.isLoading && viewModel.items.isEmpty {
                FeedShimmerView()
            } else if viewModel.items.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()
                    Image(systemName: "bag")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text("No products found")
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
    }
}
