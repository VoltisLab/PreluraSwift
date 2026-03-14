import SwiftUI

/// Shown when login fails with "verify your email": enter 4-digit code from email, then verify and log in. After success, caller should show onboarding and feed.
/// No user-editable email field (security: user cannot enter another address). Four separate digit boxes with auto-advance.
struct EmailVerificationCodeView: View {
    let username: String
    let password: String
    var onDismiss: () -> Void
    var onVerifiedAndLoggedIn: () -> Void

    @EnvironmentObject var authService: AuthService
    @State private var digits: [String] = ["", "", "", ""]
    @State private var isVerifying: Bool = false
    @State private var isResending: Bool = false
    @State private var resendMessage: String?
    @State private var errorMessage: String?
    @FocusState private var focusedIndex: Int?

    private let codeLength = 4
    private let boxSize: CGFloat = 56
    private let boxCornerRadius: CGFloat = 16

    /// Code string sent to API (digits + letters, letters always uppercase).
    private var codeTrimmed: String {
        digits.joined()
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

    /// Allowed: 0-9 and A-Z. Lowercase letters are converted to uppercase (small letters not allowed).
    private static func normalizedCodeCharacter(_ c: Character) -> Character? {
        if c.isNumber { return c }
        if c.isLetter { return Character(c.uppercased()) }
        return nil
    }

    private func digitField(index: Int) -> some View {
        TextField("", text: Binding(
            get: { digits[index] },
            set: { newValue in
                let uppercased = newValue.uppercased()
                let allowed = uppercased.compactMap { Self.normalizedCodeCharacter($0) }
                if allowed.count > 1 {
                    let chars = Array(allowed).prefix(codeLength)
                    for i in 0..<min(chars.count, codeLength) {
                        digits[i] = String(chars[i])
                    }
                    DispatchQueue.main.async {
                        if chars.count >= codeLength {
                            focusedIndex = nil
                        } else {
                            focusedIndex = min(chars.count, codeLength - 1)
                        }
                    }
                } else {
                    let newChar = allowed.first.map { String($0) } ?? ""
                    digits[index] = newChar
                    // Defer focus change so the TextField commits the character before we move focus (avoids "can't type" when field gets cleared on focus loss)
                    DispatchQueue.main.async {
                        if !newChar.isEmpty && index < codeLength - 1 {
                            focusedIndex = index + 1
                        } else if newChar.isEmpty && index > 0 {
                            focusedIndex = index - 1
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
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Resend does not accept user-provided email (security). We only have username; show guidance.
    private func resendCode() {
        errorMessage = nil
        resendMessage = nil
        isResending = true
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run {
                isResending = false
                resendMessage = "Check your email inbox and spam folder. The code was sent to the email linked to your account."
            }
        }
    }
}
