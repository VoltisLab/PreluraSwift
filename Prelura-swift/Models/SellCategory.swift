import Foundation

/// Category selected in the sell flow (backend id + name + full path for tracing back).
struct SellCategory: Equatable {
    let id: String
    let name: String
    /// Full path from root to this category (e.g. ["Men", "Accessories", "Gloves"]) so user can trace back.
    let pathNames: [String]
    /// Full path of IDs for each level.
    let pathIds: [String]

    init(id: String, name: String, pathNames: [String]? = nil, pathIds: [String]? = nil) {
        self.id = id
        self.name = name
        self.pathNames = pathNames ?? [name]
        self.pathIds = pathIds ?? [id]
    }

    /// Display string for the sell form (e.g. "Men > Accessories > Gloves").
    var displayPath: String {
        pathNames.joined(separator: " > ")
    }
}

/// A category with its full path (for search results).
struct CategoryPathEntry: Equatable {
    let id: String
    let name: String
    let pathNames: [String]
    let pathIds: [String]
    var displayPath: String { pathNames.joined(separator: " > ") }
}

/// Category node from GraphQL categories(parentId) query (matches Flutter Categoriess / CategoryTypes).
struct APICategory: Decodable {
    let id: String
    let name: String
    let hasChildren: Bool?
    let fullPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, fullPath, hasChildren
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = ""
        }
        name = try c.decode(String.self, forKey: .name)
        hasChildren = try c.decodeIfPresent(Bool.self, forKey: .hasChildren)
        fullPath = try c.decodeIfPresent(String.self, forKey: .fullPath)
    }
}

/// Material from GraphQL materials() query (backend returns BrandType: id, name).
struct APIMaterial: Decodable {
    let id: Int
    let name: String
}
