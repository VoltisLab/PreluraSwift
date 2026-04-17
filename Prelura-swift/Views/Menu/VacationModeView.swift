import SwiftUI

/// Holiday Mode — fetch on load, toggle via updateProfile(isVacationMode). Matches Flutter HolidayModeScreen.
struct VacationModeView: View {
    @EnvironmentObject var authService: AuthService
    var initialIsOn: Bool = false

    @State private var isOn: Bool = false
    @State private var isUpdating = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let userService = UserService()

    var body: some View {
        List {
            Section {
                Toggle(isOn: $isOn) {
                    Text(L10n.string("Holiday Mode"))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                .tint(Theme.primaryColor)
                .disabled(isUpdating)
                .onChange(of: isOn) { _, newValue in
                    Task { await updateVacationMode(newValue) }
                }
            }
            if let msg = errorMessage {
                Section {
                    Text(msg)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                }
            }
            Section {
                Text(L10n.string("Note: Turning on Holiday Mode will hide your items from all catalogues"))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Holiday Mode"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await fetch() }
        .task { await fetch() }
        .onAppear {
            userService.updateAuthToken(authService.authToken)
            isOn = initialIsOn
        }
    }

    private func fetch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await userService.getUser()
            await MainActor.run { isOn = user.isVacationMode }
        } catch {
            await MainActor.run {
                errorMessage = L10n.userFacingError(error)
                isOn = initialIsOn
            }
        }
    }

    private func updateVacationMode(_ value: Bool) async {
        await MainActor.run { userService.updateAuthToken(authService.authToken) }
        await MainActor.run { isUpdating = true; errorMessage = nil }
        do {
            try await userService.updateProfile(isVacationMode: value)
            // Refetch so UI and profile menu stay in sync with server
            let user = try await userService.getUser()
            await MainActor.run {
                isOn = user.isVacationMode
                isUpdating = false
                NotificationCenter.default.post(name: .wearhouseUserProfileDidUpdate, object: nil)
            }
        } catch {
            await MainActor.run {
                isOn = !value
                errorMessage = L10n.userFacingError(error)
                isUpdating = false
            }
        }
    }
}
