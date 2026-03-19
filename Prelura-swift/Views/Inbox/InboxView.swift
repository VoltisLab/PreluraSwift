import SwiftUI

struct InboxView: View {
    @ObservedObject var tabCoordinator: TabCoordinator
    @StateObject private var inboxViewModel = InboxViewModel()
    @State private var path: [AppRoute] = []

    var body: some View {
        ChatListView(tabCoordinator: tabCoordinator, path: $path, inboxViewModel: inboxViewModel)
    }
}

struct InboxMessageRow: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Profile Picture
            ZStack {
                Circle()
                    .fill(Theme.primaryColor)
                    .frame(width: 50, height: 50)
                
                Text(String(message.senderUsername.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Sender Name
                Text(message.senderUsername)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                // Message Preview
                Text(message.preview)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(2)
                
                // Timestamp
                Text(message.formattedTimestamp)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            
            Spacer()
            
            // Thumbnail
            if let thumbnailURL = message.thumbnailURL {
                AsyncImage(url: URL(string: thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                }
                .frame(width: 50, height: 50)
                .clipped()
                .cornerRadius(4)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

struct MessageDetailView: View {
    let message: Message
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(message.content)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle(message.senderUsername)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    InboxView(tabCoordinator: TabCoordinator())
        .preferredColorScheme(.dark)
}
