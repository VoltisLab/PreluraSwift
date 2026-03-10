import SwiftUI

/// Pause (archive) account: password. Matches Flutter PauseAccount; backend archiveAccount.
struct PauseAccountView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirm = false
    @State private var showSuccess = false

    private let userService = UserService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Pausing your account will hide your profile and listings. You can reactivate later by logging in.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                if let err = errorMessage {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Password")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(
                        placeholder: "Enter password",
                        text: $password,
                        isSecure: true
                    )
                }
                Spacer(minLength: Theme.Spacing.xl)
                PrimaryGlassButton(
                    "Pause Account",
                    isEnabled: !password.isEmpty,
                    isLoading: isLoading,
                    action: { showConfirm = true }
                )
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Pause Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("Pause account?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Pause Account") {
                Task { await pauseAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your profile and listings will be hidden until you log in again.")
        }
        .alert("Account paused", isPresented: $showSuccess) {
            Button("OK") {
                Task { try? await authService.logout() }
            }
        } message: {
            Text("Your account has been paused. You will be signed out.")
        }
    }

    private func pauseAccount() async {
        guard !password.isEmpty else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await userService.archiveAccount(password: password)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
