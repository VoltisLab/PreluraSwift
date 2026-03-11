import SwiftUI

/// Security & Privacy (from Flutter security_menu.dart). Menu list: Blocklist, Reset Password, Delete Account, Pause Account.
struct SecurityMenuView: View {
    var body: some View {
        List {
            NavigationLink(destination: BlocklistView()) {
                securityRow("Blocklist", icon: "person.slash")
            }
            .listRowBackground(Theme.Colors.background)
            NavigationLink(destination: ResetPasswordView()) {
                securityRow("Reset Password", icon: "key")
            }
            .listRowBackground(Theme.Colors.background)
            NavigationLink(destination: DeleteAccountView()) {
                securityRow("Delete Account", icon: "trash")
            }
            .listRowBackground(Theme.Colors.background)
            NavigationLink(destination: PauseAccountView()) {
                securityRow("Pause Account", icon: "pause.circle")
            }
            .listRowBackground(Theme.Colors.background)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Security & Privacy"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func securityRow(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.Colors.secondaryText)
            Text(title)
                .foregroundColor(Theme.Colors.primaryText)
        }
    }
}
