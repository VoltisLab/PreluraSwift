//
//  ForumService.swift
//  Prelura-swift
//
//  Community forum: topics, upvotes, threaded comments, comment likes (GraphQL).
//

import Foundation

struct ForumTopicDTO: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let username: String
    let profilePictureUrl: String?
    let createdAt: String?
    let upvotesCount: Int?
    let commentsCount: Int?
    let userUpvoted: Bool?

    var stableId: String { LookbookPostIdFormatting.graphQLUUIDString(from: id) }

    init(
        id: String,
        title: String,
        body: String,
        username: String,
        profilePictureUrl: String?,
        createdAt: String?,
        upvotesCount: Int?,
        commentsCount: Int?,
        userUpvoted: Bool?
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.username = username
        self.profilePictureUrl = profilePictureUrl
        self.createdAt = createdAt
        self.upvotesCount = upvotesCount
        self.commentsCount = commentsCount
        self.userUpvoted = userUpvoted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        username = try c.decode(String.self, forKey: .username)
        profilePictureUrl = try c.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        upvotesCount = try c.decodeIfPresent(Int.self, forKey: .upvotesCount)
        commentsCount = try c.decodeIfPresent(Int.self, forKey: .commentsCount)
        userUpvoted = try c.decodeIfPresent(Bool.self, forKey: .userUpvoted)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, body, username, profilePictureUrl, createdAt, upvotesCount, commentsCount, userUpvoted
    }

    func withUpdates(upvotesCount: Int? = nil, commentsCount: Int? = nil, userUpvoted: Bool? = nil) -> ForumTopicDTO {
        ForumTopicDTO(
            id: id,
            title: title,
            body: body,
            username: username,
            profilePictureUrl: profilePictureUrl,
            createdAt: createdAt,
            upvotesCount: upvotesCount ?? self.upvotesCount,
            commentsCount: commentsCount ?? self.commentsCount,
            userUpvoted: userUpvoted ?? self.userUpvoted
        )
    }
}

struct ForumCommentDTO: Decodable, Identifiable {
    let id: String
    let username: String
    let text: String
    let createdAt: String?
    let profilePictureUrl: String?
    let parentCommentId: String?
    let likesCount: Int?
    let userLiked: Bool?

