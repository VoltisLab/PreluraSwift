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
                TextField("Location", text: $location)
                TextField("Name", text: $name)
                TextField("Username", text: $username)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
            }
            Section(header: Text("Bio")) {
                TextEditor(text: $bio)
                    .frame(minHeight: 80)
            }
            Section {
                Button("Save") {}
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Theme.primaryColor)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Profile details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
