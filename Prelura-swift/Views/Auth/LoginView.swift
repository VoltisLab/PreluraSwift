import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSignup: Bool = false
    @State private var showForgotPassword: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Header
                        VStack(spacing: Theme.Spacing.sm) {
                            Text("Prelura")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(Theme.primaryColor)
                            Text(L10n.string("Welcome back"))
                                .font(Theme.Typography.title2)
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                        .padding(.top, Theme.Spacing.xl)

                        // Form
                        VStack(spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(L10n.string("Username"))
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                TextField(L10n.string("Enter your username"), text: $username)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.secondaryBackground)
                                    .cornerRadius(16)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(L10n.string("Password"))
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                SecureField(L10n.string("Enter your password"), text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.secondaryBackground)
                                    .cornerRadius(16)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            if let error = errorMessage {
                                Text(error)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, Theme.Spacing.md)
                            }
                            Button(L10n.string("Forgot password?")) {
                                showForgotPassword = true
                            }
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.primaryColor)
                            .buttonStyle(HapticTapButtonStyle())
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        HStack {
                            Text(L10n.string("Don't have an account?"))
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                            Button(action: { showSignup = true }) {
                                Text(L10n.string("Sign up"))
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.primaryColor)
                            }
                            .buttonStyle(HapticTapButtonStyle())
                        }
                        .padding(.bottom, 100)
                    }
                }

                PrimaryButtonBar {
                    PrimaryGlassButton(
                        L10n.string("Login"),
                        isEnabled: !username.isEmpty && !password.isEmpty,
                        isLoading: isLoading,
                        action: handleLogin
                    )
                }
            }
            .background(Theme.Colors.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignup) {
                SignupView()
            }
            .sheet(isPresented: $showForgotPassword) {
                NavigationStack {
                    ForgotPasswordView()
                        .environmentObject(authService)
                }
            }
        }
    }
    
    private func handleLogin() {
        guard !username.isEmpty, !password.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await authService.login(username: username, password: password)
                // Login successful - navigation will be handled by app state
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LoginView()
        .preferredColorScheme(.dark)
}
