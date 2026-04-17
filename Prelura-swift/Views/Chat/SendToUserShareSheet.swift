import SwiftUI

/// Recent chats, followers, and username search — same UX as lookbook “Send to…”.
struct SendToUserShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    /// Omits this username from suggestions (e.g. lookbook post author or listing seller).
    var excludeUsername: String?
    let onPick: (User) -> Void

    @State private var recentUsers: [User] = []
    @State private var followerUsers: [User] = []
    @State private var loading = true
    @State private var errorText: String?
    @State private var searchQuery: String = ""
    @State private var searchResults: [User] = []
    @State private var searchLoading = false
    @State private var searchTask: Task<Void, Never>?

    private let userService = UserService()

    private var meLower: String {
        (authService.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var excludeLower: String {
        (excludeUsername ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Prelura Support / similar handles must not receive forwards from any user.
    private func isBlockedPreluraSupportRecipient(_ user: User) -> Bool {
        let u = user.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !u.isEmpty else { return false }
        let compact = u.replacingOccurrences(of: "_", with: "")
        return compact == "prelurasupport"
    }

    private static let sendToRecentCap = 20
    private static let sendToRecent7s: TimeInterval = 7 * 24 * 3600
    private static let sendToRecent30s: TimeInterval = 30 * 24 * 3600

    private static func recentUsersFromConversations(
        sortedNewestFirst convs: [Conversation],
        meLower: String,
        excludeLower: String,
        isBlocked: (User) -> Bool
    ) -> [User] {
        let now = Date()
        let cutoff7 = now.addingTimeInterval(-sendToRecent7s)
        let cutoff30 = now.addingTimeInterval(-sendToRecent30s)

        func collect(since: Date) -> [User] {
            var seen = Set<String>()
            var out: [User] = []
            for c in convs {
                let activity = c.lastMessageTime ?? .distantPast
                guard activity >= since else { continue }
                let u = c.recipient
                let key = u.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if key.isEmpty || key == meLower { continue }
                if !excludeLower.isEmpty, key == excludeLower { continue }
                if isBlocked(u) { continue }
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                out.append(u)
                if out.count >= sendToRecentCap { break }
            }
            return out
        }

        let from7 = collect(since: cutoff7)
        if from7.count >= sendToRecentCap {
            return from7
        }
        return collect(since: cutoff30)
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorText, !err.isEmpty {
                    Text(err)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                            Section {
                                if searchLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                } else if searchResults.isEmpty {
                                    Text(L10n.string("No users found"))
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                } else {
                                    ForEach(searchResults) { user in
                                        userRow(user)
                                    }
                                }
                            } header: {
                                sendToSectionHeader(L10n.string("Search results"))
                            }
                        } else {
                            if !recentUsers.isEmpty {
                                Section {
                                    ForEach(recentUsers) { user in
                                        userRow(user)
                                    }
                                } header: {
                                    sendToSectionHeader(L10n.string("Recent"))
                                }
                            }
                            if !followerUsers.isEmpty {
                                Section {
                                    ForEach(followerUsers) { user in
                                        userRow(user)
                                    }
                                } header: {
                                    sendToSectionHeader(L10n.string("Followers"))
                                }
                            }
                            if recentUsers.isEmpty && followerUsers.isEmpty {
                                ContentUnavailableView(
                                    L10n.string("No recipients yet"),
                                    systemImage: "person.crop.circle.badge.questionmark",
                                    description: Text(L10n.string("Message someone, get followers, or search by username."))
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 0)
                    .listSectionSpacing(10)
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Send to"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(L10n.string("Search username"))
            )
            .onSubmit(of: .search) {
                Task { await runSearchNow() }
            }
            .onChange(of: searchQuery) { _, _ in
                scheduleSearch()
            }
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.string("Close")) { dismiss() }
                        .foregroundStyle(Theme.primaryColor)
                }
            }
            .onDisappear { searchTask?.cancel() }
            .task { await loadRecipients() }
        }
    }

    private func sendToSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.secondaryText)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    @ViewBuilder
    private func userRow(_ user: User) -> some View {
        let blocked = isBlockedPreluraSupportRecipient(user)
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            avatar(for: user)
                .frame(width: 40, height: 40)
            Text("@\(user.username)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                guard !blocked else { return }
                HapticManager.tap()
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onPick(user)
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(blocked ? Theme.Colors.tertiaryText : Theme.primaryColor)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(blocked)
            .accessibilityLabel(L10n.string("Send"))
        }
        .listRowInsets(EdgeInsets(top: 6, leading: Theme.Spacing.md, bottom: 6, trailing: Theme.Spacing.md))
        .listRowBackground(Theme.Colors.background)
    }

    @ViewBuilder
    private func avatar(for user: User) -> some View {
        let trimmed = user.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let url = URL(string: trimmed), !trimmed.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Circle().fill(Theme.Colors.secondaryBackground)
                }
            }
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Theme.Colors.secondaryBackground)
                .overlay(
                    Text(String(user.username.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.secondaryText)
                )
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            searchResults = []
            searchLoading = false
            return
        }
        searchLoading = true
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            let latest = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard latest.count >= 2 else {
                searchResults = []
                searchLoading = false
                return
            }
            await runSearch(query: latest)
        }
    }

    @MainActor
    private func runSearchNow() async {
        let latest = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard latest.count >= 2 else {
            searchResults = []
            searchLoading = false
            return
        }
        await runSearch(query: latest)
    }

    @MainActor
    private func runSearch(query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            searchLoading = false
            return
        }
        userService.updateAuthToken(authService.authToken)
        searchLoading = true
        do {
            let found = try await userService.searchUsers(search: query)
            let filtered = found.filter { u in
                let ul = u.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !ul.isEmpty else { return false }
                if isBlockedPreluraSupportRecipient(u) { return false }
                if ul == meLower { return false }
                if !excludeLower.isEmpty, ul == excludeLower { return false }
                return true
            }
            searchResults = filtered
            searchLoading = false
        } catch {
            searchResults = []
            searchLoading = false
        }
    }

    @MainActor
    private func loadRecipients() async {
        guard let me = authService.username?.trimmingCharacters(in: .whitespacesAndNewlines), !me.isEmpty else {
            loading = false
            errorText = L10n.string("Sign in to share.")
            return
        }
        let chat = ChatService()
        chat.updateAuthToken(authService.authToken)
        userService.updateAuthToken(authService.authToken)
        do {
            async let convsTask = chat.getConversations()
            async let followersTask = userService.getFollowers(username: me, pageNumber: 1, pageCount: 200)
            let (convs, followers) = try await (convsTask, followersTask)

            let sortedConvs = convs.sorted { a, b in
                let da = a.lastMessageTime ?? .distantPast
                let db = b.lastMessageTime ?? .distantPast
                return da > db
            }
            let recentOrdered = Self.recentUsersFromConversations(
                sortedNewestFirst: sortedConvs,
                meLower: meLower,
                excludeLower: excludeLower,
                isBlocked: isBlockedPreluraSupportRecipient
            )

            let sortedFollowers = followers.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            var followerOrdered: [User] = []
            var seenFollow = Set(
                recentOrdered.map { $0.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            )
            for u in sortedFollowers {
                let key = u.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if key.isEmpty || key == meLower { continue }
                if !excludeLower.isEmpty, key == excludeLower { continue }
                if isBlockedPreluraSupportRecipient(u) { continue }
                guard !seenFollow.contains(key) else { continue }
                seenFollow.insert(key)
                followerOrdered.append(u)
            }

            recentUsers = recentOrdered
            followerUsers = followerOrdered
            loading = false
            errorText = nil
        } catch {
            loading = false
            errorText = L10n.userFacingError(error)
        }
    }
}
