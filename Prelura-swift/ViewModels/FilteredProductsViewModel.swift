import Foundation
import SwiftUI
import Combine

@MainActor
class FilteredProductsViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var filteredItems: [Item] = []
    @Published var searchText: String = "" {
        didSet {
            applySearchFilter()
        }
    }
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var hasMorePages: Bool = true
    
    private var productService: ProductService
    private var client: GraphQLClient
    private let filterType: ProductFilterType
    private var currentPage = 1
    private let pageSize = 20
    
    init(filterType: ProductFilterType, authService: AuthService? = nil) {
        self.filterType = filterType
        self.client = GraphQLClient()
        
        if let authService = authService, let token = authService.authToken {
            self.client.setAuthToken(token)
        } else if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            self.client.setAuthToken(token)
        }
        
        self.productService = ProductService(client: self.client)
    }
    
    convenience init(filterType: ProductFilterType, authService: AuthService) {
        self.init(filterType: filterType, authService: authService)
    }
    
    func updateAuthToken(_ token: String?) {
        client.setAuthToken(token)
        productService.updateAuthToken(token)
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMorePages = true
        
        Task {
            do {
                let products = try await fetchProducts(page: 1)
                await MainActor.run {
                    self.items = products
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
    
    func loadMore() {
        guard !isLoadingMore && hasMorePages else { return }
        isLoadingMore = true
        
        Task {
            do {
                currentPage += 1
                let products = try await fetchProducts(page: currentPage)
                await MainActor.run {
                    self.items.append(contentsOf: products)
                    applySearchFilter()
                    self.isLoadingMore = false
                    self.hasMorePages = products.count >= pageSize
                }
            } catch {
                await MainActor.run {
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    func refreshAsync() async {
        await MainActor.run {
            isLoading = true
            currentPage = 1
            hasMorePages = true
        }
        
        do {
            let products = try await fetchProducts(page: 1)
            await MainActor.run {
                self.items = products
                applySearchFilter()
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
    
    private func fetchProducts(page: Int) async throws -> [Item] {
        switch filterType {
        case .onSale:
            return try await productService.getAllProducts(
                pageNumber: page,
                pageCount: pageSize,
                discountPrice: true
            )
        case .shopBargains:
            return try await productService.getAllProducts(
                pageNumber: page,
                pageCount: pageSize,
                maxPrice: 15
            )
        case .recentlyViewed:
            // Fetch recently viewed products from backend (like Flutter)
            if page == 1 {
                return try await productService.getRecentlyViewedProducts()
            } else {
                // Recently viewed doesn't support pagination, return empty for subsequent pages
                return []
            }
        case .brandsYouLove:
            // For now, return all products - this would need brand filtering
            return try await productService.getAllProducts(
                pageNumber: page,
                pageCount: pageSize
            )
        case .byBrand(let brandName):
            return try await productService.getAllProducts(
                pageNumber: page,
                pageCount: pageSize,
                search: brandName
            )
        case .bySize(let sizeName):
            return try await productService.getAllProducts(
                pageNumber: page,
                pageCount: pageSize,
                search: sizeName
            )
        }
    }
    
    private func applySearchFilter() {
        if searchText.isEmpty {
            filteredItems = items
        } else {
            filteredItems = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}
