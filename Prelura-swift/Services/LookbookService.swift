//
//  LookbookService.swift
//  Prelura-swift
//
//  Lookbooks on the server. Uses createLookbook mutation and lookbooks query.
//  When the backend does not yet expose these (see docs/lookbooks-backend-spec.md), calls fail — no local fallback.
//

import Foundation

/// Normalizes lookbook post ids for GraphQL `UUID!` variables (e.g. strips `urn:uuid:` or `{}` wrappers).
enum LookbookPostIdFormatting {
    static func graphQLUUIDString(from raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = s.lowercased()
        if lower.hasPrefix("urn:uuid:") {
            s = String(s.dropFirst("urn:uuid:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if s.count >= 2, s.first == "{", s.last == "}" {
            s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Some APIs return 32 hex chars without dashes; GraphQL UUID! and Swift UUID() need dashed form.
        let hexOnly = s.filter { $0.isHexDigit }
        if hexOnly.count == 32, hexOnly.count == s.replacingOccurrences(of: "-", with: "").count {
            let h = String(hexOnly).lowercased()
            let dashed = "\(h.prefix(8))-\(h.dropFirst(8).prefix(4))-\(h.dropFirst(12).prefix(4))-\(h.dropFirst(16).prefix(4))-\(h.dropFirst(20))"
            if UUID(uuidString: dashed) != nil { return dashed }
        }
        return s
    }
}

/// Server lookbook post (matches backend spec).
struct ServerLookbookPost: Decodable {
    let id: String
    let imageUrl: String
    /// Smaller companion file from LOOKBOOK upload (`*_thumbnail.jpeg`); optional for older API responses.
    let thumbnailUrl: String?
    let caption: String?
    let username: String
    /// Poster profile image from `getUser`-style field on the post (optional until backend supports it).
    let profilePictureUrl: String?
    let createdAt: String?
    var likesCount: Int?
    var commentsCount: Int?
    var userLiked: Bool?
    var productLinkClicks: Int?
    var shopLinkClicks: Int?
}

struct ServerLookbookComment: Decodable, Identifiable {
    let id: String
    let username: String
    let text: String
    let createdAt: String?
    let profilePictureUrl: String?
    let parentCommentId: String?
    let likesCount: Int?
    let userLiked: Bool?

    func withLikeUpdate(likesCount: Int, userLiked: Bool) -> ServerLookbookComment {
        ServerLookbookComment(
            id: id,
            username: username,
            text: text,
            createdAt: createdAt,
            profilePictureUrl: profilePictureUrl,
            parentCommentId: parentCommentId,
            likesCount: likesCount,
            userLiked: userLiked
        )
    }
}

struct CreateLookbookResponse: Decodable {
    let createLookbook: CreateLookbookPayload?
}

struct CreateLookbookPayload: Decodable {
    let lookbookPost: ServerLookbookPost?
    let success: Bool?
    let message: String?
}

struct LookbooksQueryResponse: Decodable {
    let lookbooks: LookbooksConnection?
}

struct LookbooksConnection: Decodable {
    let edges: [LookbookEdge]?
    let nodes: [ServerLookbookPost]?
}

struct LookbookEdge: Decodable {
    let node: ServerLookbookPost?
}

/// Service for server-side lookbooks. Requires backend to implement the API described in docs/lookbooks-backend-spec.md.
final class LookbookService {
    private let client: GraphQLClient
    private let uploadURL: URL
    private let session: URLSession
    private var authToken: String?

    init(client: GraphQLClient, baseURL: String = Constants.graphQLBaseURL, uploadURL: String = Constants.graphQLUploadURL) {
        self.client = client
        self.uploadURL = URL(string: uploadURL)!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.apiTimeout
        config.timeoutIntervalForResource = Constants.apiTimeout
        self.session = URLSession(configuration: config)
    }

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    /// Upload a single image with fileType LOOKBOOK. Returns the image URL. Fails when backend has no LOOKBOOK type yet.
    func uploadLookbookImage(_ imageData: Data) async throws -> String {
        let boundary = "----WearhouseBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()

        let operations: [String: Any] = [
            "query": "mutation UploadFile($files: [Upload]!, $fileType: FileTypeEnum!) { upload(files: $files, filetype: $fileType) { baseUrl data } }",
            "variables": [
                "files": [NSNull()],
                "fileType": "LOOKBOOK"
            ] as [String: Any]
        ]
        let operationsData = try JSONSerialization.data(withJSONObject: operations)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"operations\"\r\n\r\n".data(using: .utf8)!)
        body.append(operationsData)
        body.append("\r\n".data(using: .utf8)!)

        let map: [String: [String]] = ["0": ["variables.files.0"]]
        let mapData = try JSONSerialization.data(withJSONObject: map)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"map\"\r\n\r\n".data(using: .utf8)!)
        body.append(mapData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"0\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        let statusCode = http?.statusCode ?? -1

        func graphQLErrorMessage(from data: Data) -> String? {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let errors = json["errors"] as? [[String: Any]],
                  let first = errors.first,
                  let message = first["message"] as? String else { return nil }
            return message
        }

        guard (200...299).contains(statusCode) else {
            let msg = graphQLErrorMessage(from: data) ?? "Upload failed (HTTP \(statusCode))"
            throw NSError(domain: "LookbookService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        struct UploadResponse: Decodable {
            let data: UploadData?
        }
        struct UploadData: Decodable {
            let upload: UploadResult?
        }
        struct UploadResult: Decodable {
            let baseUrl: String?
            let data: [String]?
        }

        let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
        guard let upload = decoded.data?.upload,
              let baseUrl = upload.baseUrl, !baseUrl.isEmpty,
              let dataStrings = upload.data, !dataStrings.isEmpty,
              let first = dataStrings.first,
              let jsonData = first.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let imagePath = obj["image"] as? String else {
            let msg = graphQLErrorMessage(from: data) ?? "Invalid upload response"
            throw NSError(domain: "LookbookService", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return baseUrl.hasSuffix("/") ? baseUrl + imagePath : baseUrl + "/" + imagePath
    }

    /// Create a lookbook post on the server. Fails when mutation is not yet deployed.
    func createLookbook(imageUrl: String, caption: String?) async throws -> ServerLookbookPost {
        let query = """
        mutation CreateLookbook($imageUrl: String!, $caption: String) {
          createLookbook(imageUrl: $imageUrl, caption: $caption) {
            lookbookPost { id imageUrl thumbnailUrl caption username profilePictureUrl createdAt likesCount commentsCount userLiked }
            success
            message
          }
        }
        """
        let variables: [String: Any] = [
            "imageUrl": imageUrl,
            "caption": caption as Any
        ]
        struct Response: Decodable {
            let createLookbook: Payload?
        }
        struct Payload: Decodable {
            let lookbookPost: ServerLookbookPost?
            let success: Bool?
            let message: String?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "CreateLookbook",
            responseType: Response.self
        )
        guard let payload = response.createLookbook,
              let post = payload.lookbookPost else {
            throw NSError(domain: "LookbookService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Create lookbook failed"])
        }
        return post
    }

    /// Fetch lookbooks from the server. Returns empty array when query is not yet deployed or fails.
    func fetchLookbooks(first: Int = 50) async throws -> [ServerLookbookPost] {
        let query = """
        query Lookbooks($first: Int) {
          lookbooks(first: $first) {
            nodes { id imageUrl thumbnailUrl caption username profilePictureUrl createdAt likesCount commentsCount userLiked productLinkClicks shopLinkClicks }
            edges { node { id imageUrl thumbnailUrl caption username profilePictureUrl createdAt likesCount commentsCount userLiked productLinkClicks shopLinkClicks } }
          }
        }
        """
        let variables: [String: Any] = ["first": first]
        struct Response: Decodable {
            let lookbooks: Conn?
        }
        struct Conn: Decodable {
            let nodes: [ServerLookbookPost]?
            let edges: [LookbookEdge]?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "Lookbooks",
            responseType: Response.self
        )
        if let nodes = response.lookbooks?.nodes, !nodes.isEmpty {
            return nodes
        }
        if let edges = response.lookbooks?.edges {
            return edges.compactMap { $0.node }
        }
        return []
    }

    /// Fetches a single lookbook post (e.g. universal link / deep link).
    func fetchLookbookPost(postId: String) async throws -> ServerLookbookPost? {
        let query = """
        query LookbookPost($postId: UUID!) {
          lookbookPost(postId: $postId) {
            id
            imageUrl
            thumbnailUrl
            caption
            username
            profilePictureUrl
            createdAt
            likesCount
            commentsCount
            userLiked
            productLinkClicks
            shopLinkClicks
          }
        }
        """
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: postId)
        let variables: [String: Any] = ["postId": normalized]
        struct Response: Decodable { let lookbookPost: ServerLookbookPost? }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "LookbookPost",
            responseType: Response.self
        )
        return response.lookbookPost
    }

    func toggleLike(postId: String) async throws -> (liked: Bool, likesCount: Int) {
        let query = """
        mutation ToggleLookbookLike($postId: UUID!) {
          toggleLookbookLike(postId: $postId) {
            success
            liked
            likesCount
            message
          }
        }
        """
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: postId)
        let variables: [String: Any] = ["postId": normalized]
        struct Response: Decodable { let toggleLookbookLike: Payload? }
        struct Payload: Decodable {
            let success: Bool?
            let liked: Bool?
            let likesCount: Int?
            let message: String?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "ToggleLookbookLike",
            responseType: Response.self
        )
        guard let payload = response.toggleLookbookLike, payload.success == true else {
            throw NSError(domain: "LookbookService", code: -1, userInfo: [NSLocalizedDescriptionKey: response.toggleLookbookLike?.message ?? "Like failed"])
        }
        return (payload.liked ?? false, payload.likesCount ?? 0)
    }

    func fetchComments(postId: String) async throws -> [ServerLookbookComment] {
        let query = """
        query LookbookComments($postId: UUID!) {
          lookbookComments(postId: $postId) {
            id
            username
            text
            createdAt
            profilePictureUrl
            parentCommentId
            likesCount
            userLiked
          }
        }
        """
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: postId)
        let variables: [String: Any] = ["postId": normalized]
        struct Response: Decodable { let lookbookComments: [ServerLookbookComment]? }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "LookbookComments",
            responseType: Response.self
        )
        return response.lookbookComments ?? []
    }

    func addComment(postId: String, text: String, parentCommentId: String? = nil) async throws -> (comment: ServerLookbookComment, commentsCount: Int) {
        let query = """
        mutation AddLookbookComment($postId: UUID!, $text: String!, $parentCommentId: UUID) {
          addLookbookComment(postId: $postId, text: $text, parentCommentId: $parentCommentId) {
            success
            message
            commentsCount
            comment {
              id
              username
              text
              createdAt
              profilePictureUrl
              parentCommentId
              likesCount
              userLiked
            }
          }
        }
        """
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: postId)
        var variables: [String: Any] = ["postId": normalized, "text": text]
        if let rawParent = parentCommentId?.trimmingCharacters(in: .whitespacesAndNewlines), !rawParent.isEmpty {
            variables["parentCommentId"] = LookbookPostIdFormatting.graphQLUUIDString(from: rawParent)
        } else {
            variables["parentCommentId"] = NSNull()
        }
        struct Response: Decodable { let addLookbookComment: Payload? }
        struct Payload: Decodable {
            let success: Bool?
            let message: String?
            let commentsCount: Int?
            let comment: ServerLookbookComment?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "AddLookbookComment",
            responseType: Response.self
        )
        guard let payload = response.addLookbookComment, payload.success == true, let comment = payload.comment else {
            throw NSError(domain: "LookbookService", code: -1, userInfo: [NSLocalizedDescriptionKey: response.addLookbookComment?.message ?? "Add comment failed"])
        }
        return (comment, payload.commentsCount ?? 0)
    }

    func toggleCommentLike(commentId: String) async throws -> (liked: Bool, likesCount: Int) {
        let query = """
        mutation ToggleLookbookCommentLike($commentId: UUID!) {
          toggleLookbookCommentLike(commentId: $commentId) {
            success
            message
            liked
            likesCount
          }
        }
        """
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: commentId)
        let variables: [String: Any] = ["commentId": normalized]
        struct Response: Decodable { let toggleLookbookCommentLike: Payload? }
        struct Payload: Decodable {
            let success: Bool?
            let message: String?
            let liked: Bool?
            let likesCount: Int?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "ToggleLookbookCommentLike",
            responseType: Response.self
        )
        guard let payload = response.toggleLookbookCommentLike, payload.success == true else {
            throw NSError(
                domain: "LookbookService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.toggleLookbookCommentLike?.message ?? "Like failed"]
            )
        }
        return (payload.liked ?? false, payload.likesCount ?? 0)
    }

    func deleteComment(commentId: String) async throws -> Int {
        let query = """
        mutation DeleteLookbookComment($commentId: UUID!) {
          deleteLookbookComment(commentId: $commentId) {
            success
            message
            commentsCount
          }
        }
        """
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: commentId)
        let variables: [String: Any] = ["commentId": normalized]
        struct Response: Decodable { let deleteLookbookComment: Payload? }
        struct Payload: Decodable {
            let success: Bool?
            let message: String?
            let commentsCount: Int?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "DeleteLookbookComment",
            responseType: Response.self
        )
        guard let payload = response.deleteLookbookComment, payload.success == true else {
            throw NSError(
                domain: "LookbookService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.deleteLookbookComment?.message ?? "Delete failed"]
            )
        }
        return payload.commentsCount ?? 0
    }

    func deleteLookbookPost(postId: String) async throws {
        let query = """
        mutation DeleteLookbookPost($postId: UUID!) {
          deleteLookbookPost(postId: $postId) {
            success
            message
          }
        }
        """
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: postId)
        let variables: [String: Any] = ["postId": normalized]
        struct Response: Decodable { let deleteLookbookPost: Payload? }
        struct Payload: Decodable { let success: Bool?; let message: String? }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "DeleteLookbookPost",
            responseType: Response.self
        )
        guard response.deleteLookbookPost?.success == true else {
            throw NSError(
                domain: "LookbookService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.deleteLookbookPost?.message ?? "Delete failed"]
            )
        }
    }

    /// `clickType`: `"product"` (tagged item) or `"shop"` (view shop).
    func recordLookbookLinkClick(postId: String, clickType: String) async throws {
        let query = """
        mutation RecordLookbookLinkClick($postId: UUID!, $clickType: String!) {
          recordLookbookLinkClick(postId: $postId, clickType: $clickType) {
            success
            message
            productLinkClicks
            shopLinkClicks
          }
        }
        """
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: postId)
        let variables: [String: Any] = ["postId": normalized, "clickType": clickType]
        struct Response: Decodable { let recordLookbookLinkClick: Payload? }
        struct Payload: Decodable {
            let success: Bool?
            let message: String?
            let productLinkClicks: Int?
            let shopLinkClicks: Int?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "RecordLookbookLinkClick",
            responseType: Response.self
        )
        guard response.recordLookbookLinkClick?.success == true else {
            throw NSError(
                domain: "LookbookService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.recordLookbookLinkClick?.message ?? "Click record failed"]
            )
        }
    }
}
