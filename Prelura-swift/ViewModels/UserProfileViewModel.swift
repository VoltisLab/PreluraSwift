import Foundation
import Combine

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var items: [Item] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let userService: UserService

    var topBrands: [String] {
        let brandCounts = Dictionary(grouping: items.compactMap { $0.brand }, by: { $0 })
            .mapValues { $0.count }
            .sorted { a, b in
                if a.value != b.value { return a.value > b.value }
                return a.key.localizedCompare(b.key) == .orderedAscending
            }
        return Array(brandCounts.prefix(10).map { $0.key })
    }

    var categoriesWithCounts: [(name: String, count: Int)] {
        let categoryCounts = Dictionary(grouping: items, by: { $0.categoryName ?? $0.category.name })
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
        return categoryCounts
    }

    init(seller: User, authService: AuthService?) {
        self.user = seller
        let client = GraphQLClient()
        if let token = authService?.authToken {
            client.setAuthToken(token)
        } else if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            client.setAuthToken(token)
        }
        self.userService = UserService(client: client)
    }

    func load() {
        Task {
            await loadProducts()
        }
    }

    private func loadProducts() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let products = try await userService.getUserProducts(username: user.username)
            await MainActor.run {
                self.items = products
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func refresh() {
        Task { await loadProducts() }
    }

    func refreshAsync() async {
        await loadProducts()
    }
}
