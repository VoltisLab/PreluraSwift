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

    /// Staggered Discover rows: each clears when that slice is ready (Shop Categories / banners stay static in the view).
    @Published var isLoadingRecentlyViewedSection: Bool = false
    @Published var isLoadingBrandsYouLoveSection: Bool = false
    @Published var isLoadingTopShopsSection: Bool = false
    @Published var isLoadingShopBargainsSection: Bool = false
    @Published var isLoadingOnSaleSection: Bool = false

    private var productService: ProductService
    private var userService: UserService
    private var client: GraphQLClient

    init(authService: AuthService? = nil) {
        self.client = GraphQLClient()
        if let authService = authService, let token = authService.authToken {
            self.client.setAuthToken(token)
        } else if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            self.client.setAuthToken(token)
        }
        self.productService = ProductService(client: self.client)
        self.userService = UserService(client: self.client)
    }

    func updateAuthToken(_ token: String?) {
        client.setAuthToken(token)
        productService.updateAuthToken(token)
        userService.updateAuthToken(token)
    }

    func loadData() {
        prepareDiscoverLoadSync()
        Task {
            await executeDiscoverLoad()
        }
    }

    func refresh() {
        loadData()
    }

    /// Sets loading flags immediately so the Discover UI can show per-section shimmers before the async task runs.
    private func prepareDiscoverLoadSync() {
        isLoading = true
        errorMessage = nil
        setAllSectionLoading(true)
    }

    /// Refetches only recently viewed from the backend (e.g. after user views a product). Keeps rest of discover data unchanged. Order: newest first.
    func refreshRecentlyViewedSection() {
        Task {
            do {
                async let featuredTask = productService.getDiscoverFeaturedProducts()
                async let recentTask = productService.getRecentlyViewedProducts()
                let (featured, recent) = try await (featuredTask, recentTask)
                let merged = [Item].mergedDiscoverRecentlyStrip(
                    featured: featured,
                    recentlyViewed: recent,
                    maxTotal: 5
                )
                await MainActor.run {
                    self.recentlyViewedItems = merged
                }
            } catch {
                // Keep existing list on error
            }
        }
    }

    /// Toggle like for a product and update it in all relevant arrays. Optimistic update so heart/count change immediately.
    func toggleLike(productId: String) {
        guard !productId.isEmpty else { return }
        let current = discoverItems.first(where: { $0.productId == productId })
            ?? recentlyViewedItems.first(where: { $0.productId == productId })
            ?? brandsYouLoveItems.first(where: { $0.productId == productId })
            ?? shopBargainsItems.first(where: { $0.productId == productId })
            ?? onSaleItems.first(where: { $0.productId == productId })
        guard let item = current else { return }
        let newLiked = !item.isLiked
        let newCount = item.likeCount + (newLiked ? 1 : -1)
        let optimistic = item.with(likeCount: max(0, newCount), isLiked: newLiked)
        discoverItems = discoverItems.replacingItem(productId: productId, with: optimistic)
        recentlyViewedItems = recentlyViewedItems.replacingItem(productId: productId, with: optimistic)
        brandsYouLoveItems = brandsYouLoveItems.replacingItem(productId: productId, with: optimistic)
        shopBargainsItems = shopBargainsItems.replacingItem(productId: productId, with: optimistic)
        onSaleItems = onSaleItems.replacingItem(productId: productId, with: optimistic)
        Task {
            do {
                let result = try await productService.toggleLike(productId: productId, isLiked: newLiked)
                await MainActor.run {
                    let count = result.likeCount ?? optimistic.likeCount
                    let updated = item.with(likeCount: count, isLiked: result.isLiked)
                    discoverItems = discoverItems.replacingItem(productId: productId, with: updated)
                    recentlyViewedItems = recentlyViewedItems.replacingItem(productId: productId, with: updated)
                    brandsYouLoveItems = brandsYouLoveItems.replacingItem(productId: productId, with: updated)
                    shopBargainsItems = shopBargainsItems.replacingItem(productId: productId, with: updated)
                    onSaleItems = onSaleItems.replacingItem(productId: productId, with: updated)
                }
            } catch {
                await MainActor.run {
                    errorMessage = L10n.userFacingError(error)
                }
            }
        }
    }

    func refreshAsync() async {
        prepareDiscoverLoadSync()
        await executeDiscoverLoad()
    }

    // MARK: - Staggered load (parallel network, sequential UI updates)

    private func setAllSectionLoading(_ pending: Bool) {
        isLoadingRecentlyViewedSection = pending
        isLoadingBrandsYouLoveSection = pending
        isLoadingTopShopsSection = pending
        isLoadingShopBargainsSection = pending
        isLoadingOnSaleSection = pending
    }

    private func clearAllSectionLoading() {
        setAllSectionLoading(false)
    }

    private func executeDiscoverLoad() async {
        StartupTiming.mark("DiscoverViewModel.executeDiscoverLoad - started")

        do {
            async let recentlyViewedTask = productService.getRecentlyViewedProducts()
            async let discoverFeaturedTask = productService.getDiscoverFeaturedProducts()
            async let allProductsTask = productService.getAllProducts(pageNumber: 1, pageCount: 50)
            async let onSaleTask = productService.getAllProducts(pageNumber: 1, pageCount: 50, discountPrice: true)
            async let shopBargainsTask = productService.getAllProducts(pageNumber: 1, pageCount: 50, maxPrice: 15.0)
            async let recommendedTask = userService.getRecommendedSellers(pageNumber: 1, pageCount: 20)
            async let featuredShopsTask = userService.getDiscoverFeaturedShops()

            // 1) Recently viewed - does not depend on full catalog.
            let (recentlyViewedProducts, discoverFeatured) = try await (recentlyViewedTask, discoverFeaturedTask)
            let recentlyViewedVisible = recentlyViewedProducts.excludingVacationModeSellers().excludingSold()
            recentlyViewedItems = [Item].mergedDiscoverRecentlyStrip(
                featured: discoverFeatured,
                recentlyViewed: recentlyViewedVisible,
                maxTotal: 5
            )
            isLoadingRecentlyViewedSection = false
            StartupTiming.mark("DiscoverViewModel - recently viewed section ready")

            // 2) Main grid + Brands you love (needs catalog).
            let allProducts = try await allProductsTask
            let allVisible = allProducts.excludingVacationModeSellers().excludingSold()
            discoverItems = allVisible

            if allVisible.isEmpty {
                brandsYouLoveItems = []
                topShops = []
                shopBargainsItems = []
                onSaleItems = []
                clearAllSectionLoading()
                isLoading = false
                StartupTiming.mark("DiscoverViewModel.loadDiscoverContent - empty catalog")
                return
            }

            var usedProductIds: Set<UUID> = Set(recentlyViewedItems.map { $0.id })

            let nonMysteryVisible = allVisible.filter { !$0.isMysteryBox }

            var brandsYouLove: [Item] = []
            var seenBrands: Set<String> = []
            for product in nonMysteryVisible {
                if let brand = product.brand, !seenBrands.contains(brand), !usedProductIds.contains(product.id) {
                    brandsYouLove.append(product)
                    seenBrands.insert(brand)
                    usedProductIds.insert(product.id)
                    if brandsYouLove.count >= 5 { break }
                }
            }
            if brandsYouLove.count < 5 {
                let remaining = nonMysteryVisible.filter { !usedProductIds.contains($0.id) }
                brandsYouLove.append(contentsOf: remaining.prefix(5 - brandsYouLove.count))
            }
            brandsYouLoveItems = Array(brandsYouLove.prefix(5))
            usedProductIds.formUnion(Set(brandsYouLoveItems.map { $0.id }))
            isLoadingBrandsYouLoveSection = false
            StartupTiming.mark("DiscoverViewModel - brands you love section ready")

            // 3) Top shops - prefer curated list, fallback to recommended ranking.
            let featuredShops = (try? await featuredShopsTask) ?? []
            if !featuredShops.isEmpty {
                topShops = featuredShops.map { rec in
                    ShopInfo(username: rec.seller.username, avatarURL: rec.seller.avatarURL)
                }
            } else if let recommended = try? await recommendedTask {
                topShops = recommended.map { rec in
                    ShopInfo(username: rec.seller.username, avatarURL: rec.seller.avatarURL)
                }
            } else {
                var shopMap: [String: (username: String, avatarURL: String?)] = [:]
                for product in allVisible {
                    let username = product.seller.username
                    if shopMap[username] == nil && !username.isEmpty {
                        shopMap[username] = (username: username, avatarURL: product.seller.avatarURL)
                    }
                }
                topShops = Array(shopMap.values.prefix(10)).map { shopInfo in
                    ShopInfo(username: shopInfo.username, avatarURL: shopInfo.avatarURL)
                }
            }
            isLoadingTopShopsSection = false
            StartupTiming.mark("DiscoverViewModel - top shops section ready")

            // 4–5) Bargains + on sale (fetches started at t0; merge uses `usedProductIds` after brands).
            let (onSaleProducts, shopBargainsProducts) = try await (onSaleTask, shopBargainsTask)
            let onSaleVisible = onSaleProducts.excludingVacationModeSellers().excludingSold()
            let shopBargainsVisible = shopBargainsProducts.excludingVacationModeSellers().excludingSold()

            let availableBargains = shopBargainsVisible.filter { !usedProductIds.contains($0.id) }
            if availableBargains.count >= 5 {
                shopBargainsItems = Array(availableBargains.prefix(5))
            } else {
                shopBargainsItems = availableBargains
            }
            usedProductIds.formUnion(Set(shopBargainsItems.map { $0.id }))
            isLoadingShopBargainsSection = false
            StartupTiming.mark("DiscoverViewModel - shop bargains section ready")

            let availableOnSale = onSaleVisible.filter { !usedProductIds.contains($0.id) }
            if availableOnSale.count >= 5 {
                onSaleItems = Array(availableOnSale.prefix(5))
            } else {
                onSaleItems = availableOnSale
            }
            isLoadingOnSaleSection = false

            isLoading = false
            StartupTiming.mark("DiscoverViewModel.loadDiscoverContent - success (all sections)")
        } catch {
            isLoading = false
            clearAllSectionLoading()
            errorMessage = L10n.userFacingError(error)
            StartupTiming.mark("DiscoverViewModel.loadDiscoverContent - failed: \(error.localizedDescription)")
            print("❌ Discover load error: \(error.localizedDescription)")
        }
    }
}
