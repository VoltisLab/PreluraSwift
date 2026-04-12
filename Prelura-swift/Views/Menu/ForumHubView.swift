//
//  ForumHubView.swift
//  Prelura-swift
//
//  Community forum entry from the menu: topic list, new topic, navigation to discussion.
//

import SwiftUI

struct ForumHubView: View {
    @EnvironmentObject var authService: AuthService
    @State private var topics: [ForumTopicDTO] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var showNewTopic = false

    var body: some View {
        Group {
            if isLoading && topics.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = loadError, topics.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Text(err)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button(L10n.string("Try again")) {
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(topics) { topic in
                        NavigationLink(value: topic) {
                            ForumTopicRowView(topic: topic)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Community Forum"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ForumTopicDTO.self) { topic in
            ForumTopicDetailView(topicId: topic.stableId, initialTopic: topic)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if authService.isGuestMode {
                        HapticManager.error()
                    } else {
                        HapticManager.tap()
                        showNewTopic = true
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(authService.isGuestMode)
            }
        }
        .sheet(isPresented: $showNewTopic) {
            ForumNewTopicSheet(onCreated: { created in
                topics.insert(created, at: 0)
            })
            .environmentObject(authService)
        }
        .task {
            await load()
        }
    }

    private func load() async {
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = ForumService(client: client)
        service.setAuthToken(authService.authToken)
        await MainActor.run {
            isLoading = true
            loadError = nil
        }
        do {
            let list = try await service.fetchTopics(first: 50)
            await MainActor.run {
                topics = list
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                loadError = ForumErrorPresentation.userMessage(for: error)
            }
        }
    }
}

private struct ForumTopicRowView: View {
    let topic: ForumTopicDTO

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(topic.title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.primaryText)
                .lineLimit(2)
            Text(topic.body)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .lineLimit(2)
            HStack(spacing: Theme.Spacing.md) {
                Label("\(topic.upvotesCount ?? 0)", systemImage: "arrow.up.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Label("\(topic.commentsCount ?? 0)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Text("@\(topic.username)")
                    .font(.caption)
                    .foregroundStyle(Theme.primaryColor)
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - New topic

private struct ForumNewTopicSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    var onCreated: (ForumTopicDTO) -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var isPosting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.string("Title"), text: $title)
                    TextField(L10n.string("Description"), text: $bodyText, axis: .vertical)
                        .lineLimit(4...12)
                } footer: {
                    Text(L10n.string("Share a bug, idea, or discussion topic with the community."))
                }
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.string("New topic"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Button(L10n.string("Post")) { Task { await post() } }
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func post() async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !b.isEmpty else { return }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = ForumService(client: client)
        service.setAuthToken(authService.authToken)
        await MainActor.run {
            isPosting = true
            errorMessage = nil
        }
        do {
            let created = try await service.createTopic(title: t, body: b)
            await MainActor.run {
                isPosting = false
                onCreated(created)
                dismiss()
            }
        } catch {
            await MainActor.run {
                isPosting = false
                errorMessage = ForumErrorPresentation.userMessage(for: error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ForumHubView()
            .environmentObject(AuthService())
    }
}
