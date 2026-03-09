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
    
    func toggleLike(productId: String) {
        guard let productIdInt = Int(productId) else { return }
        let newIsLiked = !isLiked
        Task {
            do {
                _ = try await productService.likeProduct(productId: productIdInt)
                await MainActor.run {
                    self.isLiked = newIsLiked
                    self.likeCount = newIsLiked ? self.likeCount + 1 : max(0, self.likeCount - 1)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
