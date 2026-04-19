import PhotosUI
import SwiftUI

/// Profile details: username, bio, location. Labeled fields above each control (same pattern as Shipping Address).
/// Load from UserService.getUser(); save via UserService.updateProfile(bio:username:location:).
struct ProfileSettingsView: View {
    private static let profilePhotoSize: CGFloat = 88

    @EnvironmentObject private var authService: AuthService
    @StateObject private var photoVM = ProfileViewModel()

    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""

    private let bioMaxLength = 100

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @FocusState private var focusedField: Field?
    @State private var loadedUser: User?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showMacProfilePhotoImporter: Bool = false
    @State private var profileImage: UIImage?
    private let userService = UserService()

    private enum Field { case username, bio, location }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    profilePhotoHeader

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(L10n.string("Username"))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        SettingsTextField(
                            placeholder: L10n.string("Public username hint"),
                            text: $username,
                            textContentType: .username
                        )
                        .focused($focusedField, equals: .username)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(L10n.string("Bio"))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        ZStack(alignment: .bottomTrailing) {
                            SettingsTextEditor(
                                placeholder: L10n.string("Bio hint"),
                                text: $bio,
                                minHeight: 100,
                                maxLength: bioMaxLength
                            )
                            .focused($focusedField, equals: .bio)
                            Text("\(bio.count)/\(bioMaxLength)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .padding(Theme.Spacing.sm)
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(L10n.string("Location"))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        LocationSuggestionField(
                            placeholder: L10n.string("Location hint"),
                            text: $location,
                            isFocused: focusedField == .location
                        )
                        .focused($focusedField, equals: .location)
                    }

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
                PrimaryGlassButton(L10n.string("Save"), isLoading: isSaving, action: save)
            }
        }
        .navigationTitle(L10n.string("Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: ShareProfileLinkView().environmentObject(authService)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .accessibilityLabel(L10n.string("Share profile"))
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            userService.updateAuthToken(authService.authToken)
            photoVM.updateAuthToken(authService.authToken)
            loadUser()
        }
        .onChange(of: photoVM.isUploadingProfilePhoto) { _, isUploading in
            if !isUploading, photoVM.profilePhotoUploadError == nil {
                refreshLoadedUserAfterPhoto()
            }
        }
        .alert(L10n.string("Saved"), isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L10n.string("Your profile has been updated."))
        }
        .alert(L10n.string("Profile photo"), isPresented: Binding(
            get: { photoVM.profilePhotoUploadError != nil },
            set: { if !$0 { photoVM.profilePhotoUploadError = nil } }
        )) {
            Button("OK") { photoVM.profilePhotoUploadError = nil }
        } message: {
            if let err = photoVM.profilePhotoUploadError {
                Text(err)
            }
        }
        .macOnlyImageFileImporter(
            isPresented: $showMacProfilePhotoImporter,
            allowsMultipleSelection: false,
            maxImageCount: 1
        ) { images in
            guard let image = images.first else { return }
            profileImage = image
            photoVM.uploadProfileImage(image, authToken: authService.authToken)
        }
    }

    private var profilePhotoHeader: some View {
        HStack {
            Spacer(minLength: 0)
            Group {
                if IOSAppOnMacImageImport.isIOSAppOnMac {
                    Button {
                        showMacProfilePhotoImporter = true
                    } label: {
                        profilePhotoHeaderLabel
                    }
                    .buttonStyle(.plain)
                } else {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        profilePhotoHeaderLabel
                    }
                    .buttonStyle(.plain)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    guard let newItem,
                          let data = try? await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await MainActor.run {
                        profileImage = image
                        photoVM.uploadProfileImage(image, authToken: authService.authToken)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var profilePhotoHeaderLabel: some View {
        ZStack {
            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
                    .clipShape(Circle())
            } else if let urlString = loadedUser?.avatarURL, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Theme.Colors.secondaryBackground)
                            .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
                            .overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
                            .clipShape(Circle())
                    case .failure:
                        profilePhotoPlaceholder
                    @unknown default:
                        profilePhotoPlaceholder
                    }
                }
                .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
                .clipShape(Circle())
            } else {
                profilePhotoPlaceholder
            }
        }
        .overlay {
            if photoVM.isUploadingProfilePhoto {
                ProgressView()
                    .tint(.white)
                    .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
        }
        .overlay(
            Circle()
                .stroke(Theme.Colors.profileRingBorder, lineWidth: 2.5)
                .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
        )
    }

    private var profilePhotoPlaceholder: some View {
        Circle()
            .fill(Theme.Colors.secondaryBackground)
            .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Colors.tertiaryText)
            )
    }

    /// Refreshes `loadedUser` from the server without overwriting unsaved edits to username / bio / location fields.
    private func refreshLoadedUserAfterPhoto() {
        Task {
            do {
                let user = try await userService.getUser()
                await MainActor.run {
                    loadedUser = user
                    profileImage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = L10n.userFacingError(error)
                }
            }
        }
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
                    username = user.username
                    bio = String((user.bio ?? "").prefix(bioMaxLength))
                    location = user.location ?? ""
                    profileImage = nil
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = L10n.userFacingError(error)
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
                let usernameTrimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
                let bioTrimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
                let bioSafe = ProfanityFilter.sanitize(bioTrimmed)
                let locationTrimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
                if ProfanityFilter.maskingWouldChange(bioTrimmed) {
                    userService.updateAuthToken(UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                    _ = try? await userService.recordProfanityUsage(
                        channel: "profile_bio",
                        relatedConversationId: nil,
                        sanitizedSnippet: bioSafe
                    )
                }
                // Only send username if it changed (backend rejects "already taken" when sending current username).
                let usernameToSend: String? = {
                    let new = usernameTrimmed.isEmpty ? nil : usernameTrimmed.lowercased()
                    guard let n = new else { return nil }
                    if n == user.username.lowercased() { return nil }
                    return n
                }()
                try await userService.updateProfile(
                    bio: bioSafe.isEmpty ? nil : String(bioSafe.prefix(bioMaxLength)),
                    username: usernameToSend,
                    location: locationTrimmed.isEmpty ? nil : locationTrimmed
                )
                await MainActor.run {
                    isSaving = false
                    showSuccess = true
                    NotificationCenter.default.post(name: .wearhouseUserProfileDidUpdate, object: nil)
                }
            } catch {
                await MainActor.run {
                    errorMessage = L10n.userFacingError(error)
                    isSaving = false
                }
            }
        }
    }
}
