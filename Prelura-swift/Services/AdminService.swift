import Foundation
import Combine

/// Admin-only API: resolve users by search (userAdminStats), flag/delete user (flagUser). Requires staff auth token.
@MainActor
class AdminService: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private var client: GraphQLClient

    init(client: GraphQLClient) {
        self.client = client
        if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            self.client.setAuthToken(token)
        }
    }

    func updateAuthToken(_ token: String?) {
        client.setAuthToken(token)
    }

    /// Fetch users for admin (search by username etc). Returns id and username for delete flow.
    func fetchUserAdminStats(search: String?, pageCount: Int = 20, pageNumber: Int = 1) async throws -> [AdminUserEntry] {
        let query = """
        query UserAdminStats($search: String, $pageCount: Int, $pageNumber: Int) {
          userAdminStats(search: $search, pageCount: $pageCount, pageNumber: $pageNumber) {
            id
            username
          }
        }
        """
        var variables: [String: Any] = ["pageCount": pageCount, "pageNumber": pageNumber]
        if let s = search, !s.isEmpty {
            variables["search"] = s
        }
        struct Payload: Decodable {
            let userAdminStats: [AdminUserEntry]?
        }
        let response: Payload = try await client.execute(
            query: query,
            variables: variables,
            responseType: Payload.self
        )
        return response.userAdminStats ?? []
    }

    /// Flag/delete user (soft-delete). Admin only. id is the user's ID (string or int).
    func flagUser(id: String, reason: String, notes: String?) async throws -> (success: Bool, message: String?) {
        let mutation = """
        mutation FlagUser($id: ID!, $reason: FlagUserReasonEnum!, $notes: String) {
          flagUser(id: $id, reason: $reason, notes: $notes) {
            success
            message
          }
        }
        """
        var variables: [String: Any] = ["id": id, "reason": reason]
        if let n = notes, !n.isEmpty {
            variables["notes"] = n
        }
        struct Payload: Decodable {
            let flagUser: FlagUserResult?
        }
        struct FlagUserResult: Decodable {
            let success: Bool?
            let message: String?
        }
        let response: Payload = try await client.execute(
            query: mutation,
            variables: variables,
            responseType: Payload.self
        )
        let result = response.flagUser
        return (result?.success ?? false, result?.message)
    }
}

struct AdminUserEntry: Decodable {
    let id: AnyCodable?
    let username: String?

    var idString: String? {
        guard let id = id else { return nil }
        if let intVal = id.value as? Int { return String(intVal) }
        if let strVal = id.value as? String { return strVal }
        return String(describing: id.value)
    }
}
