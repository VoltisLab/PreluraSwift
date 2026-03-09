import SwiftUI

/// List of Contacts (from Flutter list_of_contacts). Placeholder until contacts access is wired.
struct ListOfContactsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Text("Access your contacts to invite friends to Prelura.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(Theme.Spacing.lg)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
