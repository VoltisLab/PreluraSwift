//
//  ForumTopicDetailView.swift
//  Prelura-swift
//
//  Single forum topic: upvotes, threaded comments, likes, reply composer.
//

import SwiftUI

struct ForumTopicDetailView: View {
    @EnvironmentObject var authService: AuthService

    let topicId: String
    var initialTopic: ForumTopicDTO?

    @State private var topic: ForumTopicDTO?
    @State private var comments: [ForumCommentDTO] = []
    @State private var isLoading = false
    @State private var composerText = ""
    @State private var replyTo: ForumCommentDTO?
    @State private var sendError: String?

    private var displayedTopic: ForumTopicDTO? { topic ?? initialTopic }

    var body: some View {
        Group {
            if let t = displayedTopic {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            topicHeader(t)
                            if authService.isGuestMode {
                                guestBanner
                            }
                            Divider()
                            Text(L10n.string("Comments"))
                                .font(Theme.Typography.headline)
                                .foregroundStyle(Theme.Colors.primaryText)
                            let branches = forumCommentBranches(from: comments)
                            if branches.isEmpty {
                                Text(L10n.string("No comments yet. Be the first to share your thoughts."))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                                    .padding(.vertical, Theme.Spacing.sm)
                            } else {
                                LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    ForEach(branches) { branch in
                                        ForumCommentBranchView(
                                            branch: branch,
                                            depth: 0,
                                            authService: authService,
                                            onReply: { c in
                                                replyTo = c
                                                HapticManager.selection()
                                            },
                                            onToggleLike: { c in
                                                Task { await toggleCommentLike(c) }
                                            }
                                        )
                                    }
                                }
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .onChange(of: comments.count) { _, _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Text(L10n.string("Topic not found"))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Discussion"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            composerBar
        }
        .task {
            await refreshTopicAndComments()
        }
    }

    private var guestBanner: some View {
        Text(L10n.string("Sign in to vote or comment."))
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.secondaryText)
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.primaryColor.opacity(0.12))
            .cornerRadius(8)
    }

