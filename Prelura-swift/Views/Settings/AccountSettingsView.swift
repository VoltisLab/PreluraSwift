import SwiftUI

/// Account Settings (from Flutter account_setting_view). Form: first name, last name, email, phone, DOB, gender (no profile-only fields).
/// Uses same API as Flutter: ViewMe for load, updateProfile + changeEmail for save. Bio/username/location are in Profile settings.
struct AccountSettingsView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var dateOfBirth: Date?
    @State private var dateOfBirthText: String = ""
    @State private var gender: String = ""

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDatePicker = false
    @State private var showGenderPicker = false
    @State private var showSuccess = false
    @FocusState private var focusedField: Field?
    @State private var loadedUser: User?
    /// When non-nil, we've requested an email change; show verification sheet so user enters the new code.
    @State private var pendingEmailVerification: PendingEmail?
    @EnvironmentObject private var authService: AuthService

    private let userService = UserService()

    private enum Field { case firstName, lastName, email, phone }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SettingsTextField(
                        placeholder: L10n.string("First name"),
                        text: $firstName,
                        textContentType: .givenName
                    )
                    .focused($focusedField, equals: .firstName)

                    SettingsTextField(
                        placeholder: L10n.string("Last name"),
                        text: $lastName,
                        textContentType: .familyName
                    )
                    .focused($focusedField, equals: .lastName)

                    SettingsTextField(
                        placeholder: "Email",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    .focused($focusedField, equals: .email)

                    SettingsTextField(
                        placeholder: "Phone",
                        text: $phone,
                        keyboardType: .phonePad,
                        textContentType: .telephoneNumber
                    )
                    .focused($focusedField, equals: .phone)

                    SettingsTextField(
                        placeholder: "Date of birth",
                        text: $dateOfBirthText,
                        isEnabled: false,
                        onTap: { showDatePicker = true }
                    )

                    SettingsTextField(
                        placeholder: L10n.string("Gender"),
                        text: $gender,
                        isEnabled: false,
                        onTap: { showGenderPicker = true }
                    )

                    if let err = errorMessage {
                        Text(err)
                            .font(Theme.Typography.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.lg)
                .padding(.bottom, 100)
            }
            .background(Theme.Colors.background)

            PrimaryButtonBar {
                PrimaryGlassButton("Save", isLoading: isSaving, action: save)
            }
        }
        .navigationTitle(L10n.string("Account"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: loadUser)
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
        .sheet(isPresented: $showGenderPicker) { genderPickerSheet }
        .sheet(item: $pendingEmailVerification) { wrapper in
            EmailChangeVerificationView(
                newEmail: wrapper.email,
                onDismiss: { pendingEmailVerification = nil },
                onVerified: {
                    pendingEmailVerification = nil
                    showSuccess = true
                    loadUser()
                }
            )
            .environmentObject(authService)
        }
        .alert(L10n.string("Saved"), isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L10n.string("Your account settings have been updated."))
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("Date of birth", selection: Binding(
                get: { dateOfBirth ?? Date() },
                set: { dateOfBirth = $0; dateOfBirthText = formatDOB($0) }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle(L10n.string("Date of birth"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                        .foregroundColor(Theme.primaryColor)
                }
            }
        }
    }

    private var genderPickerSheet: some View {
        NavigationStack {
            List(["Male", "Female"], id: \.self) { option in
                Button(option) {
                    gender = option
                    showGenderPicker = false
                }
            }
            .navigationTitle(L10n.string("Gender"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatDOB(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy"
        return f.string(from: date)
    }

    private func loadUser() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let user = try await userService.getUser()
                await MainActor.run {
                    loadedUser = user
                    let (first, last) = Self.splitDisplayName(user.displayName)
                    firstName = first
                    lastName = last
                    email = user.email ?? ""
                    phone = user.phoneDisplay ?? ""
                    dateOfBirth = user.dateOfBirth
                    dateOfBirthText = user.dateOfBirth.map { formatDOB($0) } ?? ""
                    gender = user.gender ?? ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    /// Split "First Last" into (first, last); single word becomes (word, "").
    private static func splitDisplayName(_ displayName: String) -> (String, String) {
        let parts = displayName.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count >= 2 {
            return (String(parts[0]), String(parts[1]))
        }
        if parts.count == 1 {
            return (String(parts[0]), "")
        }
        return ("", "")
    }

    private func save() {
        guard let user = loadedUser else { return }
        isSaving = true
        errorMessage = nil
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailChanged = emailTrimmed != (user.email ?? "")
        Task {
            do {
                if emailChanged {
                    try await userService.changeEmail(emailTrimmed)
                    await MainActor.run {
                        isSaving = false
                        pendingEmailVerification = PendingEmail(email: emailTrimmed)
                    }
                    return
                }
                let firstTrimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                let lastTrimmed = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                let genderToSend = gender.isEmpty ? nil : gender
                let phoneParsed = parsePhone(phone.trimmingCharacters(in: .whitespacesAndNewlines), existing: user.phoneDisplay)
                let displayNameToSend: String? = {
                    if firstTrimmed.isEmpty && lastTrimmed.isEmpty { return nil }
                    if lastTrimmed.isEmpty { return firstTrimmed }
                    return "\(firstTrimmed) \(lastTrimmed)"
                }()
                try await userService.updateProfile(
                    displayName: displayNameToSend,
                    firstName: firstTrimmed.isEmpty ? nil : firstTrimmed,
                    lastName: lastTrimmed.isEmpty ? nil : lastTrimmed,
                    gender: genderToSend,
                    dob: dateOfBirth,
                    phoneNumber: phoneParsed
                )
                await MainActor.run {
                    isSaving = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    /// Parse "+44 123456789" or "44123456789" into (countryCode, number). Matches Flutter account_setting_view logic.
    private func parsePhone(_ raw: String, existing: String?) -> (countryCode: String, number: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let digits = trimmed.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        if trimmed.hasPrefix("+") {
            // Assume 1–3 digit country code (e.g. 44, 1, 353)
            let codeLen = digits.count <= 3 ? min(2, digits.count) : (digits.hasPrefix("1") ? 1 : 2)
            let code = String(digits.prefix(codeLen))
            let num = String(digits.dropFirst(codeLen))
            return (code.isEmpty ? "44" : code, num)
        }
        return ("44", digits)
    }
}

/// Identifiable wrapper for presenting email-change verification sheet.
private struct PendingEmail: Identifiable {
    let id = UUID()
    let email: String
}
