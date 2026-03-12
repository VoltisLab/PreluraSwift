import SwiftUI

/// Favourites: fetch liked products, grid, search, empty state. Matches Flutter MyFavouriteScreen.
struct MyFavouritesView: View {
    @EnvironmentObject var authService: AuthService
    @State private var searchText: String = ""
    @State private var items: [Item] = []
    @State private var totalNumber: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var isLoadingMore = false

    private let productService = ProductService()
    private let pageCount = 20
    /// Same grid as feed: column and row spacing so products don’t bleed together.
    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    private var filteredItems: [Item] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return items }
        return items.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            DiscoverSearchField(
                text: $searchText,
                placeholder: L10n.string("Search favourites"),
                topPadding: Theme.Spacing.xs
            )

            if let err = errorMessage {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.error)
                    .padding(.horizontal)
            }

            if isLoading && items.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if items.isEmpty {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    Text(L10n.string("No favourites yet"))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text(L10n.string("Items you save as favourites will appear here."))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.Spacing.xl)
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                Text(String(format: L10n.string("No results for \"%@\""), searchText))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: columns,
                        alignment: .leading,
                        spacing: Theme.Spacing.md,
                        pinnedViews: []
                    ) {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                FavouriteItemCard(item: item)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if item.id == filteredItems.last?.id {
                                    loadMoreIfNeeded()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.lg)

                    if isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(L10n.string("Favourites"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load(resetPage: true) }
        .task { await load(resetPage: true) }
    }

    private func load(resetPage: Bool) async {
        productService.updateAuthToken(authService.authToken)
        if resetPage {
            currentPage = 1
            items = []
        }
        if currentPage == 1 { isLoading = true }
        errorMessage = nil
        defer {
            if currentPage == 1 { isLoading = false }
        }
        do {
            let (newItems, total) = try await productService.getLikedProducts(pageNumber: currentPage, pageCount: pageCount)
            if currentPage == 1 {
                items = newItems
            } else {
                let ids = Set(items.map { $0.id })
                items += newItems.filter { !ids.contains($0.id) }
            }
            totalNumber = total
        } catch {
            errorMessage = L10n.userFacingError(error)
        }
    }

    private func loadMoreIfNeeded() {
        guard !isLoadingMore, items.count < totalNumber else { return }
        Task {
            isLoadingMore = true
            currentPage += 1
            await load(resetPage: false)
            isLoadingMore = false
        }
    }
}

// MARK: - Card for favourites grid (image + title + price)
private struct FavouriteItemCard: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                ZStack(alignment: .bottomTrailing) {
                    RetryAsyncImage(
                        url: item.imageURLs.first.flatMap { URL(string: $0) },
                        width: size,
                        height: size,
                        cornerRadius: Theme.Glass.cornerRadius,
                        placeholder: {
                            ImageShimmerPlaceholderFilled(cornerRadius: Theme.Glass.cornerRadius)
                                .frame(width: size, height: size)
                        },
                        failurePlaceholder: {
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.Colors.secondaryText)
                                .frame(width: size, height: size)
                        }
                    )
                }
            }
            .aspectRatio(1, contentMode: .fit)

            Text(item.title)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.primaryText)
                .lineLimit(2)

            Text(item.formattedPrice)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.primaryColor)
        }
    }
}
