import SwiftUI

/// Admin Actions (from Flutter admin_menu.dart). Shown only when user is staff. Menu list with Delete All Conversations etc.
struct AdminMenuView: View {
    var body: some View {
        List {
            Button(role: .destructive, action: {}) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red)
                    Text(L10n.string("Delete All Conversations"))
                        .foregroundColor(.red)
                }
            }
            .listRowBackground(Theme.Colors.background)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Admin Actions"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
