import SwiftUI

/// Stand-alone fake lookbook feed: full-width remote images, avatar + username + subtitle, compact action bar (no production lookbook views).
private struct DebugSandboxFeedRow: Identifiable {
    let id: UUID
    var username: String
    /// Style line under the username (e.g. outfit / category).
    var subtitle: String
    var avatarURL: String
    var imageURL: String
    var liked: Bool
    var likeCount: Int
    var commentsCount: Int
    var saved: Bool
    /// Local-only lines typed in the sandbox comment sheet (not persisted to a server).
    var localPreviewComments: [String]
}

private struct CommentSheetTarget: Identifiable, Hashable {
    let id: UUID
}

struct DebugLookbookFeedSandboxView: View {
    private let actionIconSize: CGFloat = 20
    private let likeCountSize: CGFloat = 14

    @State private var rows: [DebugSandboxFeedRow] = [
        DebugSandboxFeedRow(
            id: UUID(),
            username: "maria_styles",
            subtitle: "Party dress",
            avatarURL: "https://i.pravatar.cc/128?img=47",
            imageURL: "https://picsum.photos/id/64/1080/1350",
            liked: false,
            likeCount: 12,
            commentsCount: 2,
            saved: false,
            localPreviewComments: []
        ),
        DebugSandboxFeedRow(
            id: UUID(),
            username: "jordan.lee",
            subtitle: "Streetwear drop",
            avatarURL: "https://i.pravatar.cc/128?img=12",
            imageURL: "https://picsum.photos/id/177/1080/1350",
            liked: true,
            likeCount: 48,
            commentsCount: 0,
            saved: true,
            localPreviewComments: []
        ),
        DebugSandboxFeedRow(
            id: UUID(),
            username: "theo.vintage",
            subtitle: "Y2K denim",
            avatarURL: "https://i.pravatar.cc/128?img=33",
            imageURL: "https://picsum.photos/id/338/1080/1350",
            liked: false,
            likeCount: 3,
            commentsCount: 7,
            saved: false,
            localPreviewComments: []
        ),
        DebugSandboxFeedRow(
            id: UUID(),
            username: "nina.knit",
            subtitle: "Lounge set",
            avatarURL: "https://i.pravatar.cc/128?img=45",
            imageURL: "https://picsum.photos/id/349/1080/1350",
            liked: false,
            likeCount: 0,
            commentsCount: 0,
            saved: false,
            localPreviewComments: []
        ),
        DebugSandboxFeedRow(
            id: UUID(),
            username: "sam_outfits",
            subtitle: "Summer edit",
            avatarURL: "https://i.pravatar.cc/128?img=15",
            imageURL: "https://picsum.photos/id/431/1080/1350",
            liked: true,
            likeCount: 1,
            commentsCount: 1,
            saved: false,
            localPreviewComments: []
        )
    ]

