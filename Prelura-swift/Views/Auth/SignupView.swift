import SwiftUI

struct SignupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var signupVideoURL: URL?
    @State private var email: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                VideoBackgroundView(videoURL: signupVideoURL, overlayOpacity: 0.45)
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        VStack(spacing: Theme.Spacing.sm) {
                            Text(L10n.string("Create Account"))
                                .font(Theme.Typography.title)
                                .foregroundColor(Theme.Colors.authOverVideoText)
                            Text(L10n.string("Join Prelura today"))
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.authOverVideoText)
                        }
                        .padding(.top, Theme.Spacing.lg)

                        VStack(spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("Email")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.authOverVideoText)
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.secondaryBackground)
                                    .cornerRadius(30)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(L10n.string("First Name"))
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.authOverVideoText)
                                TextField("Enter your first name", text: $firstName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.secondaryBackground)
                                    .cornerRadius(30)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("Last Name")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.authOverVideoText)
                                TextField("Enter your last name", text: $lastName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.secondaryBackground)
                                    .cornerRadius(30)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(L10n.string("Username"))
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.authOverVideoText)
                                TextField("Choose a username", text: $username)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .autocapitalization(.none)
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.secondaryBackground)
                                    .cornerRadius(30)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("Password")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.authOverVideoText)
                                HStack(spacing: Theme.Spacing.sm) {
                                    Group {
                                        if showPassword {
                                            TextField("Enter your password", text: $password)
                                        } else {
                                            SecureField("Enter your password", text: $password)
                                        }
                                    }
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(Theme.Colors.primaryText)
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(Theme.Colors.authOverVideoText)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.secondaryBackground)
                                .cornerRadius(30)
                            }
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(L10n.string("Confirm Password"))
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.authOverVideoText)
                                HStack(spacing: Theme.Spacing.sm) {
                                    Group {
                                        if showConfirmPassword {
                                            TextField("Confirm your password", text: $confirmPassword)
                                        } else {
                                            SecureField("Confirm your password", text: $confirmPassword)
                                        }
                                    }
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(Theme.Colors.primaryText)
                                    Button(action: { showConfirmPassword.toggle() }) {
                                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(Theme.Colors.authOverVideoText)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.secondaryBackground)
                                .cornerRadius(30)
                            }
                            if let error = errorMessage {
                                Text(error)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, Theme.Spacing.md)
                            }
                            if let success = successMessage {
                                Text(success)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, Theme.Spacing.md)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, 100)
                    }
                    .padding(.vertical, Theme.Spacing.lg)
                }
                .scrollContentBackground(.hidden)

                PrimaryGlassButton(
                    "Sign Up",
                    isEnabled: isFormValid,
                    isLoading: isLoading,
                    action: handleSignup
                )
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                if signupVideoURL == nil {
                    signupVideoURL = AuthVideo.signupVideoURL()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.primaryColor)
                    .buttonStyle(HapticTapButtonStyle())
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !username.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword
    }
    
    private func handleSignup() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                _ = try await authService.register(
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    username: username,
                    password1: password,
                    password2: confirmPassword
                )
                successMessage = "Account created successfully! Please check your email to verify your account."
                isLoading = false
                
                // Dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    SignupView()
        .preferredColorScheme(.dark)
}
