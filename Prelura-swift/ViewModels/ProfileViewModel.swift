import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var userItems: [Item] = []
    /// Prefetched with `getUser` so seller multi-buy settings open without a cold `userMultibuyDiscounts` call.
    @Published var multibuyDiscounts: [MultibuyDiscount] = []
    @Published var isMenuVisible: Bool = false
    /// True only while `viewMe` is in flight on first paint (`user == nil`). Pull-to-refresh does not set this.
    @Published var isLoading: Bool = false
    /// Listings + multibuy load after profile; grid can show a spinner while this is true.
    @Published var isLoadingProducts: Bool = false
    @Published var errorMessage: String?
    @Published var errorBannerTitle: String?
    
    var topBrands: [String] {
        // Extract unique brands from userItems, sorted by frequency then by name so order is stable when view re-renders.
        let brandCounts = Dictionary(grouping: userItems.compactMap { $0.brand }, by: { $0 })
            .mapValues { $0.count }
            .sorted { a, b in
                if a.value != b.value { return a.value > b.value }
                return a.key.localizedCompare(b.key) == .orderedAscending
            }
        return Array(brandCounts.prefix(10).map { $0.key })
    }
    
    var categoriesWithCounts: [(name: String, count: Int)] {
        // Group items by actual category name from API (subcategories like "Blouses", "Dresses", etc.)
        // Use categoryName if available, otherwise fall back to category.name
        let categoryCounts = Dictionary(grouping: userItems, by: { $0.categoryName ?? $0.category.name })
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
        
        return categoryCounts
    }
    
    private var userService: UserService
    private var productService: ProductService
    private var fileUploadService: FileUploadService
    private var client: GraphQLClient

    @Published var isUploadingProfilePhoto: Bool = false
    @Published var profilePhotoUploadError: String?

    init(authService: AuthService? = nil) {
        // Create services with shared client that has auth token
        self.client = GraphQLClient()
        // Get token from authService or UserDefaults
        if let authService = authService, let token = authService.authToken {
            self.client.setAuthToken(token)
        } else if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            self.client.setAuthToken(token)
        }
        self.userService = UserService(client: self.client)
        self.productService = ProductService(client: self.client)
        self.fileUploadService = FileUploadService()
        if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            self.fileUploadService.setAuthToken(token)
        }
        // Don't load in init - will be called from view
    }

    func updateAuthToken(_ token: String?) {
        client.setAuthToken(token)
        userService.updateAuthToken(token)
        productService.updateAuthToken(token)
        fileUploadService.setAuthToken(token)
    }
    
    func loadUserData() async {
        let blockFullScreenShimmer = await MainActor.run { user == nil }
        await MainActor.run {
            if blockFullScreenShimmer {
                isLoading = true
            }
            errorMessage = nil
            errorBannerTitle = nil
        }

        let previousMultibuyTiers = multibuyDiscounts
        do {
            // 1) `viewMe` first so the header can render. `userProducts` is not allowed under some bans;
            // applying profile before listings avoids an empty tab title when listings fail.
            let fetchedUser = try await userService.getUser()
            await MainActor.run {
                self.user = fetchedUser
                if blockFullScreenShimmer {
                    self.isLoading = false
                }
                self.isLoadingProducts = true
            }
            // 2) Listings + multibuy in parallel after profile is on-screen.
            async let productsTask = userService.getUserProducts()
            async let multibuyTask = userService.getMultibuyDiscounts(userId: nil)
            async let soldOrdersTask: [Order] = {
                (try? await userService.getUserOrders(isSeller: true, pageNumber: 1, pageCount: 80))?.orders ?? []
            }()
            let products = (try? await productsTask) ?? []
            let tiers: [MultibuyDiscount]
            do {
                tiers = try await multibuyTask
            } catch {
                tiers = previousMultibuyTiers
            }
            let soldOrders = await soldOrdersTask
            let mergedProducts = Self.mergeSellerProductsWithSoldOrders(
                products,
                seller: fetchedUser,
                soldOrders: soldOrders
            )
            await MainActor.run {
                self.userItems = mergedProducts
                self.multibuyDiscounts = tiers
                self.isLoadingProducts = false
            }
        } catch {
            await MainActor.run {
                if blockFullScreenShimmer {
                    self.isLoading = false
                }
                self.isLoadingProducts = false
                self.errorMessage = L10n.userFacingError(error)
                self.errorBannerTitle = L10n.userFacingErrorBannerTitle(error)
                print("❌ Profile load error: \(error.localizedDescription)")
                print("❌ Error details: \(error)")
                if let graphQLError = error as? GraphQLError {
                    print("❌ GraphQL Error: \(graphQLError)")
                }
            }
        }
    }
    
    func refresh() {
        Task {
            await loadUserData()
        }
    }
    
    func refreshAsync() async {
        await MainActor.run {
            errorMessage = nil
            errorBannerTitle = nil
        }
        await loadUserData()
    }

    /// Toggle like for a product and update userItems. Optimistic update so heart doesn't flip back on API failure.
    func toggleLike(productId: String) {
        guard !productId.isEmpty, let item = userItems.first(where: { $0.productId == productId }) else { return }
        let newLiked = !item.isLiked
        let newCount = item.likeCount + (newLiked ? 1 : -1)
        let optimistic = item.with(likeCount: max(0, newCount), isLiked: newLiked)
        userItems = userItems.replacingItem(productId: productId, with: optimistic)
        Task {
            do {
                let result = try await productService.toggleLike(productId: productId, isLiked: newLiked)
                await MainActor.run {
                    let count = result.likeCount ?? optimistic.likeCount
                    userItems = userItems.replacingItem(productId: productId, with: item.with(likeCount: count, isLiked: result.isLiked))
                }
            } catch {
                await MainActor.run { errorMessage = L10n.userFacingError(error) }
            }
        }
    }
    
    func toggleMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isMenuVisible.toggle()
        }
    }
    
    func hideMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isMenuVisible = false
        }
    }
    
    /// Uploads profile photo to backend (GraphQL UploadFile + updateProfile) and refreshes user. No local storage — avatar is always from backend.
    /// Pass current authToken so the upload uses the latest token (e.g. after refresh).
    func uploadProfileImage(_ image: UIImage, authToken: String?) {
        let resized = Self.resizeForProfileUpload(image, maxLongSide: 1200)
        guard let jpegData = resized.jpegData(compressionQuality: 0.85) else {
            profilePhotoUploadError = "Could not prepare image"
            return
        }
        profilePhotoUploadError = nil
        isUploadingProfilePhoto = true
        fileUploadService.setAuthToken(authToken)
        Task {
            do {
                let (url, thumbnail) = try await fileUploadService.uploadProfileImage(jpegData)
                try await userService.updateProfilePicture(profilePictureUrl: url, thumbnailUrl: thumbnail)
                await loadUserData()
            } catch {
                await MainActor.run {
                    profilePhotoUploadError = L10n.userFacingError(error)
                }
            }
            await MainActor.run {
                isUploadingProfilePhoto = false
            }
        }
    }

    /// Resize image so longest side is at most maxLongSide; avoids oversized uploads and backend rejections.
    private static func resizeForProfileUpload(_ image: UIImage, maxLongSide: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxLongSide || size.height > maxLongSide else { return image }
        let scale = min(maxLongSide / size.width, maxLongSide / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Sold tab vs My Orders

    /// Order rows that still represent a real sale for overlaying `userProducts` (exclude cancelled/refunded).
    private static func isActiveSaleOrder(_ order: Order) -> Bool {
        let st = order.status.uppercased()
        if st == "CANCELLED" || st == "REFUNDED" { return false }
        return true
    }

    /// Product ids from seller orders so profile "Sold" matches My Orders when `userProducts` omits SOLD or returns a stale status.
    private static func productIdsFromActiveSellerOrders(_ orders: [Order]) -> Set<String> {
        var ids = Set<String>()
        for order in orders where isActiveSaleOrder(order) {
            for p in order.products {
                let pid = p.id.trimmingCharacters(in: .whitespacesAndNewlines)
                if !pid.isEmpty { ids.insert(pid) }
            }
        }
        return ids
    }

    private static func itemFromSellerOrderLine(_ line: OrderProductSummary, seller: User, orderDate: Date) -> Item {
        let pid = line.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawPrice = line.price?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let price = Double(rawPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        let urls: [String]
        let listURL: String?
        if line.isMysteryBox {
            urls = []
            listURL = nil
        } else {
            let img = line.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            urls = img.isEmpty ? [] : [img]
            listURL = ProductListImageURL.preferredString(from: img.isEmpty ? nil : img) ?? (img.isEmpty ? nil : img)
        }
        let materialSummary: String = {
            let m = line.materials.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return m.joined(separator: ", ")
        }()
        let styleTags: [String] = {
            guard let s = line.style?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return [] }
            return [s]
        }()
        return Item(
            id: Item.id(fromProductId: pid),
            productId: pid,
            listingCode: nil,
            title: line.name,
            description: "",
            price: price,
            originalPrice: nil,
            imageURLs: urls,
            listDisplayImageURL: listURL,
            category: .clothing,
            categoryName: nil,
            seller: seller,
            condition: line.condition ?? "",
            size: line.size,
            brand: line.brand,
            colors: line.colors,
            likeCount: 0,
            views: 0,
            createdAt: orderDate,
            isLiked: false,
            status: "SOLD",
            sellCategoryBackendId: nil,
            sellSizeBackendId: nil,
            listingMeasurements: nil,
            materialSummary: materialSummary.isEmpty ? nil : materialSummary,
            styleTags: styleTags,
            isMysteryBox: line.isMysteryBox
        )
    }

    /// Patch `status` to SOLD when the listing appears on seller orders, and append rows missing from `userProducts`.
    private static func mergeSellerProductsWithSoldOrders(_ products: [Item], seller: User, soldOrders: [Order]) -> [Item] {
        let soldIds = productIdsFromActiveSellerOrders(soldOrders)
        let merged: [Item] = products.map { item in
            guard let pid = item.productId, soldIds.contains(pid) else { return item }
            if item.status.uppercased() == "SOLD" { return item }
            return item.with(status: "SOLD")
        }
        let mergedIds = Set(merged.compactMap { $0.productId })
        var seenExtra = Set<String>()
        var extras: [Item] = []
        for order in soldOrders where isActiveSaleOrder(order) {
            for line in order.products {
                let pid = line.id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !pid.isEmpty, !mergedIds.contains(pid), seenExtra.insert(pid).inserted else { continue }
                extras.append(itemFromSellerOrderLine(line, seller: seller, orderDate: order.createdAt))
            }
        }
        return merged + extras
    }
}
