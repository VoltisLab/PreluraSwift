import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSignup: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.Spacing.lg) {
                // Header
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Prelura")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Theme.primaryColor)
                    
                    Text("Welcome back")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                .padding(.top, Theme.Spacing.xl)
                
                // Form
                VStack(spacing: Theme.Spacing.md) {
                    // Username field
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Username")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        
                        TextField("Enter your username", text: $username)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .cornerRadius(16)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Password")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .cornerRadius(16)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.Typography.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, Theme.Spacing.md)
                    }
                    
                    // Login button
                    PrimaryGlassButton(
                        "Login",
                        isEnabled: !username.isEmpty && !password.isEmpty,
                        isLoading: isLoading,
                        action: handleLogin
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                
                Spacer()
                
                // Signup link
                HStack {
                    Text("Don't have an account?")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Button(action: { showSignup = true }) {
                        Text("Sign up")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.primaryColor)
                    }
                }
                .padding(.bottom, Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignup) {
                SignupView()
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
