import SwiftUI

/// Help Chat View (from Flutter help_chat_view). Placeholder for support conversation.
struct HelpChatView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Text("Start a conversation with our support team.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(Theme.Spacing.lg)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Help Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}
