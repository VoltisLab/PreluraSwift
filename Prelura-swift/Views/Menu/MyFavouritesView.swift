import SwiftUI

/// Favourites: fetch liked products, grid, search, empty state. Matches Flutter MyFavouriteScreen.
struct MyFavouritesView: View {
    @State private var searchText: String = ""
    @State private var items: [Item] = []
    @State private var totalNumber: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var isLoadingMore = false

    private let productService = ProductService()
    private let pageCount = 20
    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.sm), GridItem(.flexible(), spacing: Theme.Spacing.sm)]

    private var filteredItems: [Item] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return items }
        return items.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            DiscoverSearchField(text: $searchText, placeholder: "Search favourites", outerPadding: false)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)

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
                    Text("No favourites yet")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text("Items you save as favourites will appear here.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.Spacing.xl)
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                Text("No results for \"\(searchText)\"")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                FavouriteItemCard(item: item)
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
                    .padding(.bottom, Theme.Spacing.lg)

                    if isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load(resetPage: true) }
        .task { await load(resetPage: true) }
    }

    private func load(resetPage: Bool) async {
        if resetPage {
            currentPage = 1
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
            errorMessage = error.localizedDescription
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
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                    .fill(Theme.Colors.secondaryBackground)
                    .aspectRatio(1, contentMode: .fit)
                if let first = item.imageURLs.first, let url = URL(string: first) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.Colors.secondaryText)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(Theme.Glass.cornerRadius)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }

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
