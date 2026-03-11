import SwiftUI

/// Profile details (from Flutter profile_setting_view). Form: location, name, username, email, bio.
struct ProfileSettingsView: View {
    @State private var location: String = ""
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var bio: String = ""

    var body: some View {
        Form {
            Section {
                SettingsTextField(placeholder: "Location", text: $location)
                SettingsTextField(placeholder: "Name", text: $name)
                SettingsTextField(placeholder: "Username", text: $username)
                SettingsTextField(placeholder: "Email", text: $email)
                    .keyboardType(.emailAddress)
            }
            Section(header: Text(L10n.string("Bio"))) {
                SettingsTextEditor(placeholder: "Bio", text: $bio)
                    .frame(minHeight: 80)
            }
            Section {
                Button("Save") {}
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Theme.primaryColor)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Profile details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
