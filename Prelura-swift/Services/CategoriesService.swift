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

    /// Recursively fetch all categories and return leaf categories with full path (for search).
    func fetchAllCategoriesFlattened() async throws -> [CategoryPathEntry] {
        var result: [CategoryPathEntry] = []
        let root = try await fetchCategories(parentId: nil)
        for cat in root {
            try await collectLeaves(category: cat, pathNames: [cat.name], pathIds: [cat.id], into: &result)
        }
        return result
    }

    private func collectLeaves(category: APICategory, pathNames: [String], pathIds: [String], into result: inout [CategoryPathEntry]) async throws {
        if category.hasChildren != true {
            result.append(CategoryPathEntry(id: category.id, name: category.name, pathNames: pathNames, pathIds: pathIds))
            return
        }
        let children = try await fetchCategories(parentId: Int(category.id))
        for child in children {
            try await collectLeaves(category: child, pathNames: pathNames + [child.name], pathIds: pathIds + [child.id], into: &result)
        }
    }
}
