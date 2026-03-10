import SwiftUI

/// List of in-app notifications (Flutter NotificationsScreen + NotificationsTab).
struct NotificationsListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [AppNotification] = []
    @State private var totalNumber: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var page = 1
    private let pageSize = 15
    private let notificationService = NotificationService()

    var body: some View {
        Group {
            if isLoading && notifications.isEmpty && errorMessage == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage, notifications.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(err)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        errorMessage = nil
                        Task { await load(page: 1) }
                    }
                    .foregroundColor(Theme.primaryColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notifications.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text("No notifications")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(notifications) { notification in
                        NotificationRowView(notification: notification)
                    }
                    if notifications.count < totalNumber && !isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .onAppear { Task { await loadMore() } }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load(page: 1)
        }
        .onAppear {
            Task { await load(page: 1) }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func load(page: Int) async {
        if page == 1 { isLoading = true; errorMessage = nil }
        defer { if page == 1 { isLoading = false } }
        do {
            notificationService.updateAuthToken(UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
            let (list, total) = try await notificationService.getNotifications(pageCount: pageSize, pageNumber: page)
            await MainActor.run {
                if page == 1 {
                    notifications = list
                    totalNumber = total
                    self.page = 1
                } else {
                    notifications.append(contentsOf: list)
                    self.page = page
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func loadMore() async {
        guard !isLoading, notifications.count < totalNumber else { return }
        await load(page: page + 1)
    }
}

private struct NotificationRowView: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            if let sender = notification.sender, let urlString = sender.profilePictureUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Circle()
                            .fill(Theme.primaryColor.opacity(0.3))
                            .overlay(
                                Text(String((sender.username ?? "?").prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person")
                            .foregroundColor(Theme.Colors.secondaryText)
                    )
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(2)
                if let date = notification.createdAt {
                    Text(formatDate(date))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !notification.isRead {
                Circle()
                    .fill(Theme.primaryColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        NotificationsListView()
    }
}
