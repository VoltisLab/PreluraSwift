//
//  LookbookService.swift
//  Prelura-swift
//
//  Lookbooks on the server. Uses createLookbook mutation and lookbooks query.
//  When the backend does not yet expose these (see docs/lookbooks-backend-spec.md), calls fail — no local fallback.
//

import Foundation
import Network

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

/// Product pin from API (`LookbookProductTag` / `productTags`).
struct ServerLookbookProductTag: Decodable {
    let productId: String
    let x: Double
    let y: Double
    let imageIndex: Int?
    let clientId: String?
}

/// Snapshot row from API (`productSnapshots` list).
struct ServerLookbookProductSnapshot: Decodable {
    let productId: String
    let title: String
    let imageUrl: String?
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
    /// Distinct tagged products from API (`taggedProductCount` / `productTags`). When the schema lacks extended fields, each request retries without them (no process-wide latch).
    var taggedProductCount: Int?
    /// Pin coordinates when backend persists tags (all viewers).
    var productTags: [ServerLookbookProductTag]?
    var productSnapshots: [ServerLookbookProductSnapshot]?
    /// Present when the API persists lookbook styles on the post (optional for older schemas).
    let styles: [String]?
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
    /// Relay cursor when the schema exposes it (fallback when `pageInfo.endCursor` is null).
    let cursor: String?
    let node: ServerLookbookPost?
}

private func graphQLRejectsExtendedLookbookPostFields(_ error: Error) -> Bool {
    guard case GraphQLError.graphQLErrors(let errs) = error else { return false }
    return errs.contains { e in
        let m = e.message.lowercased()
        guard m.contains("cannot query field") || m.contains("unknown field") || m.contains("unknown argument") else { return false }
        return m.contains("taggedproductcount")
            || m.contains("producttags")
            || m.contains("productsnapshots")
            || m.contains("lookbooktaginput")
            || m.contains("lookbookproductsnapshotinput")
            || (m.contains("styles") && (m.contains("cannot query field") || m.contains("unknown field")))
    }
}

private func graphQLRejectsCreateLookbookStyles(_ error: Error) -> Bool {
    guard case GraphQLError.graphQLErrors(let errs) = error else { return false }
    return errs.contains { e in
        let m = e.message.lowercased()
        return m.contains("unknown argument") && m.contains("styles")
    }
}

private func graphQLRejectsSetLookbookProductTags(_ error: Error) -> Bool {
    guard case GraphQLError.graphQLErrors(let errs) = error else { return false }
    return errs.contains { e in
        let m = e.message.lowercased()
        guard m.contains("unknown") || m.contains("cannot query field") else { return false }
        return m.contains("setlookbookproducttags")
    }
}

/// True when the API schema has no `updateLookbookPost` mutation (backend not deployed / wrong environment).
private func graphQLRejectsUpdateLookbookPost(_ error: Error) -> Bool {
    guard case GraphQLError.graphQLErrors(let errs) = error else { return false }
    return errs.contains { e in
        let m = e.message.lowercased()
        guard m.contains("cannot query field") || m.contains("unknown field") else { return false }
        return m.contains("updatelookbookpost")
    }
}

