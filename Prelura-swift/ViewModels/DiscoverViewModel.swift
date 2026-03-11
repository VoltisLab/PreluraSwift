import Foundation
import SwiftUI
import Combine

struct ShopInfo: Identifiable {
    let id = UUID()
    let username: String
    let avatarURL: String?
}

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var discoverItems: [Item] = []
    @Published var recentlyViewedItems: [Item] = []
    @Published var brandsYouLoveItems: [Item] = []
    @Published var topShops: [ShopInfo] = []
    @Published var shopBargainsItems: [Item] = []
    @Published var onSaleItems: [Item] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var productService: ProductService
    private var client: GraphQLClient
    
    init(authService: AuthService? = nil) {
        // Create services with shared client that has auth token
        self.client = GraphQLClient()
        // Get token from authService or UserDefaults
        if let authService = authService, let token = authService.authToken {
            self.client.setAuthToken(token)
        } else if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            self.client.setAuthToken(token)
        }
        self.productService = ProductService(client: self.client)
        // Don't load in init - will be called from view
    }
    
    func updateAuthToken(_ token: String?) {
        client.setAuthToken(token)
        productService.updateAuthToken(token)
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Fetch all products for discover page
                let allProducts = try await productService.getAllProducts(
                    pageNumber: 1,
                    pageCount: 50 // Get more products for different sections
                )
                
                // Fetch discounted products separately using GraphQL filter (like Flutter)
                let onSaleProducts = try await productService.getAllProducts(
                    pageNumber: 1,
                    pageCount: 50,
                    discountPrice: true
                )
                
                // Fetch shop bargains (under £15) using GraphQL filter (like Flutter)
                let shopBargainsProducts = try await productService.getAllProducts(
                    pageNumber: 1,
                    pageCount: 50,
                    maxPrice: 15.0
                )
                
                // Fetch recently viewed products from backend (like Flutter)
                let recentlyViewedProducts = try await productService.getRecentlyViewedProducts()
                
                // Exclude items from sellers in vacation mode (hidden from catalogues)
                let allVisible = allProducts.excludingVacationModeSellers()
                let onSaleVisible = onSaleProducts.excludingVacationModeSellers()
                let shopBargainsVisible = shopBargainsProducts.excludingVacationModeSellers()
                let recentlyViewedVisible = recentlyViewedProducts.excludingVacationModeSellers()
                
                // Main product grid
                self.discoverItems = allVisible
                
                guard !allVisible.isEmpty else {
                    self.isLoading = false
                    return
                }
                
                // Recently viewed - newest first (match full page order)
                self.recentlyViewedItems = Array(recentlyViewedVisible.sorted { $0.createdAt > $1.createdAt }.prefix(10))
                
                var usedProductIds: Set<UUID> = Set(self.recentlyViewedItems.map { $0.id })
                
                // Brands You Love - get products with unique brands from all products
                // This should ideally use a GraphQL query for favorite brands, but for now use all products
                var brandsYouLove: [Item] = []
                var seenBrands: Set<String> = []
                
                for product in allVisible {
                    if let brand = product.brand, !seenBrands.contains(brand), !usedProductIds.contains(product.id) {
                        brandsYouLove.append(product)
                        seenBrands.insert(brand)
                        usedProductIds.insert(product.id)
                        if brandsYouLove.count >= 5 { break }
                    }
                }
                
                // If we don't have enough, fill with any products not already used
                if brandsYouLove.count < 5 {
                    let remaining = allVisible.filter { !usedProductIds.contains($0.id) }
                    brandsYouLove.append(contentsOf: remaining.prefix(5 - brandsYouLove.count))
                }
                self.brandsYouLoveItems = Array(brandsYouLove.prefix(5))
                
                // Update used product IDs
                usedProductIds.formUnion(Set(self.brandsYouLoveItems.map { $0.id }))
                
                // Top Shops - extract unique seller info (username + avatar) from all products
                // This should ideally use a GraphQL query for top shops, but for now use all products
                var shopMap: [String: (username: String, avatarURL: String?)] = [:]
                for product in allVisible {
                    let username = product.seller.username
                    if shopMap[username] == nil && !username.isEmpty {
                        shopMap[username] = (username: username, avatarURL: product.seller.avatarURL)
                    }
                }
                self.topShops = Array(shopMap.values.prefix(10)).map { shopInfo in
                    ShopInfo(username: shopInfo.username, avatarURL: shopInfo.avatarURL)
                }
                
                // Shop Bargains - use the separately fetched products under £15, excluding already used products
                let availableBargains = shopBargainsVisible.filter { !usedProductIds.contains($0.id) }
                if availableBargains.count >= 5 {
                    self.shopBargainsItems = Array(availableBargains.prefix(5))
                } else {
                    // If not enough bargains, use what we have
                    self.shopBargainsItems = availableBargains
                }
                
                // Update used product IDs
                usedProductIds.formUnion(Set(self.shopBargainsItems.map { $0.id }))
                
                // On Sale - use the separately fetched discounted products, excluding already used products
                let availableOnSale = onSaleVisible.filter { !usedProductIds.contains($0.id) }
                if availableOnSale.count >= 5 {
                    self.onSaleItems = Array(availableOnSale.prefix(5))
                } else {
                    // If not enough on sale, use what we have
                    self.onSaleItems = availableOnSale
                }
                print("🛍️ On Sale items: \(self.onSaleItems.count) products")
                if !self.onSaleItems.isEmpty {
                    print("🛍️ First on sale item: \(self.onSaleItems.first?.title ?? "N/A")")
                }
                
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = L10n.userFacingError(error)
                print("❌ Discover load error: \(error.localizedDescription)")
            }
        }
    }
    
    func refresh() {
        loadData()
    }

    /// Refetches only recently viewed from the backend (e.g. after user views a product). Keeps rest of discover data unchanged. Order: newest first.
    func refreshRecentlyViewedSection() {
        Task {
            do {
                let recentlyViewedProducts = try await productService.getRecentlyViewedProducts()
                let recentlyViewedVisible = recentlyViewedProducts.excludingVacationModeSellers()
                    .sorted { $0.createdAt > $1.createdAt }
                await MainActor.run {
                    self.recentlyViewedItems = Array(recentlyViewedVisible.prefix(10))
                }
            } catch {
                // Keep existing list on error
            }
        }
    }

    /// Toggle like for a product and update it in all relevant arrays.
    func toggleLike(productId: String) {
        guard !productId.isEmpty else { return }
        let current = discoverItems.first(where: { $0.productId == productId })
            ?? recentlyViewedItems.first(where: { $0.productId == productId })
            ?? brandsYouLoveItems.first(where: { $0.productId == productId })
            ?? shopBargainsItems.first(where: { $0.productId == productId })
            ?? onSaleItems.first(where: { $0.productId == productId })
        guard let item = current else { return }
        Task {
            do {
                let (isLiked, likeCount) = try await productService.toggleLike(productId: productId, isLiked: !item.isLiked)
                await MainActor.run {
                    let updated = item.with(likeCount: likeCount, isLiked: isLiked)
                    discoverItems = discoverItems.replacingItem(productId: productId, with: updated)
                    recentlyViewedItems = recentlyViewedItems.replacingItem(productId: productId, with: updated)
                    brandsYouLoveItems = brandsYouLoveItems.replacingItem(productId: productId, with: updated)
                    shopBargainsItems = shopBargainsItems.replacingItem(productId: productId, with: updated)
                    onSaleItems = onSaleItems.replacingItem(productId: productId, with: updated)
                }
            } catch {
                await MainActor.run { errorMessage = L10n.userFacingError(error) }
            }
        }
    }
    
    func refreshAsync() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            discoverItems = []
            recentlyViewedItems = []
            brandsYouLoveItems = []
            topShops = []
            shopBargainsItems = []
            onSaleItems = []
        }
        
        do {
            let allProducts = try await productService.getAllProducts(
                pageNumber: 1,
                pageCount: 50
            )
            
            // Fetch discounted products separately using GraphQL filter (like Flutter)
            let onSaleProducts = try await productService.getAllProducts(
                pageNumber: 1,
                pageCount: 50,
                discountPrice: true
            )
            
            // Fetch shop bargains (under £15) using GraphQL filter (like Flutter)
            let shopBargainsProducts = try await productService.getAllProducts(
                pageNumber: 1,
                pageCount: 50,
                maxPrice: 15.0
            )
            
            // Fetch recently viewed products from backend (like Flutter)
            let recentlyViewedProducts = try await productService.getRecentlyViewedProducts()
            
            let allVisible = allProducts.excludingVacationModeSellers()
            let onSaleVisible = onSaleProducts.excludingVacationModeSellers()
            let shopBargainsVisible = shopBargainsProducts.excludingVacationModeSellers()
            let recentlyViewedVisible = recentlyViewedProducts.excludingVacationModeSellers()
            
            await MainActor.run {
                self.discoverItems = allVisible
                
                guard !allVisible.isEmpty else {
                    self.isLoading = false
                    return
                }
                
                // Recently viewed - newest first (match full page order)
                self.recentlyViewedItems = Array(recentlyViewedVisible.sorted { $0.createdAt > $1.createdAt }.prefix(10))
                
                var usedProductIds: Set<UUID> = Set(self.recentlyViewedItems.map { $0.id })
                
                // Brands You Love - get products with unique brands from all products
                var brandsYouLove: [Item] = []
                var seenBrands: Set<String> = []
                
                for product in allVisible {
                    if let brand = product.brand, !seenBrands.contains(brand), !usedProductIds.contains(product.id) {
                        brandsYouLove.append(product)
                        seenBrands.insert(brand)
                        usedProductIds.insert(product.id)
                        if brandsYouLove.count >= 5 { break }
                    }
                }
                
                if brandsYouLove.count < 5 {
                    let remaining = allVisible.filter { !usedProductIds.contains($0.id) }
                    brandsYouLove.append(contentsOf: remaining.prefix(5 - brandsYouLove.count))
                }
                self.brandsYouLoveItems = Array(brandsYouLove.prefix(5))
                
                usedProductIds.formUnion(Set(self.brandsYouLoveItems.map { $0.id }))
                
                // Top Shops - extract unique seller info from all products
                var shopMap: [String: (username: String, avatarURL: String?)] = [:]
                for product in allVisible {
                    let username = product.seller.username
                    if shopMap[username] == nil && !username.isEmpty {
                        shopMap[username] = (username: username, avatarURL: product.seller.avatarURL)
                    }
                }
                self.topShops = Array(shopMap.values.prefix(10)).map { shopInfo in
                    ShopInfo(username: shopInfo.username, avatarURL: shopInfo.avatarURL)
                }
                
                // Shop Bargains - use the separately fetched products under £15
                let availableBargains = shopBargainsVisible.filter { !usedProductIds.contains($0.id) }
                if availableBargains.count >= 5 {
                    self.shopBargainsItems = Array(availableBargains.prefix(5))
                } else {
                    self.shopBargainsItems = availableBargains
                }
                
                usedProductIds.formUnion(Set(self.shopBargainsItems.map { $0.id }))
                
                // On Sale - use the separately fetched discounted products, excluding already used products
                let availableOnSale = onSaleVisible.filter { !usedProductIds.contains($0.id) }
                if availableOnSale.count >= 5 {
                    self.onSaleItems = Array(availableOnSale.prefix(5))
                } else {
                    self.onSaleItems = availableOnSale
                }
                print("🛍️ On Sale items (refresh): \(self.onSaleItems.count) products")
                
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = L10n.userFacingError(error)
            }
        }
    }
}
