//
//  StyleEnumValuesLoader.swift
//  Prelura-swift
//
//  Fetches GraphQL `StyleEnum` case names via introspection when the server allows it,
//  caches them for fast subsequent launches, and falls back to the bundled catalog.
//

import Foundation

/// Loads lookbook / sell style pill labels from the live GraphQL schema, with cache + offline fallback.
enum StyleEnumValuesLoader {
    private static let defaultsKey = "styleEnumGraphQLRawValuesCache_v1"

    /// Values to show immediately: last successful API/cache, else bundled ``StyleEnumCatalog/rawValues``.
    static func cachedRaws() -> [String] {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data),
           !decoded.isEmpty
        {
            return decoded
        }
        return StyleEnumCatalog.rawValues
    }

    static func saveCache(_ raws: [String]) {
        let trimmed = raws.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private struct IntrospectionData: Decodable {
        struct GType: Decodable {
            struct EnumVal: Decodable { let name: String }
            let enumValues: [EnumVal]?
        }

        /// GraphQL introspection root field.
        let `__type`: GType?
    }

    private static let introspectionQuery = """
    query StyleEnumIntrospection {
      __type(name: "StyleEnum") {
        enumValues { name }
      }
    }
    """

    /// Fetches enum member names from the API. Returns empty if introspection is disabled or the type is missing.
    static func fetchFromBackend(client: GraphQLClient) async throws -> [String] {
        let data: IntrospectionData = try await client.execute(
            query: introspectionQuery,
            operationName: "StyleEnumIntrospection",
            responseType: IntrospectionData.self
        )
        let names = data.__type?.enumValues?.map(\.name) ?? []
        return names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Refreshes UserDefaults cache; ignores failures (offline / introspection blocked).
    static func refreshCacheFromBackend(client: GraphQLClient) async {
        do {
            let raws = try await fetchFromBackend(client: client)
            guard !raws.isEmpty else { return }
            saveCache(raws)
        } catch {
            // Keep existing cache or bundled fallback.
        }
    }
}
