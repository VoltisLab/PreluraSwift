import SwiftUI

/// Account Settings (from Flutter account_setting_view). Form: full name, email, phone, DOB, gender, bio.
/// Uses same API as Flutter: ViewMe for load, updateProfile + changeEmail for save. No backend changes.
struct AccountSettingsView: View {
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var dateOfBirth: Date?
    @State private var dateOfBirthText: String = ""
    @State private var gender: String = ""
    @State private var bio: String = ""

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDatePicker = false
    @State private var showGenderPicker = false
    @State private var showSuccess = false
    @FocusState private var focusedField: Field?
    @State private var loadedUser: User?

    private let userService = UserService()

    private enum Field { case fullName, email, phone, bio }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SettingsTextField(
                    placeholder: "Full name",
                    text: $fullName,
                    textContentType: .name
                )
                .focused($focusedField, equals: .fullName)

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
                    placeholder: "Gender",
                    text: $gender,
                    isEnabled: false,
                    onTap: { showGenderPicker = true }
                )

                Button("AutoFill") {
                    focusedField = .fullName
                }
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(30)

                SettingsTextEditor(placeholder: "Bio", text: $bio, minHeight: 100)
                    .focused($focusedField, equals: .bio)

                if let err = errorMessage {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.red)
                }

                PrimaryGlassButton("Save", isLoading: isSaving, action: save)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: loadUser)
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
        .sheet(isPresented: $showGenderPicker) { genderPickerSheet }
        .alert("Saved", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your account settings have been updated.")
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
            .navigationTitle("Date of birth")
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
            .navigationTitle("Gender")
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
                    fullName = user.displayName.isEmpty ? (user.email ?? "") : user.displayName
                    email = user.email ?? ""
                    phone = user.phoneDisplay ?? ""
                    dateOfBirth = user.dateOfBirth
                    dateOfBirthText = user.dateOfBirth.map { formatDOB($0) } ?? ""
                    gender = user.gender ?? ""
                    bio = user.bio ?? ""
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

    private func save() {
        guard let user = loadedUser else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let modifiedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines) != (user.email ?? "")
                if modifiedEmail {
                    try await userService.changeEmail(email.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                let displayNameToSend = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
                let genderToSend = gender.isEmpty ? nil : gender
                let phoneParsed = parsePhone(phone.trimmingCharacters(in: .whitespacesAndNewlines), existing: user.phoneDisplay)
                try await userService.updateProfile(
                    displayName: displayNameToSend.isEmpty ? nil : displayNameToSend,
                    gender: genderToSend,
                    dob: dateOfBirth,
                    phoneNumber: phoneParsed,
                    bio: bio.isEmpty ? nil : bio
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
