import SwiftUI

/// List of users that the given user follows (Flutter FollowingRoute).
struct FollowingListView: View {
    let username: String
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var users: [User] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(L10n.string("Not following anyone yet"))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(users, id: \.id) { user in
                    NavigationLink(destination: UserProfileView(seller: user, authService: authService)) {
                        HStack(spacing: Theme.Spacing.md) {
                            if let urlString = user.avatarURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                                    default: Circle().fill(Theme.primaryColor.opacity(0.3))
                                        .overlay(Text(String(user.username.prefix(1)).uppercased()).font(.system(size: 18, weight: .semibold)).foregroundColor(.white))
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Theme.primaryColor.opacity(0.3))
                                    .frame(width: 44, height: 44)
                                    .overlay(Text(String(user.username.prefix(1)).uppercased()).font(.system(size: 18, weight: .semibold)).foregroundColor(.white))
                            }
                            Text(user.username)
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Following"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                users = []
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        FollowingListView(username: "test")
            .environmentObject(AuthService())
    }
}
