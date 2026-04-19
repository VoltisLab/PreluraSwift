import SwiftUI

struct BrowseView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = BrowseViewModel()
    @State private var searchText: String = ""
    let selectedCategory: Category?
    
    init(selectedCategory: Category? = nil) {
        self.selectedCategory = selectedCategory
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: Theme.Spacing.md) {
                    // Category Filters
                    categoryFilters
                    
                    // Sort Options
                    sortOptions
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.sm)
                .background(Theme.Colors.background)
                
                // Items Grid
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: WearhouseLayoutMetrics.productGridColumns(
                                horizontalSizeClass: horizontalSizeClass,
                                spacing: Theme.Spacing.sm
                            ),
                            spacing: Theme.Spacing.sm
                        ) {
                            ForEach(viewModel.filteredItems) { item in
                                NavigationLink(destination: ItemDetailView(item: item)) {
                                    ItemCard(item: item)
                                }
                                .buttonStyle(PlainTappableButtonStyle())
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                    }
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Browse"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(L10n.string("Search items, brands or styles"))
            )
            .onChange(of: searchText) { _, newValue in
                viewModel.setSearchText(newValue)
            }
            .onAppear {
                if let category = selectedCategory {
                    viewModel.selectCategory(category)
                }
            }
        }
    }
    
    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                // All Categories Button
                CategoryFilterButton(
                    title: L10n.string("All"),
                    isSelected: viewModel.selectedCategory == nil,
                    action: {
                        viewModel.selectCategory(nil)
                    }
                )
                
                ForEach(Category.allCategories) { category in
                    CategoryFilterButton(
                        title: category.name,
                        isSelected: viewModel.selectedCategory?.id == category.id,
                        action: {
                            viewModel.selectCategory(category)
                        }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.xs)
        }
    }
    
    private var sortOptions: some View {
        Menu {
            ForEach(BrowseViewModel.SortOption.allCases, id: \.self) { option in
                Button(action: {
                    viewModel.setSortOption(option)
                }) {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(L10n.string("Sort: ") + viewModel.sortOption.rawValue)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .glassEffect()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text(L10n.string("No items found"))
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text(L10n.string("Try adjusting your filters"))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PillTag(title: title, isSelected: isSelected, accentWhenUnselected: true, action: action)
    }
}

#Preview {
    BrowseView()
        .preferredColorScheme(.dark)
}