    @State private var commentSheetTarget: CommentSheetTarget?
    @State private var commentDraft: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Isolated UI: full-width photos, header with avatar, name + subtitle, action row comment → send, like and save on the right.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.md)

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    sandboxRow(index: index, row: row)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Lookbook feed sandbox")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $commentSheetTarget) { target in
            DebugSandboxCommentSheet(
                comments: commentsBinding(for: target.id),
                draft: $commentDraft,
                onSend: { text in
                    postComment(postId: target.id, text: text)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(22)
        }
    }

    private func commentsBinding(for postId: UUID) -> Binding<[String]> {
        Binding(
            get: { rows.first(where: { $0.id == postId })?.localPreviewComments ?? [] },
            set: { newValue in
                if let i = rows.firstIndex(where: { $0.id == postId }) {
                    rows[i].localPreviewComments = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func sandboxRow(index: Int, row: DebugSandboxFeedRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                sandboxAvatar(urlString: row.avatarURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                    Text(row.subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)

            fullWidthRemoteImage(urlString: row.imageURL)

            sandboxActionBar(index: index, row: row)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(Theme.Colors.background)

            Rectangle()
                .fill(Theme.Colors.glassBorder.opacity(0.35))
                .frame(height: 0.5)
                .padding(.leading, Theme.Spacing.md)
        }
    }

    @ViewBuilder
    private func sandboxActionBar(index: Int, row: DebugSandboxFeedRow) -> some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                LikeButtonView(
                    isLiked: row.liked,
                    likeCount: row.likeCount,
                    action: { toggleLike(at: index) },
                    onDarkOverlay: false,
                    heartPointSize: 20,
                    likeCountFormatting: LookbookFeedEngagementCountFormatting.short
                )

                Button {
                    HapticManager.tap()
                    commentDraft = ""
                    commentSheetTarget = CommentSheetTarget(id: row.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: actionIconSize, weight: .medium))
                            .foregroundStyle(Theme.Colors.primaryText)
                        Text(LookbookFeedEngagementCountFormatting.short(row.commentsCount))
                            .font(.system(size: likeCountSize, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.tap()
                } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: actionIconSize, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button {
                HapticManager.tap()
                toggleSave(at: index)
            } label: {
                Image(systemName: row.saved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: actionIconSize, weight: .medium))
                    .foregroundStyle(row.saved ? Theme.primaryColor : Theme.Colors.primaryText)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sandboxAvatar(urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        avatarPlaceholder
                    case .empty:
                        avatarPlaceholder
                            .overlay { ProgressView().scaleEffect(0.7) }
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Theme.Colors.secondaryBackground)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }
    }

    /// Edge-to-edge width; portrait aspect ~ 4:5 so the slot matches typical lookbook crops.
    @ViewBuilder
    private func fullWidthRemoteImage(urlString: String) -> some View {
        let aspect: CGFloat = 4 / 5
        Group {
            if let url = URL(string: urlString) {
                Color.clear
                    .aspectRatio(aspect, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                imageFailurePlaceholder
                            case .empty:
                                ZStack {
                                    Theme.Colors.secondaryBackground.opacity(0.5)
                                    ProgressView()
                                }
                            @unknown default:
                                imageFailurePlaceholder
                            }
                        }
                    }
                    .clipped()
            } else {
                imageFailurePlaceholder
                    .aspectRatio(aspect, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var imageFailurePlaceholder: some View {
        Theme.Colors.secondaryBackground
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    Text("Could not load image")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
    }

    private func toggleLike(at index: Int) {
        guard rows.indices.contains(index) else { return }
        rows[index].liked.toggle()
        rows[index].likeCount += rows[index].liked ? 1 : -1
        if rows[index].likeCount < 0 { rows[index].likeCount = 0 }
    }

    private func postComment(postId: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = rows.firstIndex(where: { $0.id == postId }) else { return }
        rows[i].localPreviewComments.append(trimmed)
        rows[i].commentsCount += 1
    }

    private func toggleSave(at index: Int) {
        guard rows.indices.contains(index) else { return }
        rows[index].saved.toggle()
    }
}

// MARK: - Comment sheet (sandbox preview only)

private struct DebugSandboxCommentSheet: View {
    @Binding var comments: [String]
    @Binding var draft: String
    var onSend: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var composerFocused: Bool

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if comments.isEmpty {
                    Text(L10n.string("No comments yet"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.sm)
                        .padding(.bottom, Theme.Spacing.sm)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(comments.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("you")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Theme.Colors.primaryText)
                                        Text(line)
                                            .font(.system(size: 15))
                                            .foregroundStyle(Theme.Colors.primaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    TextEditor(text: $draft)
                        .focused($composerFocused)
                        .frame(minHeight: 100, maxHeight: 160)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Theme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Write a comment…")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.Colors.tertiaryText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    PrimaryGlassButton(
                        L10n.string("Send"),
                        isEnabled: canSend,
                        action: sendCurrentDraft
                    )
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.md)
                .background(Theme.Colors.background)
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Comments"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundStyle(Theme.primaryColor)
                }
            }
        }
    }

    private func sendCurrentDraft() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onSend(t)
        draft = ""
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DebugLookbookFeedSandboxView()
    }
}
#endif
