import Foundation
import SwiftUI
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var userItems: [Item] = []
    @Published var isMenuVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    var topBrands: [String] {
        // Extract unique brands from userItems, sorted by frequency
        let brandCounts = Dictionary(grouping: userItems.compactMap { $0.brand }, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
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
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Load user profile and products in parallel for faster display
            async let userTask = userService.getUser()
            async let productsTask = userService.getUserProducts()
            let (fetchedUser, products) = try await (userTask, productsTask)
            await MainActor.run {
                self.user = fetchedUser
                self.userItems = products
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
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
        await loadUserData()
    }

    /// Toggle like for a product and update userItems.
    func toggleLike(productId: String) {
        guard !productId.isEmpty, let item = userItems.first(where: { $0.productId == productId }) else { return }
        Task {
            do {
                let (isLiked, likeCount) = try await productService.toggleLike(productId: productId, isLiked: !item.isLiked)
                await MainActor.run {
                    userItems = userItems.replacingItem(productId: productId, with: item.with(likeCount: likeCount, isLiked: isLiked))
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
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
    
    private static let localProfileImageFilename = "ProfilePhoto.jpg"
    
    /// Saves profile image to app Documents so it persists across launches. Call after user picks a new photo.
    func saveProfileImageLocally(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Self.localProfileImageFilename)
        try? data.write(to: url)
        UserDefaults.standard.set(url.path, forKey: "LOCAL_PROFILE_IMAGE_PATH")
    }
    
    /// Loads the locally saved profile image if any (used so profile photo persists).
    func loadLocalProfileImage() -> UIImage? {
        guard let path = UserDefaults.standard.string(forKey: "LOCAL_PROFILE_IMAGE_PATH"),
              FileManager.default.fileExists(atPath: path),
              let image = UIImage(contentsOfFile: path) else { return nil }
        return image
    }
    
    /// Uploads profile photo to backend (GraphQL UploadFile + updateProfile), then saves locally and refreshes user. Matches Flutter updateProfilePicture flow.
    func uploadProfileImage(_ image: UIImage) {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            profilePhotoUploadError = "Could not prepare image"
            return
        }
        saveProfileImageLocally(image)
        profilePhotoUploadError = nil
        isUploadingProfilePhoto = true
        Task {
            do {
                let (url, thumbnail) = try await fileUploadService.uploadProfileImage(jpegData)
                try await userService.updateProfilePicture(profilePictureUrl: url, thumbnailUrl: thumbnail)
                await loadUserData()
            } catch {
                await MainActor.run {
                    profilePhotoUploadError = error.localizedDescription
                }
            }
            await MainActor.run {
                isUploadingProfilePhoto = false
            }
        }
    }
}