    private func topicHeader(_ t: ForumTopicDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(t.title)
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.primaryText)
            Text(t.body)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.primaryText)
            HStack {
                Text("@\(t.username)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.primaryColor)
                Spacer()
                Button {
                    guard !authService.isGuestMode else {
                        HapticManager.error()
                        return
                    }
                    Task { await toggleTopicUpvote() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: (t.userUpvoted ?? false) ? "arrow.up.circle.fill" : "arrow.up.circle")
                        Text("\(t.upvotesCount ?? 0)")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle((t.userUpvoted ?? false) ? Theme.primaryColor : Theme.Colors.secondaryText)
                }
                .buttonStyle(.plain)
                .disabled(authService.isGuestMode)
            }
        }
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let r = replyTo {
                HStack {
                    Text(String(format: L10n.string("Replying to @%@"), r.username))
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Spacer()
                    Button(L10n.string("Clear")) {
                        replyTo = nil
                    }
                    .font(.caption)
                }
            }
            if let err = sendError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
                TextField(L10n.string("Write a comment…"), text: $composerText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .disabled(authService.isGuestMode)
                Button {
                    Task { await sendComment() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.primaryColor)
                }
                .disabled(authService.isGuestMode || composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background.opacity(0.98))
        }
        .overlay(Divider(), alignment: .top)
    }

    private func service() -> ForumService {
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let s = ForumService(client: client)
        s.setAuthToken(authService.authToken)
        return s
    }

    private func refreshTopicAndComments() async {
        let sid = LookbookPostIdFormatting.graphQLUUIDString(from: topicId)
        await MainActor.run { isLoading = true }
        let s = service()
        do {
            async let t = s.fetchTopic(topicId: sid)
            async let c = s.fetchComments(topicId: sid)
            let (fetchedTopic, fetchedComments) = try await (t, c)
            await MainActor.run {
                if let ft = fetchedTopic {
                    topic = ft
                }
                comments = fetchedComments
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func toggleTopicUpvote() async {
        let sid = LookbookPostIdFormatting.graphQLUUIDString(from: topicId)
        do {
            let result = try await service().toggleTopicUpvote(topicId: sid)
            await MainActor.run {
                if let base = topic ?? initialTopic {
                    topic = base.withUpdates(upvotesCount: result.upvotesCount, userUpvoted: result.upvoted)
                }
                HapticManager.toggle()
            }
        } catch {
            await MainActor.run { HapticManager.error() }
        }
    }

    private func sendComment() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let sid = LookbookPostIdFormatting.graphQLUUIDString(from: topicId)
        let parentId = replyTo.map { LookbookPostIdFormatting.graphQLUUIDString(from: $0.id) }
        await MainActor.run { sendError = nil }
        do {
            let out = try await service().addComment(topicId: sid, text: text, parentCommentId: parentId)
            await MainActor.run {
                composerText = ""
                replyTo = nil
                comments.append(out.comment)
                if let base = topic ?? initialTopic {
                    topic = base.withUpdates(commentsCount: out.commentsCount)
                }
                HapticManager.success()
            }
        } catch {
            await MainActor.run {
                sendError = ForumErrorPresentation.userMessage(for: error)
                HapticManager.error()
            }
        }
    }

    private func toggleCommentLike(_ c: ForumCommentDTO) async {
        guard !authService.isGuestMode else {
            await MainActor.run { HapticManager.error() }
            return
        }
        do {
            let result = try await service().toggleCommentLike(commentId: c.id)
            let nid = LookbookPostIdFormatting.graphQLUUIDString(from: c.id).lowercased()
            await MainActor.run {
                comments = comments.map { row in
                    let rid = LookbookPostIdFormatting.graphQLUUIDString(from: row.id).lowercased()
                    if rid == nid {
                        return row.withLikeUpdate(likesCount: result.likesCount, userLiked: result.liked)
                    }
                    return row
                }
                HapticManager.like()
            }
        } catch {
            await MainActor.run { HapticManager.error() }
        }
    }
}

// MARK: - Comment tree

private struct ForumCommentBranch: Identifiable {
    var id: String { comment.id }
    let comment: ForumCommentDTO
    var replies: [ForumCommentBranch]
}

private func forumCommentBranches(from flat: [ForumCommentDTO]) -> [ForumCommentBranch] {
    let normalizedIds = Set(flat.map { LookbookPostIdFormatting.graphQLUUIDString(from: $0.id).lowercased() })
    let byParent = Dictionary(grouping: flat) { c -> String in
        guard let p = c.parentCommentId, !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return LookbookPostIdFormatting.graphQLUUIDString(from: p).lowercased()
    }

    func build(_ c: ForumCommentDTO) -> ForumCommentBranch {
        let cid = LookbookPostIdFormatting.graphQLUUIDString(from: c.id).lowercased()
        let subs = (byParent[cid] ?? []).sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
        return ForumCommentBranch(comment: c, replies: subs.map { build($0) })
    }

    let roots = flat.filter { c in
        guard let p = c.parentCommentId, !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        let pid = LookbookPostIdFormatting.graphQLUUIDString(from: p).lowercased()
        return !normalizedIds.contains(pid)
    }
    .sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }

    return roots.map { build($0) }
}

private struct ForumCommentBranchView: View {
    let branch: ForumCommentBranch
    let depth: Int
    let authService: AuthService
    let onReply: (ForumCommentDTO) -> Void
    let onToggleLike: (ForumCommentDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForumCommentRowInner(
                comment: branch.comment,
                authService: authService,
                onReply: onReply,
                onToggleLike: onToggleLike
            )
            ForEach(branch.replies) { reply in
                ForumCommentBranchView(
                    branch: reply,
                    depth: depth + 1,
                    authService: authService,
                    onReply: onReply,
                    onToggleLike: onToggleLike
                )
                .padding(.leading, CGFloat(min(depth + 1, 5)) * 12)
            }
        }
    }
}

private struct ForumCommentRowInner: View {
    let comment: ForumCommentDTO
    let authService: AuthService
    let onReply: (ForumCommentDTO) -> Void
    let onToggleLike: (ForumCommentDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text("@\(comment.username)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryColor)
                Spacer()
                Button {
                    onToggleLike(comment)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: (comment.userLiked ?? false) ? "heart.fill" : "heart")
                        Text("\(comment.likesCount ?? 0)")
                    }
                    .font(.caption)
                    .foregroundStyle((comment.userLiked ?? false) ? Theme.primaryColor : Theme.Colors.secondaryText)
                }
                .buttonStyle(.plain)
                .disabled(authService.isGuestMode)
            }
            Text(comment.text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.primaryText)
            Button(L10n.string("Reply")) {
                onReply(comment)
            }
            .font(.caption)
            .disabled(authService.isGuestMode)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.glassBorder.opacity(0.15))
        .cornerRadius(10)
    }
}
