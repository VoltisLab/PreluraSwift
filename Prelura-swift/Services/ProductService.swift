import Foundation
import Combine

@MainActor
class ProductService: ObservableObject {
    private var client: GraphQLClient
    
    init(client: GraphQLClient? = nil) {
        if let client = client {
            self.client = client
        } else {
            self.client = GraphQLClient()
            // Try to load auth token from UserDefaults
            if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
                self.client.setAuthToken(token)
            }
        }
    }
    
    func updateAuthToken(_ token: String?) {
        client.setAuthToken(token)
    }
    
    func getAllProducts(pageNumber: Int = 1, pageCount: Int = 20, search: String? = nil, parentCategory: String? = nil, discountPrice: Bool? = nil, maxPrice: Double? = nil) async throws -> [Item] {
        let query = """
        query AllProducts($pageNumber: Int, $pageCount: Int, $search: String, $filters: ProductFiltersInput) {
          allProducts(pageNumber: $pageNumber, pageCount: $pageCount, search: $search, filters: $filters) {
            id
            name
            description
            price
            discountPrice
            imagesUrl
            condition
            createdAt
            size {
              id
              name
            }
            brand {
              id
              name
            }
            customBrand
            likes
            views
            userLiked
            seller {
              id
              username
              displayName
              profilePictureUrl
              isVacationMode
            }
            category {
              id
              name
            }
            color
          }
          allProductsTotalNumber
        }
        """
        
        var variables: [String: Any] = [
            "pageNumber": pageNumber,
            "pageCount": pageCount
        ]
        
        if let search = search, !search.isEmpty {
            variables["search"] = search
        }
        
        // Build filters object
        var filters: [String: Any] = [:]
        if let parentCategory = parentCategory, parentCategory != "All" {
            // Map category names to GraphQL enum values
            if let categoryEnum = mapCategoryToEnum(parentCategory) {
                filters["parentCategory"] = categoryEnum
            }
        }
        
        // Add discountPrice filter if specified (like Flutter app)
        if let discountPrice = discountPrice {
            filters["discountPrice"] = discountPrice
        }
        
        // Add maxPrice filter if specified (for shop bargains)
        if let maxPrice = maxPrice {
            filters["maxPrice"] = maxPrice
        }
        
        if !filters.isEmpty {
            variables["filters"] = filters
        }
        
        let response: AllProductsResponse = try await client.execute(
            query: query,
            variables: variables,
            responseType: AllProductsResponse.self
        )
        
        guard let products = response.allProducts else {
            return []
        }
        
        return products.compactMap { product in
            // Convert id to string
            let idString: String
            if let anyCodable = product.id {
                if let intValue = anyCodable.value as? Int {
                    idString = String(intValue)
                } else if let stringValue = anyCodable.value as? String {
                    idString = stringValue
                } else {
                    idString = String(describing: anyCodable.value)
                }
            } else {
                return nil
            }
            
            // Extract image URLs from imagesUrl array (which contains JSON strings)
            let imageURLs = extractImageURLs(from: product.imagesUrl)
            
            // Extract seller id
            let sellerIdString: String
            if let sellerId = product.seller?.id {
                if let intValue = sellerId.value as? Int {
                    sellerIdString = String(intValue)
                } else if let stringValue = sellerId.value as? String {
                    sellerIdString = stringValue
                } else {
                    sellerIdString = String(describing: sellerId.value)
                }
            } else {
                sellerIdString = ""
            }
            
            // Parse discountPrice (it's a percentage string, e.g., "20" for 20% off)
            let originalPrice = product.price ?? 0.0
            let discountPercentage: Double? = {
                guard let discountPriceStr = product.discountPrice,
                      let discount = Double(discountPriceStr),
                      discount > 0 else {
                    return nil
                }
                return discount
            }()
            
            // Calculate final price: if discount exists, apply it; otherwise use original price
            let finalPrice: Double
            let itemOriginalPrice: Double?
            if let discount = discountPercentage {
                // Calculate discounted price: originalPrice - (originalPrice * discount / 100)
                finalPrice = originalPrice - (originalPrice * discount / 100)
                itemOriginalPrice = originalPrice
            } else {
                finalPrice = originalPrice
                itemOriginalPrice = nil
            }
            
            return Item(
                id: UUID(uuidString: idString) ?? UUID(),
                productId: idString,
                title: product.name ?? "",
                description: product.description ?? "",
                price: finalPrice,
                originalPrice: itemOriginalPrice,
                imageURLs: imageURLs,
                category: Category.fromName(product.category?.name ?? ""),
                categoryName: product.category?.name, // Store actual category name from API (subcategory)
                seller: User(
                    id: UUID(uuidString: sellerIdString) ?? UUID(),
                    username: product.seller?.username ?? "",
                    displayName: product.seller?.displayName ?? "",
                    avatarURL: product.seller?.profilePictureUrl,
                    isVacationMode: product.seller?.isVacationMode ?? false
                ),
                condition: product.condition ?? "",
                size: product.size?.name,
                brand: product.brand?.name ?? product.customBrand,
                likeCount: product.likes ?? 0,
                views: product.views ?? 0,
                createdAt: Self.parseCreatedAt(product.createdAt) ?? Date(),
                isLiked: product.userLiked ?? false
            )
        }
    }
    
    private static func parseCreatedAt(_ iso8601: String?) -> Date? {
        guard let s = iso8601 else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: s) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)
    }
    
    private func extractImageURLs(from imagesUrl: [String]?) -> [String] {
        guard let imagesUrl = imagesUrl else { return [] }
        var urls: [String] = []
        for imageJson in imagesUrl {
            // imagesUrl contains JSON strings like '{"url":"...","thumbnail":"..."}'
            // Try to parse as JSON string
            if let data = imageJson.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let url = json["url"] as? String, !url.isEmpty {
                        urls.append(url)
                    }
                } catch {
                    // If JSON parsing fails, try using the string directly as URL (fallback)
                    // This handles cases where imagesUrl might already contain direct URLs
                    if !imageJson.isEmpty && (imageJson.hasPrefix("http://") || imageJson.hasPrefix("https://")) {
                        urls.append(imageJson)
                    }
                }
            } else {
                // If data conversion fails, try using the string directly as URL (fallback)
                if !imageJson.isEmpty && (imageJson.hasPrefix("http://") || imageJson.hasPrefix("https://")) {
                    urls.append(imageJson)
                }
            }
        }
        return urls
    }
    
    func searchProducts(query: String, pageNumber: Int = 1, pageCount: Int = 20) async throws -> [Item] {
        // Use the search parameter in getAllProducts
        return try await getAllProducts(pageNumber: pageNumber, pageCount: pageCount, search: query)
    }

    /// Fetch unique brand names from the catalog (for sell flow brand picker). Uses existing allProducts and extracts brand/customBrand.
    func getBrandNames() async throws -> [String] {
        var all: [String] = []
        var seen = Set<String>()
        for page in 1...3 {
            let products = try await getAllProducts(pageNumber: page, pageCount: 50)
            for item in products {
                let name = item.brand ?? ""
                if !name.isEmpty, !seen.contains(name) {
                    seen.insert(name)
                    all.append(name)
                }
            }
            if products.count < 50 { break }
        }
        return all.sorted()
    }

    /// Favourites: fetch liked products. Matches Flutter getMyFavouriteProduct (query likedProducts).
    func getLikedProducts(pageNumber: Int = 1, pageCount: Int = 50) async throws -> (items: [Item], totalNumber: Int) {
        let query = """
        query LikedProducts($pageCount: Int, $pageNumber: Int) {
          likedProducts(pageCount: $pageCount, pageNumber: $pageNumber) {
            product {
              id
              name
              description
              price
              discountPrice
              imagesUrl
              condition
              createdAt
              size { id name }
              brand { id name }
              customBrand
              likes
              views
              userLiked
            seller { id username displayName profilePictureUrl isVacationMode }
            category { id name }
            color
            }
          }
          likedProductsTotalNumber
        }
        """
        struct LikedProductsResponse: Decodable {
            let likedProducts: [LikedProductRow]?
            let likedProductsTotalNumber: Int?
        }
        struct LikedProductRow: Decodable {
            let product: ProductData?
        }
        let response: LikedProductsResponse = try await client.execute(
            query: query,
            variables: ["pageCount": pageCount, "pageNumber": pageNumber],
            responseType: LikedProductsResponse.self
        )
        let products = (response.likedProducts ?? []).compactMap { $0.product }
        let items = products.compactMap { mapProductToItem(product: $0) }
        let total = response.likedProductsTotalNumber ?? 0
        return (items, total)
    }

    /// Toggle like on a product. Matches Flutter likeProduct mutation.
    func likeProduct(productId: Int) async throws -> Bool {
        let mutation = """
        mutation LikeProduct($productId: Int!) {
          likeProduct(productId: $productId) {
            success
          }
        }
        """
        struct Payload: Decodable { let likeProduct: LikeProductPayload? }
        struct LikeProductPayload: Decodable { let success: Bool? }
        let response: Payload = try await client.execute(query: mutation, variables: ["productId": productId], responseType: Payload.self)
        return response.likeProduct?.success ?? false
    }

    // Map category filter names to GraphQL enum values
    private func mapCategoryToEnum(_ category: String) -> String? {
        switch category {
        case "Women":
            return "WOMEN"
        case "Men":
            return "MEN"
        case "Kids":
            return "KIDS"
        case "Toddlers":
            return "TODDLERS"
        case "Boys":
            return "BOYS"
        case "Girls":
            return "GIRLS"
        default:
            return nil
        }
    }
}

