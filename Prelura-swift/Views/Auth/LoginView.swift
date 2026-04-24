import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    /// When true (staff only), saves the current session and clears fields so another account can sign in.
    var staffAddAccountMode: Bool = false
    /// Called after a successful login in `staffAddAccountMode` (e.g. dismiss the add-account sheet).
    var onStaffAccountAdded: (() -> Void)? = nil
    /// Demo credentials for testing; pre-filled so you don't have to type each time.
    @State private var username: String = "Testuser"
    @State private var password: String = "Password123!!!"
    @State private var showPassword: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSignup: Bool = false
    /// Prefill for `SignupView` when routing from Sign in with Apple (no Wearhouse account yet).
    @State private var appleSignupPrefillEmail: String?
    @State private var appleSignupPrefillFirstName: String?
    @State private var appleSignupPrefillLastName: String?
    @State private var showForgotPassword: Bool = false
    @State private var showEmailVerificationCode: Bool = false
    @State private var loginVideoURL: URL?
    @State private var appleNonceRaw: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VideoBackgroundView(videoURL: loginVideoURL, overlayOpacity: 0.45)
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Header
                        VStack(spacing: Theme.Spacing.sm) {
                            WearhouseWordmarkView(style: .login)
                            Text(staffAddAccountMode ? L10n.string("Add account") : L10n.string("Welcome back"))
                                .font(Theme.Typography.title2)
                                .foregroundColor(Theme.Colors.authOverVideoText)
                        }
                        .padding(.top, Theme.Spacing.xl)

                        // Form
                        VStack(spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(L10n.string("Username"))
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.authOverVideoText)
                                TextField(L10n.string("Enter your username"), text: $username)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .textContentType(.username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, Theme.TextInput.insetHorizontal)
                                    .padding(.vertical, Theme.TextInput.insetVerticalCompact)
                                    .background(Theme.Colors.secondaryBackground)
                                    .cornerRadius(30)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(L10n.string("Password"))
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.authOverVideoText)
                                HStack(spacing: Theme.Spacing.sm) {
                                    Group {
                                        if showPassword {
                                            TextField(L10n.string("Enter your password"), text: $password)
                                        } else {
                                            SecureField(L10n.string("Enter your password"), text: $password)
                                        }
                                    }
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(Theme.Colors.primaryText)
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(Theme.Colors.authOverVideoText)
                                    }
                                    .buttonStyle(PlainTappableButtonStyle())
                                }
                                .padding(.horizontal, Theme.TextInput.insetHorizontal)
                                .padding(.vertical, Theme.TextInput.insetVerticalCompact)
                                .background(Theme.Colors.secondaryBackground)
                                .cornerRadius(30)
                            }
                            if let error = errorMessage {
                                Text(error)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, Theme.Spacing.md)
                                if error.localizedCaseInsensitiveContains("verify") && error.localizedCaseInsensitiveContains("email") {
                                    Button("Enter verification code") {
                                        showEmailVerificationCode = true
                                    }
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.primaryColor)
                                    .padding(.top, Theme.Spacing.xs)
                                }
                            }
                            Button(L10n.string("Forgot password?")) {
                                showForgotPassword = true
                            }
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.primaryColor)
                            .buttonStyle(HapticTapButtonStyle())
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        if !staffAddAccountMode {
                            HStack {
                                Text(L10n.string("Don't have an account?"))
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.authOverVideoText)
                                Button(action: {
                                    appleSignupPrefillEmail = nil
                                    appleSignupPrefillFirstName = nil
                                    appleSignupPrefillLastName = nil
                                    showSignup = true
                                }) {
                                    Text(L10n.string("Sign up"))
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.primaryColor)
                                }
                                .buttonStyle(HapticTapButtonStyle())
                            }
                            .padding(.bottom, 100)
                        } else {
                            Spacer().frame(height: 24)
                        }
                    }
                }

                VStack(spacing: Theme.Spacing.md) {
                    if !staffAddAccountMode {
                        BorderGlassButton(L10n.string("Continue as guest"), action: { authService.continueAsGuest() })
                            .padding(.horizontal, Theme.Spacing.md)

                        SignInWithAppleButton(.signIn) { request in
                            let pair = AppleSignInSupport.makeNoncePair()
                            appleNonceRaw = pair.raw
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = pair.hashed
                        } onCompletion: { result in
                            Task { await handleAppleSignInCompletion(result) }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    PrimaryGlassButton(
                        L10n.string("Login"),
                        isEnabled: !username.isEmpty && !password.isEmpty,
                        isLoading: isLoading,
                        action: handleLogin
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .navigationBarHidden(true)
            .onAppear {
                if loginVideoURL == nil {
                    loginVideoURL = AuthVideo.randomLoginVideoURL()
                }
                if staffAddAccountMode {
                    authService.prepareForAdditionalStaffLogin()
                    username = ""
                    password = ""
                }
            }
            .navigationDestination(isPresented: $showSignup) {
                SignupView(
                    prefilledEmail: appleSignupPrefillEmail,
                    prefilledFirstName: appleSignupPrefillFirstName,
                    prefilledLastName: appleSignupPrefillLastName
                )
                .environmentObject(authService)
                .onDisappear {
                    appleSignupPrefillEmail = nil
                    appleSignupPrefillFirstName = nil
                    appleSignupPrefillLastName = nil
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                NavigationStack {
                    ForgotPasswordView()
                        .environmentObject(authService)
                }
                .scrollContentBackground(.hidden)
                .wearhouseSheetContentColumnIfWide()
            }
            .fullScreenCover(isPresented: $showEmailVerificationCode) {
                NavigationStack {
                    EmailVerificationCodeView(
                        username: username,
                        password: password,
                        onDismiss: { showEmailVerificationCode = false },
                        onVerifiedAndLoggedIn: {
                            showEmailVerificationCode = false
                            authService.shouldShowOnboardingAfterLogin = true
                        }
                    )
                    .environmentObject(authService)
                }
                .wearhouseSheetContentColumnIfWide()
            }
        }
    }
    
    @MainActor
    private func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            errorMessage = L10n.userFacingError(error)
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonceRaw
            else {
                errorMessage = L10n.string("Could not read Apple credentials.")
                return
            }
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                try await authService.loginWithApple(identityToken: token, rawNonce: nonce)
            } catch {
                if case AuthError.appleAccountNotLinkedToWearhouse = error {
                    appleSignupPrefillEmail = credential.email
                    appleSignupPrefillFirstName = credential.fullName?.givenName
                    appleSignupPrefillLastName = credential.fullName?.familyName
                    errorMessage = nil
                    showSignup = true
                } else {
                    errorMessage = L10n.userFacingError(error)
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
                if staffAddAccountMode {
                    onStaffAccountAdded?()
                }
                // Login successful - navigation will be handled by app state
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = L10n.userFacingError(error)
                // Do not auto-open verify screen: user stays on login and can tap "Enter verification code" if needed
            }
        }
    }
}

#Preview {
    LoginView()
        .preferredColorScheme(.dark)
}
