import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var allItems: [Item] = []
    @Published var filteredItems: [Item] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: String = "All"
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var hasMorePages: Bool = true
    
    private let productService = ProductService()
    private var currentPage = 1
    private let pageSize = 20

    func updateAuthToken(_ token: String?) {
        productService.updateAuthToken(token)
    }
    
    init() {
        loadData()
    }

    /// Toggle like for a product and update local state.
    func toggleLike(productId: String) {
        guard !productId.isEmpty, let item = allItems.first(where: { $0.productId == productId }) else { return }
        let newLiked = !item.isLiked
        Task {
            do {
                let (isLiked, likeCount) = try await productService.toggleLike(productId: productId, isLiked: newLiked)
                await MainActor.run {
                    let updated = item.with(likeCount: likeCount, isLiked: isLiked)
                    if let i = allItems.firstIndex(where: { $0.productId == productId }) {
                        allItems[i] = updated
                    }
                    if let j = filteredItems.firstIndex(where: { $0.productId == productId }) {
                        filteredItems[j] = updated
                    }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMorePages = true
        
        Task {
            do {
                // Use the current selectedCategory value
                let categoryFilter = selectedCategory == "All" ? nil : selectedCategory
                let products = try await productService.getAllProducts(
                    pageNumber: currentPage,
                    pageCount: pageSize,
                    parentCategory: categoryFilter
                )
                await MainActor.run {
                    self.allItems = products
                    self.filteredItems = products
                    self.isLoading = false
                    self.hasMorePages = products.count >= pageSize
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    print("❌ Error loading products: \(error.localizedDescription)")
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
                let products = try await productService.getAllProducts(
                    pageNumber: currentPage,
                    pageCount: pageSize,
                    search: searchText.isEmpty ? nil : searchText,
                    parentCategory: selectedCategory
                )
                await MainActor.run {
                    self.allItems.append(contentsOf: products)
                    self.filteredItems.append(contentsOf: products)
                    self.isLoadingMore = false
                    self.hasMorePages = products.count >= pageSize
                }
            } catch {
                await MainActor.run {
                    self.isLoadingMore = false
                    self.currentPage -= 1 // Revert page increment on error
                    print("❌ Load more error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func searchItems(query: String) {
        searchText = query
        // Reload data with search and category filters
        currentPage = 1
        hasMorePages = true
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let products = try await productService.getAllProducts(
                    pageNumber: currentPage,
                    pageCount: pageSize,
                    search: query.isEmpty ? nil : query,
                    parentCategory: selectedCategory
                )
                await MainActor.run {
                    self.allItems = products
                    self.filteredItems = products
                    self.isLoading = false
                    self.hasMorePages = products.count >= pageSize
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func filterByCategory(_ category: String) {
        selectedCategory = category
        // Reload data with new category filter
        currentPage = 1
        hasMorePages = true
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Use the current selectedCategory value (convert "All" to nil)
                let categoryFilter = selectedCategory == "All" ? nil : selectedCategory
                let products = try await productService.getAllProducts(
                    pageNumber: currentPage,
                    pageCount: pageSize,
                    parentCategory: categoryFilter
                )
                await MainActor.run {
                    self.allItems = products
                    self.filteredItems = products
                    self.isLoading = false
                    self.hasMorePages = products.count >= pageSize
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    print("❌ Error filtering by category '\(category)': \(error.localizedDescription)")
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
            errorMessage = nil
        }
        
        do {
            let products = try await productService.getAllProducts(
                pageNumber: 1,
                pageCount: pageSize,
                search: searchText.isEmpty ? nil : searchText,
                parentCategory: selectedCategory == "All" ? nil : selectedCategory
            )
            
            await MainActor.run {
                self.allItems = products
                self.filteredItems = products
                self.isLoading = false
                self.hasMorePages = products.count >= pageSize
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
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
                        self.filteredItems = searchResults
                    }
                } catch {
                    await MainActor.run {
                        print("❌ Search error: \(error.localizedDescription)")
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