struct AllProductsResponse: Decodable {
    let allProducts: [ProductData]?
    let allProductsTotalNumber: Int?
}

struct ProductData: Decodable {
    let id: AnyCodable?
    let name: String?
    let description: String?
    let price: Double?
    let discountPrice: String?
    let imagesUrl: [String]?
    let condition: String?
    let createdAt: String?  // ISO8601 from GraphQL
    let size: SizeData?
    let brand: BrandData?
    let customBrand: String?
    let color: [String]?
    let likes: Int?
    let views: Int?
    let userLiked: Bool?
    let seller: SellerData?
    let category: CategoryData?
}

struct SizeData: Decodable {
    let id: AnyCodable?
    let name: String?
}

struct BrandData: Decodable {
    let id: AnyCodable?
    let name: String?
}

struct SellerData: Decodable {
    let id: AnyCodable?
    let username: String?
    let displayName: String?
    let profilePictureUrl: String?
    let isVacationMode: Bool?
}

struct CategoryData: Decodable {
    let id: AnyCodable?
    let name: String?
}

extension ProductService {
    /// Fetch a single product by ID (for deep links / notification navigation). Matches GraphQL query product(id: Int!).
    func getProduct(id: Int) async throws -> Item? {
        let query = """
        query ProductDetail($id: Int!) {
          product(id: $id) {
            id
            name
            description
            price
            discountPrice
            imagesUrl
            condition
            createdAt
            size { id name }
            brand { id name }
            customBrand
            likes
            views
            userLiked
            seller { id username displayName profilePictureUrl isVacationMode }
            category { id name }
            color
          }
        }
        """
        struct ProductDetailResponse: Decodable {
            let product: ProductData?
        }
        let response: ProductDetailResponse = try await client.execute(
            query: query,
            variables: ["id": id],
            responseType: ProductDetailResponse.self
        )
        guard let product = response.product else { return nil }
        return mapProductToItem(product: product)
    }