    func withLikeUpdate(likesCount: Int, userLiked: Bool) -> ForumCommentDTO {
        ForumCommentDTO(
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

final class ForumService {
    private let client: GraphQLClient
    private var authToken: String?

    init(client: GraphQLClient) {
        self.client = client
    }

    func setAuthToken(_ token: String?) {
        authToken = token
        client.setAuthToken(token)
    }

    func fetchTopics(first: Int = 50) async throws -> [ForumTopicDTO] {
        let query = """
        query ForumTopics($first: Int) {
          forumTopics(first: $first) {
            nodes {
              id
              title
              body
              username
              profilePictureUrl
              createdAt
              upvotesCount
              commentsCount
              userUpvoted
            }
            edges { node {
              id
              title
              body
              username
              profilePictureUrl
              createdAt
              upvotesCount
              commentsCount
              userUpvoted
            } }
          }
        }
        """
        let variables: [String: Any] = ["first": first]
        struct Response: Decodable {
            let forumTopics: Conn?
        }
        struct Conn: Decodable {
            let nodes: [ForumTopicDTO]?
            let edges: [Edge]?
        }
        struct Edge: Decodable {
            let node: ForumTopicDTO?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "ForumTopics",
            responseType: Response.self
        )
        if let nodes = response.forumTopics?.nodes, !nodes.isEmpty { return nodes }
        if let edges = response.forumTopics?.edges {
            return edges.compactMap(\.node)
        }
        return []
    }

    func fetchTopic(topicId: String) async throws -> ForumTopicDTO? {
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: topicId)
        let query = """
        query ForumTopic($topicId: UUID!) {
          forumTopic(topicId: $topicId) {
            id
            title
            body
            username
            profilePictureUrl
            createdAt
            upvotesCount
            commentsCount
            userUpvoted
          }
        }
        """
        struct Response: Decodable { let forumTopic: ForumTopicDTO? }
        let response: Response = try await client.execute(
            query: query,
            variables: ["topicId": normalized],
            operationName: "ForumTopic",
            responseType: Response.self
        )
        return response.forumTopic
    }

    func fetchComments(topicId: String) async throws -> [ForumCommentDTO] {
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: topicId)
        let query = """
        query ForumComments($topicId: UUID!) {
          forumComments(topicId: $topicId) {
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
        struct Response: Decodable { let forumComments: [ForumCommentDTO]? }
        let response: Response = try await client.execute(
            query: query,
            variables: ["topicId": normalized],
            operationName: "ForumComments",
            responseType: Response.self
        )
        return response.forumComments ?? []
    }

    func createTopic(title: String, body: String) async throws -> ForumTopicDTO {
        let query = """
        mutation CreateForumTopic($title: String!, $body: String!) {
          createForumTopic(title: $title, body: $body) {
            success
            message
            topic {
              id
              title
              body
              username
              profilePictureUrl
              createdAt
              upvotesCount
              commentsCount
              userUpvoted
            }
          }
        }
        """
        struct Response: Decodable { let createForumTopic: Payload? }
        struct Payload: Decodable {
            let success: Bool?
            let message: String?
            let topic: ForumTopicDTO?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: ["title": title, "body": body],
            operationName: "CreateForumTopic",
            responseType: Response.self
        )
        guard let payload = response.createForumTopic, payload.success == true, let topic = payload.topic else {
            throw NSError(
                domain: "ForumService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.createForumTopic?.message ?? "Could not create topic"]
            )
        }
        return topic
    }

    func toggleTopicUpvote(topicId: String) async throws -> (upvoted: Bool, upvotesCount: Int) {
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: topicId)
        let query = """
        mutation ToggleForumTopicUpvote($topicId: UUID!) {
          toggleForumTopicUpvote(topicId: $topicId) {
            success
            message
            upvoted
            upvotesCount
          }
        }
        """
        struct Response: Decodable { let toggleForumTopicUpvote: Payload? }
        struct Payload: Decodable {
            let success: Bool?
            let message: String?
            let upvoted: Bool?
            let upvotesCount: Int?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: ["topicId": normalized],
            operationName: "ToggleForumTopicUpvote",
            responseType: Response.self
        )
        guard let payload = response.toggleForumTopicUpvote, payload.success == true else {
            throw NSError(
                domain: "ForumService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.toggleForumTopicUpvote?.message ?? "Upvote failed"]
            )
        }
        return (payload.upvoted ?? false, payload.upvotesCount ?? 0)
    }

    func addComment(topicId: String, text: String, parentCommentId: String? = nil) async throws -> (comment: ForumCommentDTO, commentsCount: Int) {
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: topicId)
        var variables: [String: Any] = ["topicId": normalized, "text": text]
        if let rawParent = parentCommentId?.trimmingCharacters(in: .whitespacesAndNewlines), !rawParent.isEmpty {
            variables["parentCommentId"] = LookbookPostIdFormatting.graphQLUUIDString(from: rawParent)
        } else {
            variables["parentCommentId"] = NSNull()
        }
        let query = """
        mutation AddForumComment($topicId: UUID!, $text: String!, $parentCommentId: UUID) {
          addForumComment(topicId: $topicId, text: $text, parentCommentId: $parentCommentId) {
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
        struct Response: Decodable { let addForumComment: Payload? }
        struct Payload: Decodable {
            let success: Bool?
            let message: String?
            let commentsCount: Int?
            let comment: ForumCommentDTO?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: variables,
            operationName: "AddForumComment",
            responseType: Response.self
        )
        guard let payload = response.addForumComment, payload.success == true, let comment = payload.comment else {
            throw NSError(
                domain: "ForumService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.addForumComment?.message ?? "Could not post comment"]
            )
        }
        return (comment, payload.commentsCount ?? 0)
    }

    func toggleCommentLike(commentId: String) async throws -> (liked: Bool, likesCount: Int) {
        let normalized = LookbookPostIdFormatting.graphQLUUIDString(from: commentId)
        let query = """
        mutation ToggleForumCommentLike($commentId: UUID!) {
          toggleForumCommentLike(commentId: $commentId) {
            success
            message
            liked
            likesCount
          }
        }
        """
        struct Response: Decodable { let toggleForumCommentLike: Payload? }
        struct Payload: Decodable {
            let success: Bool?
            let message: String?
            let liked: Bool?
            let likesCount: Int?
        }
        let response: Response = try await client.execute(
            query: query,
            variables: ["commentId": normalized],
            operationName: "ToggleForumCommentLike",
            responseType: Response.self
        )
        guard let payload = response.toggleForumCommentLike, payload.success == true else {
            throw NSError(
                domain: "ForumService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.toggleForumCommentLike?.message ?? "Like failed"]
            )
        }
        return (payload.liked ?? false, payload.likesCount ?? 0)
    }
}

/// Replaces raw GraphQL validation errors when the API has not been deployed with `community_forum` yet.
enum ForumErrorPresentation {
    static func userMessage(for error: Error) -> String {
        let msg = error.localizedDescription
        let m = msg.lowercased()
        if m.contains("cannot query field") && m.contains("forum") {
            return L10n.string(
                "The forum is not available on this server yet. Deploy the latest backend and run migrations, then try again."
            )
        }
        return msg
    }
}
