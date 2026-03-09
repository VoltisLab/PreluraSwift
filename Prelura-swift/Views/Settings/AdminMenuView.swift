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
                    Text("Delete All Conversations")
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Admin Actions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