    func getRecentlyViewedProducts() async throws -> [Item] {
        let query = """
        query RecentlyViewedProducts {
          recentlyViewedProducts {
            id
            name
            description
            price
            discountPrice
            imagesUrl
            condition
            createdAt
            size {
              id
              name
            }
            brand {
              id
              name
            }
            customBrand
            likes
            views
            userLiked
            seller {
              id
              username
              displayName
              profilePictureUrl
              isVacationMode
            }
            category {
              id
              name
            }
            color
          }
        }
        """
        
        struct RecentlyViewedProductsResponse: Decodable {
            let recentlyViewedProducts: [ProductData]?
        }
        
        let response: RecentlyViewedProductsResponse = try await client.execute(
            query: query,
            variables: nil,
            responseType: RecentlyViewedProductsResponse.self
        )
        
        guard let products = response.recentlyViewedProducts else {
            return []
        }
        
        return products.compactMap { product in
            // Extract product id
            let idString: String
            if let productId = product.id {
                if let intValue = productId.value as? Int {
                    idString = String(intValue)
                } else if let stringValue = productId.value as? String {
                    idString = stringValue
                } else {
                    idString = String(describing: productId.value)
                }
            } else {
                idString = UUID().uuidString
            }
            
            // Extract seller id
            let sellerIdString: String
            if let sellerId = product.seller?.id {
                if let intValue = sellerId.value as? Int {
                    sellerIdString = String(intValue)
                } else if let stringValue = sellerId.value as? String {
                    sellerIdString = stringValue
                } else {
                    sellerIdString = String(describing: sellerId.value)
                }
            } else {
                sellerIdString = ""
            }
            
            // Parse discountPrice (it's a percentage string, e.g., "20" for 20% off)
            let originalPrice = product.price ?? 0.0
            let discountPercentage: Double? = {
                guard let discountPriceStr = product.discountPrice,
                      let discount = Double(discountPriceStr),
                      discount > 0 else {
                    return nil
                }
                return discount
            }()
            
            // Calculate final price: if discount exists, apply it; otherwise use original price
            let finalPrice: Double
            let itemOriginalPrice: Double?
            if let discount = discountPercentage {
                // Calculate discounted price: originalPrice - (originalPrice * discount / 100)
                finalPrice = originalPrice - (originalPrice * discount / 100)
                itemOriginalPrice = originalPrice
            } else {
                finalPrice = originalPrice
                itemOriginalPrice = nil
            }
            
            // Extract image URLs from imagesUrl array (which contains JSON strings)
            let imageURLs = extractImageURLs(from: product.imagesUrl)
            
            // Get brand name (use customBrand as fallback)
            let brandName = product.brand?.name ?? product.customBrand
            
            // Get size
            let sizeName = product.size?.name ?? "One Size"
            
            return Item(
                id: UUID(uuidString: idString) ?? UUID(),
                title: product.name ?? "",
                description: product.description ?? "",
                price: finalPrice,
                originalPrice: itemOriginalPrice,
                imageURLs: imageURLs,
                category: Category.fromName(product.category?.name ?? ""),
                categoryName: product.category?.name, // Store actual category name from API (subcategory)
                seller: User(
                    id: UUID(uuidString: sellerIdString) ?? UUID(),
                    username: product.seller?.username ?? "",
                    displayName: product.seller?.displayName ?? "",
                    avatarURL: product.seller?.profilePictureUrl,
                    isVacationMode: product.seller?.isVacationMode ?? false
                ),
                condition: product.condition ?? "UNKNOWN",
                size: sizeName,
                brand: brandName,
                likeCount: product.likes ?? 0,
                views: product.views ?? 0,
                createdAt: Self.parseCreatedAt(product.createdAt) ?? Date(),
                isLiked: product.userLiked ?? false
            )
        }
    }
    
