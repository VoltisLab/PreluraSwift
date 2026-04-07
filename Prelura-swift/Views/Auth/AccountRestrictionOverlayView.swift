import SwiftUI

/// Full-screen state when the account is banned or temporarily suspended (from `viewMe` / GraphQL errors).
struct AccountRestrictionOverlayView: View {
    @EnvironmentObject private var authService: AuthService

    private var title: String {
        authService.accountIsBanned ? "Account banned" : "Account suspended"
    }

    private var detail: String {
        if authService.accountIsBanned {
            return "This account is no longer allowed to use WEARHOUSE. If you think this is a mistake, contact support through the help options on our website."
        }
        if let end = authService.accountSuspendedUntil, end > Date() {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return "Your access is paused until \(f.string(from: end)). You can still open your Inbox to read messages from Support. If this was a mistake, reply in your support thread."
        }
        return "Your access is temporarily limited. Open Inbox for messages from Support, or sign out and try again later."
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primaryColor)
                Text(title)
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)
                Text(detail)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                Button {
                    Task { await authService.logout() }
                } label: {
                    Text("Sign out")
                        .font(Theme.Typography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.md)
            }
            .padding(Theme.Spacing.lg)
        }
    }
}
