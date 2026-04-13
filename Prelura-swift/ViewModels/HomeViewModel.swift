import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var allItems: [Item] = []
    @Published var filteredItems: [Item] = []
    /// Staff-curated Discover featured picks; own section on Home when not searching.
    @Published var featuredItems: [Item] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: String = "All"
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    /// Short banner headline for TLS / secure transport (see `L10n.userFacingErrorBannerTitle`).
    @Published var errorBannerTitle: String?
    @Published var hasMorePages: Bool = true
    /// When AI search mapped a colour alias (e.g. "camo" → "Green"), show this hint.
    @Published var searchClosestMatchHint: String?
    
    private let productService = ProductService()
    private var currentPage = 1
    private let pageSize = 20

    private func clearNetworkError() {
        errorMessage = nil
        errorBannerTitle = nil
    }

    private func setNetworkError(_ error: Error) {
        errorMessage = L10n.userFacingError(error)
        errorBannerTitle = L10n.userFacingErrorBannerTitle(error)
    }

    func updateAuthToken(_ token: String?) {
        productService.updateAuthToken(token)
    }
    
    init() {
        loadData()
    }

    /// Toggle like for a product and update local state. Applies optimistic update so the heart/count change immediately on tap.
    func toggleLike(productId: String) {
        guard !productId.isEmpty else { return }
        let item = allItems.first(where: { $0.productId == productId })
            ?? featuredItems.first(where: { $0.productId == productId })
        guard let item else { return }
        let newLiked = !item.isLiked
        let newCount = item.likeCount + (newLiked ? 1 : -1)
        let optimistic = item.with(likeCount: max(0, newCount), isLiked: newLiked)
        if let i = allItems.firstIndex(where: { $0.productId == productId }) {
            allItems[i] = optimistic
        }
        if let j = filteredItems.firstIndex(where: { $0.productId == productId }) {
            filteredItems[j] = optimistic
        }
        if let k = featuredItems.firstIndex(where: { $0.productId == productId }) {
            featuredItems[k] = optimistic
        }
        Task {
            do {
                let result = try await productService.toggleLike(productId: productId, isLiked: newLiked)
                await MainActor.run {
                    let count = result.likeCount ?? optimistic.likeCount
                    let updated = item.with(likeCount: count, isLiked: result.isLiked)
                    if let i = allItems.firstIndex(where: { $0.productId == productId }) {
                        allItems[i] = updated
                    }
                    if let j = filteredItems.firstIndex(where: { $0.productId == productId }) {
                        filteredItems[j] = updated
                    }
                    if let k = featuredItems.firstIndex(where: { $0.productId == productId }) {
                        featuredItems[k] = updated
                    }
                }
            } catch {
                await MainActor.run {
                    // Keep optimistic state so the heart doesn't flip back; surface error for user
                    setNetworkError(error)
                }
            }
        }
    }

    /// Deduped featured slice for the Home section (max 20, active sellers only).
    private static func featuredSectionItems(from featured: [Item]) -> [Item] {
        let f = featured.excludingVacationModeSellers().excludingSold()
        var seen = Set<UUID>()
        var out: [Item] = []
        for item in f.prefix(20) {
            if seen.insert(item.id).inserted { out.append(item) }
        }
        return out
    }

    /// Staff-curated featured list for "See all" (deduped, no count cap).
    static func allFeaturedItems(from featured: [Item]) -> [Item] {
        let f = featured.excludingVacationModeSellers().excludingSold()
        var seen = Set<UUID>()
        var out: [Item] = []
        for item in f {
            if seen.insert(item.id).inserted { out.append(item) }
        }
        return out
    }

    func loadData() {
        isLoading = true
        clearNetworkError()
        currentPage = 1
        hasMorePages = true
        
        Task {
            do {
                let categoryFilter = selectedCategory == "All" ? nil : selectedCategory
                let search = searchText.isEmpty ? nil : searchText
                let hideFeatured = !(search ?? "").isEmpty
                if hideFeatured {
                    let products = try await productService.getAllProducts(
                        pageNumber: currentPage,
                        pageCount: pageSize,
                        search: search,
                        parentCategory: categoryFilter
                    )
                    let visible = products.excludingVacationModeSellers().excludingSold()
                    await MainActor.run {
                        self.featuredItems = []
                        self.allItems = visible
                        self.filteredItems = visible
                        self.isLoading = false
                        self.hasMorePages = products.count >= pageSize
                    }
                } else {
                    async let featuredTask = productService.getDiscoverFeaturedProducts()
                    let products = try await productService.getAllProducts(
                        pageNumber: currentPage,
                        pageCount: pageSize,
                        search: nil,
                        parentCategory: categoryFilter
                    )
                    let visible = products.excludingVacationModeSellers().excludingSold()
                    await MainActor.run {
                        self.allItems = visible
                        self.filteredItems = visible
                        self.isLoading = false
                        self.hasMorePages = products.count >= pageSize
                    }
                    let featured = (try? await featuredTask) ?? []
                    await MainActor.run {
                        self.featuredItems = Self.featuredSectionItems(from: featured)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.setNetworkError(error)
                    print("Error loading products: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func loadMore() {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            do {
                let categoryFilter = selectedCategory == "All" ? nil : selectedCategory
                let products = try await productService.getAllProducts(
                    pageNumber: currentPage,
                    pageCount: pageSize,
                    search: searchText.isEmpty ? nil : searchText,
                    parentCategory: categoryFilter
                )
                await MainActor.run {
                    let visible = products.excludingVacationModeSellers().excludingSold()
                    let existing = Set(self.allItems.map(\.id))
                    let newOnly = visible.filter { !existing.contains($0.id) }
                    self.allItems.append(contentsOf: newOnly)
                    self.filteredItems.append(contentsOf: newOnly)
                    self.isLoadingMore = false
                    self.hasMorePages = products.count >= pageSize
                }
            } catch {
                await MainActor.run {
                    self.isLoadingMore = false
                    self.currentPage -= 1 // Revert page increment on error
                    print("Load more error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func searchItems(query: String) {
        searchText = query
        searchClosestMatchHint = nil
        runSearch(search: query.isEmpty ? nil : query, category: selectedCategory)
    }
    
    /// After the user clears the system search field (or Home tab clears `searchText`), restore featured feed and hints.
    func reloadFeedAfterSearchEmptied() {
        searchClosestMatchHint = nil
        loadData()
    }

    /// Run search using AI-parsed result (colours/categories resolved; hint for "closest to").
    func searchWithParsed(_ parsed: ParsedSearch) {
        // Keep the user's typed text in the field; only the network query uses parsed terms.
        searchClosestMatchHint = parsed.closestMatchHint
        if let cat = parsed.categoryOverride, !cat.isEmpty {
            selectedCategory = cat
        }
        let categoryFilter = selectedCategory == "All" ? nil : selectedCategory
        runSearch(search: parsed.searchText.isEmpty ? nil : parsed.searchText, category: categoryFilter ?? selectedCategory)
    }
    
    private func runSearch(search: String?, category: String?) {
        currentPage = 1
        hasMorePages = true
        isLoading = true
        clearNetworkError()
        let categoryFilter = (category == "All" || category == nil) ? nil : category
        
        Task {
            do {
                let hideFeatured = search.map { !$0.isEmpty } ?? false
                if hideFeatured {
                    let products = try await productService.getAllProducts(
                        pageNumber: currentPage,
                        pageCount: pageSize,
                        search: search,
                        parentCategory: categoryFilter
                    )
                    let visible = products.excludingVacationModeSellers().excludingSold()
                    await MainActor.run {
                        self.featuredItems = []
                        self.allItems = visible
                        self.filteredItems = visible
                        self.isLoading = false
                        self.hasMorePages = products.count >= pageSize
                    }
                } else {
                    async let featuredTask = productService.getDiscoverFeaturedProducts()
                    let products = try await productService.getAllProducts(
                        pageNumber: currentPage,
                        pageCount: pageSize,
                        search: search,
                        parentCategory: categoryFilter
                    )
                    let visible = products.excludingVacationModeSellers().excludingSold()
                    await MainActor.run {
                        self.allItems = visible
                        self.filteredItems = visible
                        self.isLoading = false
                        self.hasMorePages = products.count >= pageSize
                    }
                    let featured = (try? await featuredTask) ?? []
                    await MainActor.run {
                        self.featuredItems = Self.featuredSectionItems(from: featured)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.setNetworkError(error)
                }
            }
        }
    }
    
    func filterByCategory(_ category: String) {
        selectedCategory = category
        // Reload with new category; keep an active search query if the user is searching.
        currentPage = 1
        hasMorePages = true
        isLoading = true
        clearNetworkError()
        
        Task {
            do {
                let categoryFilter = selectedCategory == "All" ? nil : selectedCategory
                let search = searchText.isEmpty ? nil : searchText
                let hideFeatured = !(search ?? "").isEmpty
                if hideFeatured {
                    let products = try await productService.getAllProducts(
                        pageNumber: currentPage,
                        pageCount: pageSize,
                        search: search,
                        parentCategory: categoryFilter
                    )
                    let visible = products.excludingVacationModeSellers().excludingSold()
                    await MainActor.run {
                        self.featuredItems = []
                        self.allItems = visible
                        self.filteredItems = visible
                        self.isLoading = false
                        self.hasMorePages = products.count >= pageSize
                    }
                } else {
                    async let featuredTask = productService.getDiscoverFeaturedProducts()
                    let products = try await productService.getAllProducts(
                        pageNumber: currentPage,
                        pageCount: pageSize,
                        search: nil,
                        parentCategory: categoryFilter
                    )
                    let visible = products.excludingVacationModeSellers().excludingSold()
                    await MainActor.run {
                        self.allItems = visible
                        self.filteredItems = visible
                        self.isLoading = false
                        self.hasMorePages = products.count >= pageSize
                    }
                    let featured = (try? await featuredTask) ?? []
                    await MainActor.run {
                        self.featuredItems = Self.featuredSectionItems(from: featured)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.setNetworkError(error)
                    print("Error filtering by category '\(category)': \(error.localizedDescription)")
                }
            }
        }
    }
    
    func refresh() {
        currentPage = 1
        loadData()
    }
    
    func refreshAsync() async {
        await MainActor.run {
            currentPage = 1
            hasMorePages = true
            isLoading = true
            clearNetworkError()
        }
        
        do {
            let categoryFilter = selectedCategory == "All" ? nil : selectedCategory
            let search = searchText.isEmpty ? nil : searchText
            if search != nil {
                let products = try await productService.getAllProducts(
                    pageNumber: 1,
                    pageCount: pageSize,
                    search: search,
                    parentCategory: categoryFilter
                )
                let visible = products.excludingVacationModeSellers().excludingSold()
                await MainActor.run {
                    self.featuredItems = []
                    self.allItems = visible
                    self.filteredItems = visible
                    self.isLoading = false
                    self.hasMorePages = products.count >= pageSize
                }
            } else {
                async let featuredTask = productService.getDiscoverFeaturedProducts()
                let products = try await productService.getAllProducts(
                    pageNumber: 1,
                    pageCount: pageSize,
                    search: nil,
                    parentCategory: categoryFilter
                )
                let visible = products.excludingVacationModeSellers().excludingSold()
                await MainActor.run {
                    self.allItems = visible
                    self.filteredItems = visible
                    self.isLoading = false
                    self.hasMorePages = products.count >= pageSize
                }
                let featured = (try? await featuredTask) ?? []
                await MainActor.run {
                    self.featuredItems = Self.featuredSectionItems(from: featured)
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.setNetworkError(error)
            }
        }
    }
    
    private func applyFilters() {
        // This is now handled by reloading from API with filters
        // Keeping for backward compatibility but filters are applied server-side
        var filtered = allItems
        
        // Search filter - use GraphQL search parameter
        if !searchText.isEmpty {
            Task {
                do {
                    let searchResults = try await productService.getAllProducts(
                        pageNumber: 1,
                        pageCount: pageSize,
                        search: searchText,
                        parentCategory: selectedCategory
                    )
                    await MainActor.run {
                        self.filteredItems = searchResults.excludingVacationModeSellers().excludingSold()
                    }
                } catch {
                    await MainActor.run {
                        print("Search error: \(error.localizedDescription)")
                        // Fallback to client-side filtering
                        filtered = filtered.filter {
                            $0.title.localizedCaseInsensitiveContains(searchText) ||
                            $0.description.localizedCaseInsensitiveContains(searchText) ||
                            ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
                        }
                        self.filteredItems = filtered
                    }
                }
            }
        } else {
            filteredItems = filtered
        }
    }
}
