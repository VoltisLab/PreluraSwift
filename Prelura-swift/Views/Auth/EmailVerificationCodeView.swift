import SwiftUI

/// Shown when login fails with "verify your email": enter 4-digit code from email, then verify and log in. After success, caller should show onboarding and feed.
/// Optional email: when provided (e.g. from signup), "Didn't get the code?" calls resend API; otherwise user can enter email to request a new code.
struct EmailVerificationCodeView: View {
    let username: String
    let password: String
    /// Email for resend. When nil, user can enter their email in the optional field to request a new code.
    var emailForResend: String? = nil
    var onDismiss: () -> Void
    var onVerifiedAndLoggedIn: () -> Void

    @EnvironmentObject var authService: AuthService
    /// Single source of truth for the 4-character code (avoids sync issues and spurious clears).
    @State private var codeString: String = ""
    @State private var isVerifying: Bool = false
    @State private var isResending: Bool = false
    @State private var resendMessage: String?
    @State private var errorMessage: String?
    /// User-entered email for resend when emailForResend was not provided (e.g. from login).
    @State private var resendEmailInput: String = ""
    @FocusState private var focusedIndex: Int?

    private let codeLength = 4
    private let boxSize: CGFloat = 56
    private let boxCornerRadius: CGFloat = 16

    /// Code string sent to API (digits + letters, letters always uppercase).
    private var codeTrimmed: String {
        String(codeString.prefix(codeLength)).uppercased()
    }
    private var canSubmit: Bool {
        codeTrimmed.count == codeLength
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    Text(L10n.string("Verify your email"))
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text("Enter the 4-digit code we sent to your email.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // 4 separate digit fields with auto-advance
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(0..<codeLength, id: \.self) { index in
                            digitField(index: index)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)

                    if let err = errorMessage {
                        Text(err)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.error)
                            .padding(.horizontal)
                    }
                    if let msg = resendMessage {
                        Text(msg)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryText)
                            .padding(.horizontal)
                    }

                    // Email for resend: use provided email or let user enter (e.g. when coming from login)
                    if emailForResend == nil {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Email (for resend)")
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                            TextField("Enter the email linked to your account", text: $resendEmailInput)
                                .textFieldStyle(PlainTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.secondaryBackground)
                                .cornerRadius(12)
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.sm)
                    }

                    Button("Didn't get the code?") {
                        resendCode()
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.primaryColor)
                    .padding(.top, Theme.Spacing.sm)
                    .disabled(isResending)
                }
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, 120)
            }
            .background(Theme.Colors.background)

            PrimaryButtonBar {
                PrimaryGlassButton("Verify", isLoading: isVerifying, action: verifyAndLogin)
                    .disabled(!canSubmit)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onDismiss()
                }
                .foregroundColor(Theme.primaryColor)
            }
        }
        .onAppear {
            focusedIndex = 0
        }
    }

    /// Allowed: 0-9 and A-Z. Lowercase letters are converted to uppercase.
    private static func normalizedCodeCharacter(_ c: Character) -> Character? {
        if c.isNumber { return c }
        if c.isLetter { return Character(c.uppercased()) }
        return nil
    }

    private func digitField(index: Int) -> some View {
        TextField("", text: Binding(
            get: {
                guard index < codeString.count else { return "" }
                let i = codeString.index(codeString.startIndex, offsetBy: index)
                return String(codeString[i])
            },
            set: { newValue in
                let uppercased = newValue.uppercased()
                let allowed = uppercased.compactMap { Self.normalizedCodeCharacter($0) }
                var newCode = codeString
                if allowed.count > 1 {
                    // Paste: replace with up to 4 allowed characters
                    newCode = String(allowed.prefix(codeLength)).uppercased()
                    codeString = newCode
                    DispatchQueue.main.async {
                        if newCode.count >= codeLength {
                            focusedIndex = nil
                        } else {
                            focusedIndex = min(newCode.count, codeLength - 1)
                        }
                    }
                    return
                }
                let newChar = allowed.first.map { String($0) }
                if let ch = newChar {
                    // Insert or replace at index
                    if index < newCode.count {
                        let i = newCode.index(newCode.startIndex, offsetBy: index)
                        newCode.replaceSubrange(i...i, with: ch)
                    } else {
                        newCode.append(ch)
                    }
                    newCode = String(newCode.prefix(codeLength))
                    codeString = newCode
                    DispatchQueue.main.async {
                        if index < codeLength - 1 && newCode.count > index + 1 {
                            focusedIndex = index + 1
                        } else if newCode.count >= codeLength {
                            focusedIndex = nil
                        }
                    }
                } else {
                    // Backspace: remove character at index (only when user explicitly cleared)
                    if index < newCode.count {
                        let i = newCode.index(newCode.startIndex, offsetBy: index)
                        newCode.remove(at: i)
                        codeString = newCode
                        DispatchQueue.main.async {
                            let next = min(index, newCode.count)
                            focusedIndex = next >= 0 ? next : 0
                        }
                    }
                }
            }
        ))
        .keyboardType(.numberPad)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
        .font(.system(size: 24, weight: .semibold, design: .rounded))
        .multilineTextAlignment(.center)
        .foregroundColor(Theme.Colors.primaryText)
        .focused($focusedIndex, equals: index)
        .frame(width: boxSize, height: boxSize)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: boxCornerRadius))
    }

    private func verifyAndLogin() {
        guard canSubmit else { return }
        errorMessage = nil
        resendMessage = nil
        isVerifying = true
        Task {
            do {
                let success = try await authService.verifyAccount(code: codeTrimmed)
                guard success else {
                    await MainActor.run {
                        errorMessage = "Invalid or expired code."
                        isVerifying = false
                    }
                    return
                }
                _ = try await authService.login(username: username, password: password)
                await MainActor.run {
                    isVerifying = false
                    onVerifiedAndLoggedIn()
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    errorMessage = verificationErrorMessage(from: error)
                }
            }
        }
    }

    /// Map backend/GraphQL errors to user-facing messages: invalid vs expired.
    private func verificationErrorMessage(from error: Error) -> String {
        let msg = error.localizedDescription
        // Backend: OTP_CODE_EXPIRED = "Verification code expired." / WRONG_OTP_CODE = "Invalid verification code."
        if msg.localizedCaseInsensitiveContains("expired") {
            return "This code has expired. Tap \"Didn't get the code?\" to request a new one."
        }
        if msg.localizedCaseInsensitiveContains("invalid") && (msg.localizedCaseInsensitiveContains("code") || msg.localizedCaseInsensitiveContains("verification")) {
            return "Invalid verification code. Please check and try again."
        }
        return msg
    }

    /// Resend: use emailForResend if provided, else resendEmailInput. Calls API when we have a valid email.
    private func resendCode() {
        errorMessage = nil
        resendMessage = nil
        let email = (emailForResend?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (resendEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)).nilIfEmpty
        guard let emailToUse = email else {
            resendMessage = "Enter your email above to resend the code."
            return
        }
        guard emailToUse.contains("@"), emailToUse.contains(".") else {
            resendMessage = "Enter a valid email address to resend the code."
            return
        }
        isResending = true
        Task {
            do {
                _ = try await authService.resendActivationEmail(email: emailToUse)
                await MainActor.run {
                    isResending = false
                    resendMessage = "Verification code sent. Check your email."
                }
            } catch {
                await MainActor.run {
                    isResending = false
                    resendMessage = error.localizedDescription
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
