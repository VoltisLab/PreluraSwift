import Foundation
import SwiftUI
import Combine

@MainActor
class ItemDetailViewModel: ObservableObject {
    @Published var similarItems: [Item] = []
    @Published var memberItems: [Item] = []
    @Published var isLoadingSimilar: Bool = false
    @Published var isLoadingMember: Bool = false
    @Published var isLiked: Bool = false
    @Published var likeCount: Int = 0
    @Published var errorMessage: String?
    /// Current user's profile picture URL; used when viewing own product and seller avatar is missing.
    @Published var currentUserAvatarURL: String?
    
    var productService: ProductService
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
    
    func loadSimilarProducts(productId: String, categoryId: Int? = nil) {
        isLoadingSimilar = true
        errorMessage = nil
        
        Task {
            do {
                let products = try await productService.getSimilarProducts(
                    productId: productId,
                    categoryId: categoryId
                )
                await MainActor.run {
                    self.similarItems = products
                    self.isLoadingSimilar = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSimilar = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func loadMemberItems(username: String, excludeProductId: UUID) {
        isLoadingMember = true
        errorMessage = nil
        
        Task {
            do {
                let products = try await userService.getUserProducts(username: username)
                await MainActor.run {
                    // Exclude the current product
                    self.memberItems = products.filter { $0.id != excludeProductId }
                    self.isLoadingMember = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingMember = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Sync like state from the item (call from view onAppear).
    func syncLikeState(isLiked: Bool, likeCount: Int) {
        self.isLiked = isLiked
        self.likeCount = likeCount
    }
    
    /// Load current user's profile picture URL (for own product detail when seller avatar is missing).
    func loadCurrentUserAvatar() async {
        do {
            let user = try await userService.getUser()
            currentUserAvatarURL = user.avatarURL
        } catch {
            currentUserAvatarURL = nil
        }
    }

    /// Record this product as recently viewed (fire-and-forget). Call when product detail is shown.
    func recordRecentlyViewed(productId: String?) {
        guard let productId = productId, let productIdInt = Int(productId) else { return }
        Task {
            await productService.addToRecentlyViewed(productId: productIdInt)
            await MainActor.run {
                NotificationCenter.default.post(name: .preluraRecentlyViewedDidUpdate, object: nil)
            }
        }
    }
    
    func toggleLike(productId: String) {
        Task {
            do {
                let (newIsLiked, newCount) = try await productService.toggleLike(productId: productId, isLiked: !isLiked)
                await MainActor.run {
                    self.isLiked = newIsLiked
                    self.likeCount = newCount
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
