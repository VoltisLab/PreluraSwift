import SwiftUI

/// Shown when a listing the user liked sells: similar GraphQL results plus optional search from server meta hints.
struct LikedItemSoldSimilarView: View {
    let soldProductId: String
    let categoryId: Int?
    let suggestionQuery: String

    @EnvironmentObject private var authService: AuthService
    private let productService = ProductService()

    @State private var similar: [Item] = []
    @State private var searchItems: [Item] = []
    @State private var isLoading = true
    @State private var errorText: String?

    private var combined: [Item] {
        var seen = Set<String>()
        var out: [Item] = []
        for item in similar + searchItems {
            let key = item.productId ?? "\(item.id)"
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(item)
        }
        return out
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorText, combined.isEmpty {
                Text(err)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text(L10n.string("An item you liked sold"))
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.primaryText)
                            .padding(.horizontal, Theme.Spacing.md)

                        Text(L10n.string("Similar picks from brand, size, and title keywords — plus related search results."))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .padding(.horizontal, Theme.Spacing.md)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                                GridItem(.flexible(), spacing: Theme.Spacing.sm)
                            ],
                            spacing: Theme.Spacing.md
                        ) {
                            ForEach(combined) { item in
                                NavigationLink(destination: ItemDetailView(item: item, authService: authService)) {
                                    HomeItemCard(item: item, onLikeTap: nil, hideLikeButton: true)
                                }
                                .buttonStyle(PlainTappableButtonStyle())
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Similar items"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            productService.updateAuthToken(authService.authToken)
        }
        .task {
            await load()
        }
    }

    private func load() async {
        productService.updateAuthToken(authService.authToken)
        await MainActor.run { isLoading = true; errorText = nil }
        let q = suggestionQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        async let similarTask: Result<[Item], Error> = {
            guard let pid = Int(soldProductId) else {
                return .success([])
            }
            do {
                let items = try await productService.getSimilarProducts(
                    productId: String(pid),
                    categoryId: categoryId,
                    pageNumber: 1,
                    pageCount: 24
                )
                return .success(items)
            } catch {
                return .failure(error)
            }
        }()

        async let searchTask: Result<[Item], Error> = {
            guard !q.isEmpty else { return .success([]) }
            do {
                let items = try await productService.searchProducts(query: q, pageNumber: 1, pageCount: 16)
                return .success(items)
            } catch {
                return .failure(error)
            }
        }()

        let simRes = await similarTask
        let seaRes = await searchTask

        let sItems: [Item] = {
            switch simRes {
            case .success(let v): return v.filter { $0.productId != soldProductId }
            case .failure: return []
            }
        }()
        let tItems: [Item] = {
            switch seaRes {
            case .success(let v): return v.filter { $0.productId != soldProductId }
            case .failure: return []
            }
        }()

        await MainActor.run {
            similar = sItems
            searchItems = tItems
            if case .failure(let err) = simRes, case .failure = seaRes {
                errorText = L10n.userFacingError(err)
            } else if combined.isEmpty {
                errorText = L10n.string("No similar items available yet")
            } else {
                errorText = nil
            }
            isLoading = false
        }
    }
}
