import SwiftUI

/// Set new password with OTP/code from email (Flutter NewPasswordScreen).
struct NewPasswordView: View {
    let email: String

    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var success = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Enter the 6-digit code we sent to \(email) and choose a new password.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Code")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        TextField("000000", text: $code)
                            .keyboardType(.numberPad)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .cornerRadius(16)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("New password")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        SecureField("At least 8 characters", text: $newPassword)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .cornerRadius(16)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Confirm password")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        SecureField("Confirm new password", text: $confirmPassword)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .cornerRadius(16)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    if let err = errorMessage {
                        Text(err)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, 100)
            }
            .background(Theme.Colors.background)

            PrimaryButtonBar {
                PrimaryGlassButton("Set new password", isLoading: isLoading, action: submit)
                    .disabled(!canSubmit)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("New Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Password updated", isPresented: $success) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("You can now log in with your new password.")
        }
    }

    private var canSubmit: Bool {
        code.count == 6 && newPassword.count >= 8 && newPassword == confirmPassword
    }

    private func submit() {
        guard canSubmit else { return }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await authService.resetPasswordWithCode(email: email, code: code, newPassword: newPassword)
                await MainActor.run { success = true }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isLoading = false }
        }
    }
}

#Preview {
    NavigationStack {
        NewPasswordView(email: "user@example.com")
            .environmentObject(AuthService())
    }
}