    func getSimilarProducts(productId: String, categoryId: Int? = nil, pageNumber: Int = 1, pageCount: Int = 20) async throws -> [Item] {
        let query = """
        query SimilarProducts($productId: Int, $categoryId: Int, $pageNumber: Int, $pageCount: Int) {
          similarProducts(productId: $productId, categoryId: $categoryId, pageNumber: $pageNumber, pageCount: $pageCount) {
            id
            name
            description
            price
            discountPrice
            imagesUrl
            condition
            createdAt
            size {
              id
              name
            }
            brand {
              id
              name
            }
            customBrand
            likes
            views
            userLiked
            seller {
              id
              username
              displayName
              profilePictureUrl
              isVacationMode
            }
            category {
              id
              name
            }
            color
          }
        }
        """
        
        var variables: [String: Any] = [
            "pageNumber": pageNumber,
            "pageCount": pageCount
        ]
        
        if let productIdInt = Int(productId) {
            variables["productId"] = productIdInt
        }
        
        if let categoryId = categoryId {
            variables["categoryId"] = categoryId
        }
        
        struct SimilarProductsResponse: Decodable {
            let similarProducts: [ProductData]?
        }
        
        let response: SimilarProductsResponse = try await client.execute(
            query: query,
            variables: variables,
            responseType: SimilarProductsResponse.self
        )
        
        guard let products = response.similarProducts else {
            return []
        }
        
        return products.compactMap { product in
            return mapProductToItem(product: product)
        }
    }
    
