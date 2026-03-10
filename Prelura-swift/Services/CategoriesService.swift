import Foundation

/// Fetches hierarchical categories from the same GraphQL API as Flutter (categories(parentId)).
final class CategoriesService {
    private let client: GraphQLClient

    init(client: GraphQLClient = GraphQLClient()) {
        self.client = client
    }

    private static let categoriesQuery = """
    query Categories($parentId: Int) {
      categories(parentId: $parentId) {
        id
        name
        hasChildren
        fullPath
      }
    }
    """

    struct CategoriesResponse: Decodable {
        let categories: [APICategory]?
    }

    /// Fetch categories for a parent. Pass nil for root (Men, Women, Boys, Girls, Toddlers, etc.).
    func fetchCategories(parentId: Int?) async throws -> [APICategory] {
        var variables: [String: Any] = [:]
        if let id = parentId {
            variables["parentId"] = id
        }
        let body = try await client.execute(
            query: Self.categoriesQuery,
            variables: variables.isEmpty ? nil : variables,
            operationName: "Categories",
            responseType: CategoriesResponse.self
        )
        return body.categories ?? []
    }
}
