import SwiftUI

/// Staff-only: list signed-in accounts, switch session, log out one or all, add another account.
struct StaffAccountsView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var busyUsername: String?
    @State private var errorMessage: String?
    @State private var showAddAccount = false
    @State private var showLogoutAllConfirm = false

    var body: some View {
        List {
            Section {
                if let u = authService.username {
                    LabeledContent(L10n.string("Active account"), value: u)
                }
            } header: {
                Text(L10n.string("Signed in as"))
            }

            Section {
                ForEach(authService.staffSessionsForUI, id: \.username) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.username)
                                .foregroundColor(Theme.Colors.primaryText)
                            if row.isActive {
                                Text(L10n.string("Current"))
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                        }
                        Spacer()
                        if !row.isActive {
                            Button(L10n.string("Switch")) {
                                Task { await switchTo(row.username) }
                            }
                            .disabled(busyUsername != nil)
                        }
                        Button(L10n.string("Log out"), role: .destructive) {
                            Task { await logoutOne(row.username) }
                        }
                        .disabled(busyUsername != nil)
                    }
                }
            } header: {
                Text(L10n.string("Accounts"))
            }

            Section {
                Button {
                    showAddAccount = true
                } label: {
                    Label(L10n.string("Add account"), systemImage: "person.badge.plus")
                }
                Button(role: .destructive) {
                    showLogoutAllConfirm = true
                } label: {
                    Label(L10n.string("Log out all accounts"), systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle(L10n.string("Accounts"))
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showAddAccount) {
            NavigationStack {
                LoginView(
                    staffAddAccountMode: true,
                    onStaffAccountAdded: { showAddAccount = false }
                )
                .environmentObject(authService)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.string("Cancel")) {
                            showAddAccount = false
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .alert(L10n.string("Could not switch account"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.string("OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            L10n.string("Log out all accounts on this device?"),
            isPresented: $showLogoutAllConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Log out all"), role: .destructive) {
                Task { await authService.logoutAllStaffSessions() }
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        }
    }

    private func switchTo(_ name: String) async {
        busyUsername = name
        defer { busyUsername = nil }
        do {
            try await authService.switchToStaffAccount(username: name)
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func logoutOne(_ name: String) async {
        busyUsername = name
        defer { busyUsername = nil }
        await authService.logoutStaffAccount(username: name)
    }
}