private func lookbookUpdateMutationNotDeployedError() -> NSError {
    NSError(
        domain: "LookbookService",
        code: -2,
        userInfo: [
            NSLocalizedDescriptionKey: "Lookbook edits aren’t supported on this server yet. Deploy the updateLookbookPost API (see docs/lookbooks-backend-spec.md).",
        ]
    )
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

    /// GraphQL selection for `LookbookPost` / `ServerLookbookPost` (extended = count + pins from server).
    private func lookbookPostGraphQLFields(includeExtended: Bool) -> String {
        if includeExtended {
            return "id imageUrl thumbnailUrl caption username profilePictureUrl createdAt likesCount commentsCount userLiked productLinkClicks shopLinkClicks taggedProductCount productTags { productId x y imageIndex clientId } productSnapshots { productId title imageUrl } styles"
        }
        return "id imageUrl thumbnailUrl caption username profilePictureUrl createdAt likesCount commentsCount userLiked productLinkClicks shopLinkClicks"
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

    /// Create a lookbook post on the server. Sends `tags` / `productSnapshots` / `styles` when the schema supports them.
    func createLookbook(
        imageUrl: String,
        caption: String?,
        tags: [LookbookTagData]? = nil,
        productSnapshots: [String: LookbookProductSnapshot]? = nil,
        styles: [String]? = nil
    ) async throws -> ServerLookbookPost {
        let styleRaws = StyleEnumCatalog.normalizedUnique(styles ?? [], maxCount: 3)
        do {
            return try await createLookbook(
                imageUrl: imageUrl,
                caption: caption,
                tags: tags,
                productSnapshots: productSnapshots,
                styleRaws: styleRaws,
                includeExtended: true
            )
        } catch {
            if graphQLRejectsExtendedLookbookPostFields(error) {
                return try await createLookbook(
                    imageUrl: imageUrl,
                    caption: caption,
                    tags: tags,
                    productSnapshots: productSnapshots,
                    styleRaws: styleRaws,
                    includeExtended: false
                )
            }
            throw error
        }
    }

    private enum CreateLookbookMutationVariant {
        case tagsAndStyles
        case tagsOnly
        case stylesOnly
        case basic
    }

    private func createLookbookMutationVariants(hasTagPayload: Bool, hasStyles: Bool) -> [CreateLookbookMutationVariant] {
        if hasTagPayload && hasStyles { return [.tagsAndStyles, .tagsOnly] }
        if hasTagPayload { return [.tagsOnly] }
        if hasStyles { return [.stylesOnly, .basic] }
        return [.basic]
    }

    private func createLookbook(
        imageUrl: String,
        caption: String?,
        tags: [LookbookTagData]?,
        productSnapshots: [String: LookbookProductSnapshot]?,
        styleRaws: [String],
        includeExtended: Bool
    ) async throws -> ServerLookbookPost {
        let fields = lookbookPostGraphQLFields(includeExtended: includeExtended)
        let hasTagPayload = includeExtended
            && (!(tags ?? []).isEmpty || !((productSnapshots ?? [:]).isEmpty))
        let hasStyles = !styleRaws.isEmpty
        let order = createLookbookMutationVariants(hasTagPayload: hasTagPayload, hasStyles: hasStyles)
        var lastStyleRejection: Error?
        for variant in order {
            do {
                return try await executeCreateLookbookMutation(
                    variant: variant,
                    fields: fields,
                    imageUrl: imageUrl,
                    caption: caption,
                    tags: tags,
                    productSnapshots: productSnapshots,
                    styleRaws: styleRaws
                )
            } catch {
                if graphQLRejectsCreateLookbookStyles(error) {
                    lastStyleRejection = error
                    continue
                }
                throw error
            }
        }
        if let e = lastStyleRejection {
            throw e
        }
        throw NSError(domain: "LookbookService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Create lookbook failed"])
    }

    private func executeCreateLookbookMutation(
        variant: CreateLookbookMutationVariant,
        fields: String,
        imageUrl: String,
        caption: String?,
        tags: [LookbookTagData]?,
        productSnapshots: [String: LookbookProductSnapshot]?,
        styleRaws: [String]
    ) async throws -> ServerLookbookPost {
        let query: String
        switch variant {
        case .tagsAndStyles:
            query = """
            mutation CreateLookbook($imageUrl: String!, $caption: String, $styles: [StyleEnum!], $tags: [LookbookTagInput!], $productSnapshots: [LookbookProductSnapshotInput!]) {
              createLookbook(imageUrl: $imageUrl, caption: $caption, styles: $styles, tags: $tags, productSnapshots: $productSnapshots) {
                lookbookPost { \(fields) }
                success
                message
              }
            }
            """
        case .tagsOnly:
            query = """
            mutation CreateLookbook($imageUrl: String!, $caption: String, $tags: [LookbookTagInput!], $productSnapshots: [LookbookProductSnapshotInput!]) {
              createLookbook(imageUrl: $imageUrl, caption: $caption, tags: $tags, productSnapshots: $productSnapshots) {
                lookbookPost { \(fields) }
                success
                message
              }
            }
            """
        case .stylesOnly:
            query = """
            mutation CreateLookbook($imageUrl: String!, $caption: String, $styles: [StyleEnum!]) {
              createLookbook(imageUrl: $imageUrl, caption: $caption, styles: $styles) {
                lookbookPost { \(fields) }
                success
                message
              }
            }
            """
        case .basic:
            query = """
            mutation CreateLookbook($imageUrl: String!, $caption: String) {
              createLookbook(imageUrl: $imageUrl, caption: $caption) {
                lookbookPost { \(fields) }
                success
                message
              }
            }
            """
        }

        var variables: [String: Any] = ["imageUrl": imageUrl]
        if let c = caption, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            variables["caption"] = c
        }
        switch variant {
        case .tagsAndStyles:
            variables["styles"] = styleRaws
            fallthrough
        case .tagsOnly:
            let tagRows = (tags ?? []).map { t -> [String: Any] in
                [
                    "productId": t.productId,
                    "x": t.x,
                    "y": t.y,
                    "imageIndex": t.imageIndex,
                    "clientId": t.clientId,
                ]
            }
            let snapRows = (productSnapshots ?? [:]).values.map { s -> [String: Any] in
                var row: [String: Any] = ["productId": s.productId, "title": s.title]
                if let u = s.imageUrl { row["imageUrl"] = u }
                return row
            }
            variables["tags"] = tagRows
            variables["productSnapshots"] = snapRows
        case .stylesOnly:
            variables["styles"] = styleRaws
        case .basic:
            break
        }

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

    /// Updates caption on an existing post (author-only on server). Requires backend `updateLookbookPost` mutation.
    func updateLookbookPost(postId: String, caption: String?) async throws -> ServerLookbookPost {
        do {
            return try await updateLookbookPost(postId: postId, caption: caption, includeTaggedProductCount: true)
        } catch {
            if graphQLRejectsUpdateLookbookPost(error) {
                throw lookbookUpdateMutationNotDeployedError()
            }
            if graphQLRejectsExtendedLookbookPostFields(error) {
                do {
                    return try await updateLookbookPost(postId: postId, caption: caption, includeTaggedProductCount: false)
                } catch {
                    if graphQLRejectsUpdateLookbookPost(error) {
                        throw lookbookUpdateMutationNotDeployedError()
                    }
                    throw error
                }
            }
            throw error
        }
    }

    private func updateLookbookPost(postId: String, caption: String?, includeTaggedProductCount: Bool) async throws -> ServerLookbookPost {
        let lf = lookbookPostGraphQLFields(includeExtended: includeTaggedProductCount)
        let query = """
        mutation UpdateLookbookPost($postId: UUID!, $caption: String) {
          updateLookbookPost(postId: $postId, caption: $caption) {
            lookbookPost { \(lf) }
            success
            message
          }
        }
        """
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: postId)
        var variables: [String: Any] = ["postId": normalized]
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            variables["caption"] = NSNull()
        } else {
            variables["caption"] = trimmed
        }
        struct Response: Decodable {
            let updateLookbookPost: Payload?
        }
        struct Payload: Decodable {
            let lookbookPost: ServerLookbookPost?
            let success: Bool?
            let message: String?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "UpdateLookbookPost",
            responseType: Response.self
        )
        guard let payload = response.updateLookbookPost,
              payload.success == true,
              let post = payload.lookbookPost else {
            let msg = response.updateLookbookPost?.message ?? "Update lookbook failed"
            throw NSError(domain: "LookbookService", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return post
    }

    /// Replaces product pins on an existing post (author-only). Falls back silently when the backend has not deployed `setLookbookProductTags`.
    func setLookbookProductTags(postId: String, tags: [LookbookTagData], productSnapshots: [String: LookbookProductSnapshot]?) async throws -> ServerLookbookPost {
        do {
            return try await setLookbookProductTags(postId: postId, tags: tags, productSnapshots: productSnapshots, includeExtended: true)
        } catch {
            if graphQLRejectsExtendedLookbookPostFields(error) {
                return try await setLookbookProductTags(postId: postId, tags: tags, productSnapshots: productSnapshots, includeExtended: false)
            }
            throw error
        }
    }

    private func setLookbookProductTags(
        postId: String,
        tags: [LookbookTagData],
        productSnapshots: [String: LookbookProductSnapshot]?,
        includeExtended: Bool
    ) async throws -> ServerLookbookPost {
        let lf = lookbookPostGraphQLFields(includeExtended: includeExtended)
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: postId)
        let tagRows = tags.map { t -> [String: Any] in
            [
                "productId": t.productId,
                "x": t.x,
                "y": t.y,
                "imageIndex": t.imageIndex,
                "clientId": t.clientId,
            ]
        }
        let snapRows: [[String: Any]] = (productSnapshots.map { Array($0.values) } ?? []).map { s -> [String: Any] in
            var row: [String: Any] = ["productId": s.productId, "title": s.title]
            if let u = s.imageUrl { row["imageUrl"] = u }
            return row
        }
        var variables: [String: Any] = ["postId": normalized, "tags": tagRows]
        if snapRows.isEmpty {
            variables["productSnapshots"] = NSNull()
        } else {
            variables["productSnapshots"] = snapRows
        }
        let query = """
        mutation SetLookbookProductTags($postId: UUID!, $tags: [LookbookTagInput!]!, $productSnapshots: [LookbookProductSnapshotInput!]) {
          setLookbookProductTags(postId: $postId, tags: $tags, productSnapshots: $productSnapshots) {
            lookbookPost { \(lf) }
            success
            message
          }
        }
        """
        struct Response: Decodable {
            let setLookbookProductTags: Payload?
        }
        struct Payload: Decodable {
            let lookbookPost: ServerLookbookPost?
            let success: Bool?
            let message: String?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "SetLookbookProductTags",
            responseType: Response.self
        )
        guard let payload = response.setLookbookProductTags,
              payload.success == true,
              let post = payload.lookbookPost else {
            let msg = response.setLookbookProductTags?.message ?? "Update product tags failed"
            throw NSError(domain: "LookbookService", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return post
    }

    /// Caption first, then product tags when supported. Returns the latest `lookbookPost` when tag mutation succeeds; otherwise the caption-only update result.
    func saveLookbookPostEdits(postId: String, caption: String?, tags: [LookbookTagData], productSnapshots: [String: LookbookProductSnapshot]?) async throws -> ServerLookbookPost {
        let captionPost = try await updateLookbookPost(postId: postId, caption: caption)
        do {
            return try await setLookbookProductTags(postId: postId, tags: tags, productSnapshots: productSnapshots)
        } catch {
            if graphQLRejectsSetLookbookProductTags(error) {
                return captionPost
            }
            throw error
        }
    }

    /// Fetch lookbooks from the server. Returns empty array when query is not yet deployed or fails.
    func fetchLookbooks(first: Int = 50) async throws -> [ServerLookbookPost] {
        do {
            return try await fetchLookbooks(first: first, includeTaggedProductCount: true)
        } catch {
            if graphQLRejectsExtendedLookbookPostFields(error) {
                return try await fetchLookbooks(first: first, includeTaggedProductCount: false)
            }
            throw error
        }
    }

    /// One page of the main Lookbook feed (cursor + `after`). Use for infinite scroll; falls back to empty next cursor when the server omits cursors.
    struct LookbooksFeedPageResult: Sendable {
        let posts: [ServerLookbookPost]
        let endCursor: String?
        let hasNextPage: Bool
    }

    /// Loads the main Lookbook feed. Uses cursor pagination when the schema has `pageInfo` / `after`; otherwise one `lookbooks(first:)` call sized like the first paginated page (not `maxPosts`, which is too slow on large feeds).
    func fetchLookbooksFeed(maxPosts: Int = 500, pageSize: Int = 100) async throws -> [ServerLookbookPost] {
        let cap = min(maxPosts, 500)
        let firstBatch = await Self.recommendedLookbookFirstBatchSize()
        let legacyFirstBatch = min(firstBatch, cap)
        do {
            return try await fetchLookbooksFeedPaginated(
                maxPosts: maxPosts,
                pageSize: pageSize,
                firstPageBatchLimit: firstBatch,
                includeTaggedProductCount: true
            )
        } catch {
            if graphQLRejectsExtendedLookbookPostFields(error) {
                do {
                    return try await fetchLookbooksFeedPaginated(
                        maxPosts: maxPosts,
                        pageSize: pageSize,
                        firstPageBatchLimit: firstBatch,
                        includeTaggedProductCount: false
                    )
                } catch {
                    // Paginated query still uses `pageInfo` / `after`; legacy servers reject those even without extended post fields.
                    if graphQLRejectsLookbooksPagination(error) {
                        return try await fetchLookbooks(first: legacyFirstBatch)
                    }
                    throw error
                }
            }
            if graphQLRejectsLookbooksPagination(error) {
                return try await fetchLookbooks(first: legacyFirstBatch)
            }
            throw error
        }
    }

    /// Fetches a single page for infinite scroll (same connection shape as the paginated feed query).
    func fetchLookbooksFeedPage(first: Int, after: String?) async throws -> LookbooksFeedPageResult {
        do {
            return try await fetchLookbooksFeedPage(first: max(1, min(first, 100)), after: after, includeTaggedProductCount: true)
        } catch {
            if graphQLRejectsExtendedLookbookPostFields(error) {
                return try await fetchLookbooksFeedPage(first: max(1, min(first, 100)), after: after, includeTaggedProductCount: false)
            }
            throw error
        }
    }

    private func fetchLookbooksFeedPage(first: Int, after: String?, includeTaggedProductCount: Bool) async throws -> LookbooksFeedPageResult {
        let lf = lookbookPostGraphQLFields(includeExtended: includeTaggedProductCount)
        let query = """
        query LookbooksFeed($first: Int, $after: String) {
          lookbooks(first: $first, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes { \(lf) }
            edges { cursor node { \(lf) } }
          }
        }
        """
        var variables: [String: Any] = ["first": first]
        if let c = after, !c.isEmpty {
            variables["after"] = c
        } else {
            variables["after"] = NSNull()
        }
        struct Response: Decodable {
            let lookbooks: Conn?
        }
        struct PageInfo: Decodable {
            let hasNextPage: Bool?
            let endCursor: String?
        }
        struct Conn: Decodable {
            let pageInfo: PageInfo?
            let nodes: [ServerLookbookPost]?
            let edges: [LookbookEdge]?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "LookbooksFeed",
            responseType: Response.self
        )
        var batch: [ServerLookbookPost] = []
        if let nodes = response.lookbooks?.nodes, !nodes.isEmpty {
            batch = nodes
        } else if let edges = response.lookbooks?.edges {
            batch = edges.compactMap { $0.node }
        }
        let hasNext = response.lookbooks?.pageInfo?.hasNextPage == true
        let end = response.lookbooks?.pageInfo?.endCursor?.trimmingCharacters(in: .whitespacesAndNewlines)
        var endCursor: String? = (end?.isEmpty == false) ? end : nil
        if endCursor == nil, let edges = response.lookbooks?.edges {
            for edge in edges.reversed() {
                if let c = edge.cursor?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
                    endCursor = c
                    break
                }
            }
        }
        // Some APIs omit `pageInfo.endCursor` / edge cursors while still setting `hasNextPage`. Without *some*
        // `after` value the client cannot fetch the next page — use the last post id as a last-resort cursor.
        if endCursor == nil, hasNext, let last = batch.last {
            let id = last.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if !id.isEmpty {
                endCursor = LookbookPostIdFormatting.graphQLUUIDString(from: id)
            }
        }
        return LookbooksFeedPageResult(posts: batch, endCursor: endCursor, hasNextPage: hasNext)
    }

    /// First Lookbook request: **20** items on typical Wi‑Fi / Ethernet; **10** when the path looks slower (cellular-only, Low Data Mode, expensive routing, or unsatisfied).
    private static func recommendedLookbookFirstBatchSize() async -> Int {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.prelura.lookbook.firstBatch")
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                let n: Int
                if path.status != .satisfied {
                    n = 10
                } else if path.isConstrained || path.isExpensive {
                    n = 10
                } else {
                    let hasWifiOrWired = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
                    if path.usesInterfaceType(.cellular), !hasWifiOrWired {
                        n = 10
                    } else {
                        n = 20
                    }
                }
                continuation.resume(returning: n)
            }
            monitor.start(queue: queue)
        }
    }

    private func graphQLRejectsLookbooksPagination(_ error: Error) -> Bool {
        guard case GraphQLError.graphQLErrors(let errs) = error else { return false }
        return errs.contains { e in
            let m = e.message.lowercased()
            return (m.contains("unknown argument") && m.contains("after"))
                || (m.contains("cannot query field") && m.contains("pageinfo"))
        }
    }

    private func fetchLookbooksFeedPaginated(
        maxPosts: Int,
        pageSize: Int,
        firstPageBatchLimit: Int,
        includeTaggedProductCount: Bool
    ) async throws -> [ServerLookbookPost] {
        let lf = lookbookPostGraphQLFields(includeExtended: includeTaggedProductCount)
        let query = """
        query LookbooksFeed($first: Int, $after: String) {
          lookbooks(first: $first, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes { \(lf) }
            edges { cursor node { \(lf) } }
          }
        }
        """
        var merged: [ServerLookbookPost] = []
        var seenIds = Set<String>()
        var cursor: String? = nil
        var iterations = 0
        var isFirstPage = true
        repeat {
            let pageLimit: Int
            if isFirstPage {
                pageLimit = min(firstPageBatchLimit, max(1, maxPosts - merged.count))
                isFirstPage = false
            } else {
                pageLimit = min(pageSize, max(1, maxPosts - merged.count))
            }
            var variables: [String: Any] = ["first": pageLimit]
            if let c = cursor {
                variables["after"] = c
            } else {
                variables["after"] = NSNull()
            }
            struct Response: Decodable {
                let lookbooks: Conn?
            }
            struct PageInfo: Decodable {
                let hasNextPage: Bool?
                let endCursor: String?
            }
            struct Conn: Decodable {
                let pageInfo: PageInfo?
                let nodes: [ServerLookbookPost]?
                let edges: [LookbookEdge]?
            }
            let response: Response = try await client.execute(
                query: query,
                variables: variables,
                operationName: "LookbooksFeed",
                responseType: Response.self
            )
            var batch: [ServerLookbookPost] = []
            if let nodes = response.lookbooks?.nodes, !nodes.isEmpty {
                batch = nodes
            } else if let edges = response.lookbooks?.edges {
                batch = edges.compactMap { $0.node }
            }
            for p in batch {
                if seenIds.insert(p.id).inserted {
                    merged.append(p)
                }
            }
            if batch.isEmpty {
                break
            }
            let hasNext = response.lookbooks?.pageInfo?.hasNextPage == true
            let end = response.lookbooks?.pageInfo?.endCursor?.trimmingCharacters(in: .whitespacesAndNewlines)
            var nextCursor: String? = (end?.isEmpty == false) ? end : nil
            if nextCursor == nil, let edges = response.lookbooks?.edges {
                for edge in edges.reversed() {
                    if let c = edge.cursor?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
                        nextCursor = c
                        break
                    }
                }
            }
            cursor = nextCursor
            iterations += 1
            if merged.count >= maxPosts { break }
            if !hasNext { break }
            if cursor == nil { break }
            if iterations > 64 { break }
        } while merged.count < maxPosts
        if merged.isEmpty {
            let fallbackFirst = min(firstPageBatchLimit, min(maxPosts, 500))
            return try await fetchLookbooks(first: fallbackFirst, includeTaggedProductCount: includeTaggedProductCount)
        }
        return Array(merged.prefix(maxPosts))
    }

    private func fetchLookbooks(first: Int, includeTaggedProductCount: Bool) async throws -> [ServerLookbookPost] {
        let lf = lookbookPostGraphQLFields(includeExtended: includeTaggedProductCount)
        let query = """
        query Lookbooks($first: Int) {
          lookbooks(first: $first) {
            nodes { \(lf) }
            edges { node { \(lf) } }
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
        do {
            return try await fetchLookbookPost(postId: postId, includeTaggedProductCount: true)
        } catch {
            if graphQLRejectsExtendedLookbookPostFields(error) {
                return try await fetchLookbookPost(postId: postId, includeTaggedProductCount: false)
            }
            throw error
        }
    }

    private func fetchLookbookPost(postId: String, includeTaggedProductCount: Bool) async throws -> ServerLookbookPost? {
        let lf = lookbookPostGraphQLFields(includeExtended: includeTaggedProductCount)
        let query = """
        query LookbookPost($postId: UUID!) {
          lookbookPost(postId: $postId) { \(lf) }
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

    /// User row returned when listing who liked a lookbook post (field names align with `getUser`-style responses).
    struct LookbookPostLikeUser: Decodable, Identifiable, Hashable {
        let username: String
        let profilePictureUrl: String?
        var id: String { username }
    }

    /// Loads users who liked a post. Tries a few common schema shapes; throws if none succeed.
    func fetchLookbookPostLikers(postId: String) async throws -> [LookbookPostLikeUser] {
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: postId)
        let variables: [String: Any] = ["postId": normalized]

        let qRoot = """
        query LookbookPostLikers($postId: UUID!) {
          lookbookPostLikers(postId: $postId) {
            username
            profilePictureUrl
          }
        }
        """
        struct RootResponse: Decodable { let lookbookPostLikers: [LookbookPostLikeUser]? }
        do {
            let r: RootResponse = try await client.execute(
                query: qRoot,
                variables: variables,
                operationName: "LookbookPostLikers",
                responseType: RootResponse.self
            )
            if let list = r.lookbookPostLikers { return list }
        } catch {}

        let qNested = """
        query LookbookPostLikersNested($postId: UUID!) {
          lookbookPost(postId: $postId) {
            likers {
              username
              profilePictureUrl
            }
          }
        }
        """
        struct NestedPayload: Decodable { let likers: [LookbookPostLikeUser]? }
        struct NestedResponse: Decodable { let lookbookPost: NestedPayload? }
        do {
            let r: NestedResponse = try await client.execute(
                query: qNested,
                variables: variables,
                operationName: "LookbookPostLikersNested",
                responseType: NestedResponse.self
            )
            if let list = r.lookbookPost?.likers { return list }
        } catch {}

        let qAlt = """
        query LookbookPostLikeUsers($postId: UUID!) {
          lookbookPostLikeUsers(postId: $postId) {
            username
            profilePictureUrl
          }
        }
        """
        struct AltResponse: Decodable { let lookbookPostLikeUsers: [LookbookPostLikeUser]? }
        let r: AltResponse = try await client.execute(
            query: qAlt,
            variables: variables,
            operationName: "LookbookPostLikeUsers",
            responseType: AltResponse.self
        )
        return r.lookbookPostLikeUsers ?? []
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