    func toggleLike(productId: String, isLiked: Bool) async throws -> (isLiked: Bool, likeCount: Int) {
        let mutation = """
        mutation ToggleLike($productId: Int!, $isLiked: Boolean!) {
          toggleLikeProduct(productId: $productId, isLiked: $isLiked) {
            isLiked
            likeCount
          }
        }
        """
        
        guard let productIdInt = Int(productId) else {
            throw NSError(domain: "ProductService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid product ID"])
        }
        
        var variables: [String: Any] = [
            "productId": productIdInt,
            "isLiked": isLiked
        ]
        
        struct ToggleLikeResponse: Decodable {
            let toggleLikeProduct: ToggleLikeData?
        }
        
        struct ToggleLikeData: Decodable {
            let isLiked: Bool?
            let likeCount: Int?
        }
        
        let response: ToggleLikeResponse = try await client.execute(
            query: mutation,
            variables: variables,
            responseType: ToggleLikeResponse.self
        )
        
        guard let data = response.toggleLikeProduct else {
            throw NSError(domain: "ProductService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to toggle like"])
        }
        
        return (
            isLiked: data.isLiked ?? isLiked,
            likeCount: data.likeCount ?? 0
        )
    }
    
    private func mapProductToItem(product: ProductData) -> Item? {
        // Extract product id
        let idString: String
        if let productId = product.id {
            if let intValue = productId.value as? Int {
                idString = String(intValue)
            } else if let stringValue = productId.value as? String {
                idString = stringValue
            } else {
                idString = String(describing: productId.value)
            }
        } else {
            idString = UUID().uuidString
        }
        
        // Extract seller id
        let sellerIdString: String
        if let sellerId = product.seller?.id {
            if let intValue = sellerId.value as? Int {
                sellerIdString = String(intValue)
            } else if let stringValue = sellerId.value as? String {
                sellerIdString = stringValue
            } else {
                sellerIdString = String(describing: sellerId.value)
            }
        } else {
            sellerIdString = ""
        }
        
        // Parse discountPrice (it's a percentage string, e.g., "20" for 20% off)
        let originalPrice = product.price ?? 0.0
        let discountPercentage: Double? = {
            guard let discountPriceStr = product.discountPrice,
                  let discount = Double(discountPriceStr),
                  discount > 0 else {
                return nil
            }
            return discount
        }()
        
        // Calculate final price: if discount exists, apply it; otherwise use original price
        let finalPrice: Double
        let itemOriginalPrice: Double?
        if let discount = discountPercentage {
            // Calculate discounted price: originalPrice - (originalPrice * discount / 100)
            finalPrice = originalPrice - (originalPrice * discount / 100)
            itemOriginalPrice = originalPrice
        } else {
            finalPrice = originalPrice
            itemOriginalPrice = nil
        }
        
            // Extract image URLs from imagesUrl array (which contains JSON strings)
            let imageURLs = extractImageURLs(from: product.imagesUrl)
            
            // Get brand name (use customBrand as fallback)
            let brandName = product.brand?.name ?? product.customBrand
        
        // Get size
        let sizeName = product.size?.name ?? "One Size"
        
        return Item(
            id: UUID(uuidString: idString) ?? UUID(),
            productId: idString,
            title: product.name ?? "",
            description: product.description ?? "",
            price: finalPrice,
            originalPrice: itemOriginalPrice,
            imageURLs: imageURLs,
            category: Category.fromName(product.category?.name ?? ""),
            categoryName: product.category?.name,
            seller: User(
                id: UUID(uuidString: sellerIdString) ?? UUID(),
                username: product.seller?.username ?? "",
                displayName: product.seller?.displayName ?? "",
                avatarURL: product.seller?.profilePictureUrl,
                isVacationMode: product.seller?.isVacationMode ?? false
            ),
            condition: product.condition ?? "UNKNOWN",
            size: sizeName,
            brand: brandName,
            colors: product.color ?? [],
            likeCount: product.likes ?? 0,
            views: product.views ?? 0,
            createdAt: Self.parseCreatedAt(product.createdAt) ?? Date(),
            isLiked: product.userLiked ?? false
        )
    }
}
