import SwiftUI

/// Staff-only sheet: moderation actions for another user’s account (dashboard GraphQL mutations).
struct StaffUserActionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @State private var target: User
    @StateObject private var adminService = AdminService(client: GraphQLClient())

    @State private var busy = false
    @State private var errorAlert: String?
    @State private var confirmRemoveStaff = false
    @State private var confirmGrantStaff = false

    var onProfileChanged: () async -> Void

    init(user: User, onProfileChanged: @escaping () async -> Void) {
        _target = State(initialValue: user)
        self.onProfileChanged = onProfileChanged
    }

    private var tierLabel: String {
        let t = target.profileTier.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch t {
        case "PRO": return L10n.string("This account is Pro.")
        case "ELITE": return L10n.string("This account is Elite.")
        default: return L10n.string("This account is on the standard tier.")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                reportSection
                moderationCard(
                    title: L10n.string("Platform verified"),
                    status: target.blueTickVerified
                        ? L10n.string("Blue tick is on for this account.")
                        : L10n.string("Blue tick is off for this account.")
                ) {
                    Button(target.blueTickVerified ? L10n.string("Remove blue tick") : L10n.string("Add blue tick")) {
                        Task { await run { try await adminService.adminSetUserBlueTickVerified(userId: uid, blueTickVerified: !target.blueTickVerified) } onSuccess: {
                            target = User(
                                id: target.id,
                                userId: target.userId,
                                username: target.username,
                                displayName: target.displayName,
                                avatarURL: target.avatarURL,
                                bio: target.bio,
                                location: target.location,
                                locationAbbreviation: target.locationAbbreviation,
                                memberSince: target.memberSince,
                                rating: target.rating,
                                reviewCount: target.reviewCount,
                                listingsCount: target.listingsCount,
                                followingsCount: target.followingsCount,
                                followersCount: target.followersCount,
                                isStaff: target.isStaff,
                                isVerified: target.isVerified,
                                blueTickVerified: !target.blueTickVerified,
                                profileTier: target.profileTier,
                                isVacationMode: target.isVacationMode,
                                isMultibuyEnabled: target.isMultibuyEnabled,
                                email: target.email,
                                phoneDisplay: target.phoneDisplay,
                                dateOfBirth: target.dateOfBirth,
                                gender: target.gender,
                                shippingAddress: target.shippingAddress,
                                isFollowing: target.isFollowing,
                                postageOptions: target.postageOptions,
                                payoutBankAccount: target.payoutBankAccount,
                                sellerGoldRenewsAt: target.sellerGoldRenewsAt,
                                isBanned: target.isBanned,
                                suspendedUntil: target.suspendedUntil
                            )
                        }}
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(Theme.primaryColor)
                }

                moderationCard(
                    title: L10n.string("Email verification"),
                    status: target.isVerified
                        ? L10n.string("Email is verified for this account.")
                        : L10n.string("Email is not verified for this account.")
                ) {
                    Button(target.isVerified ? L10n.string("Remove email verification") : L10n.string("Mark email verified")) {
                        Task { await run { try await adminService.adminSetUserEmailVerified(userId: uid, emailVerified: !target.isVerified) } onSuccess: {
                            target = User(
                                id: target.id,
                                userId: target.userId,
                                username: target.username,
                                displayName: target.displayName,
                                avatarURL: target.avatarURL,
                                bio: target.bio,
                                location: target.location,
                                locationAbbreviation: target.locationAbbreviation,
                                memberSince: target.memberSince,
                                rating: target.rating,
                                reviewCount: target.reviewCount,
                                listingsCount: target.listingsCount,
                                followingsCount: target.followingsCount,
                                followersCount: target.followersCount,
                                isStaff: target.isStaff,
                                isVerified: !target.isVerified,
                                blueTickVerified: target.blueTickVerified,
                                profileTier: target.profileTier,
                                isVacationMode: target.isVacationMode,
                                isMultibuyEnabled: target.isMultibuyEnabled,
                                email: target.email,
                                phoneDisplay: target.phoneDisplay,
                                dateOfBirth: target.dateOfBirth,
                                gender: target.gender,
                                shippingAddress: target.shippingAddress,
                                isFollowing: target.isFollowing,
                                postageOptions: target.postageOptions,
                                payoutBankAccount: target.payoutBankAccount,
                                sellerGoldRenewsAt: target.sellerGoldRenewsAt,
                                isBanned: target.isBanned,
                                suspendedUntil: target.suspendedUntil
                            )
                        }}
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(target.isVerified ? Theme.Colors.error : Theme.primaryColor)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(L10n.string("Profile tier"))
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    VStack(spacing: 0) {
                        Text(tierLabel)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.Spacing.md)
                        ContentDivider()
                        tierButton(L10n.string("Set Pro"), disabled: target.profileTier == "PRO") {
                            Task { await run { try await adminService.adminSetUserProfileTier(userId: uid, profileTier: "PRO") } onSuccess: {
                                applyTier("PRO")
                            }}
                        }
                        ContentDivider()
                        tierButton(L10n.string("Set Elite"), disabled: target.profileTier == "ELITE") {
                            Task { await run { try await adminService.adminSetUserProfileTier(userId: uid, profileTier: "ELITE") } onSuccess: {
                                applyTier("ELITE")
                            }}
                        }
                        ContentDivider()
                        tierButton(
                            L10n.string("Clear tier"),
                            disabled: target.profileTier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            isDestructive: true
                        ) {
                            Task { await run { try await adminService.adminSetUserProfileTier(userId: uid, profileTier: "") } onSuccess: {
                                applyTier("")
                            }}
                        }
                    }
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius, style: .continuous))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(L10n.string("Admin"))
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(
                            target.isStaff
                                ? L10n.string("This account has staff access (Admin Dashboard, Accounts, moderation tools).")
                                : L10n.string("Grant staff access for moderation tools, Accounts switching, and Admin Dashboard.")
                        )
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.primaryText)
                        if target.isStaff {
                            Button(L10n.string("Remove staff access")) {
                                confirmRemoveStaff = true
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(Theme.Colors.error)
                        } else {
                            Button(L10n.string("Grant staff access")) {
                                confirmGrantStaff = true
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(Theme.primaryColor)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius, style: .continuous))
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("User actions"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.string("Close")) { dismiss() }
            }
        }
        .onAppear {
            adminService.updateAuthToken(authService.authToken)
        }
        .onChange(of: authService.authToken) { _, new in
            adminService.updateAuthToken(new)
        }
        .alert(L10n.string("Error"), isPresented: Binding(
            get: { errorAlert != nil },
            set: { if !$0 { errorAlert = nil } }
        )) {
            Button(L10n.string("OK"), role: .cancel) { errorAlert = nil }
        } message: {
            Text(errorAlert ?? "")
        }
        .confirmationDialog(
            L10n.string("Remove staff access for this user?"),
            isPresented: $confirmRemoveStaff,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Remove staff access"), role: .destructive) {
                Task { await run { try await adminService.adminSetUserStaff(userId: uid, isStaff: false) } onSuccess: {
                    applyStaff(false)
                }}
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            L10n.string("Grant staff access? This user can use moderation tools."),
            isPresented: $confirmGrantStaff,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Grant staff access")) {
                Task { await run { try await adminService.adminSetUserStaff(userId: uid, isStaff: true) } onSuccess: {
                    applyStaff(true)
                }}
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        }
        .overlay {
            if busy {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }

    private var uid: Int {
        guard let id = target.userId else { return -1 }
        return id
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(L10n.string("Report user"))
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
            NavigationLink {
                ReportUserView(username: target.username)
                    .environmentObject(authService)
            } label: {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(Theme.primaryColor)
                    Text(L10n.string("Report user"))
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func moderationCard(title: String, status: String, @ViewBuilder actions: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
            VStack(spacing: 0) {
                Text(status)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                ContentDivider()
                actions()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius, style: .continuous))
        }
    }

    private func tierButton(_ title: String, disabled: Bool, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.callout)
                .fontWeight(.medium)
                .foregroundColor(disabled ? Theme.Colors.secondaryText : (isDestructive ? Theme.Colors.error : Theme.primaryColor))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.md)
        }
        .disabled(disabled || busy || uid < 0)
        .buttonStyle(.plain)
    }

    private func applyTier(_ raw: String) {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        target = User(
            id: target.id,
            userId: target.userId,
            username: target.username,
            displayName: target.displayName,
            avatarURL: target.avatarURL,
            bio: target.bio,
            location: target.location,
            locationAbbreviation: target.locationAbbreviation,
            memberSince: target.memberSince,
            rating: target.rating,
            reviewCount: target.reviewCount,
            listingsCount: target.listingsCount,
            followingsCount: target.followingsCount,
            followersCount: target.followersCount,
            isStaff: target.isStaff,
            isVerified: target.isVerified,
            blueTickVerified: target.blueTickVerified,
            profileTier: t,
            isVacationMode: target.isVacationMode,
            isMultibuyEnabled: target.isMultibuyEnabled,
            email: target.email,
            phoneDisplay: target.phoneDisplay,
            dateOfBirth: target.dateOfBirth,
            gender: target.gender,
            shippingAddress: target.shippingAddress,
            isFollowing: target.isFollowing,
            postageOptions: target.postageOptions,
            payoutBankAccount: target.payoutBankAccount,
            sellerGoldRenewsAt: target.sellerGoldRenewsAt,
            isBanned: target.isBanned,
            suspendedUntil: target.suspendedUntil
        )
    }

    private func applyStaff(_ staff: Bool) {
        target = User(
            id: target.id,
            userId: target.userId,
            username: target.username,
            displayName: target.displayName,
            avatarURL: target.avatarURL,
            bio: target.bio,
            location: target.location,
            locationAbbreviation: target.locationAbbreviation,
            memberSince: target.memberSince,
            rating: target.rating,
            reviewCount: target.reviewCount,
            listingsCount: target.listingsCount,
            followingsCount: target.followingsCount,
            followersCount: target.followersCount,
            isStaff: staff,
            isVerified: target.isVerified,
            blueTickVerified: target.blueTickVerified,
            profileTier: target.profileTier,
            isVacationMode: target.isVacationMode,
            isMultibuyEnabled: target.isMultibuyEnabled,
            email: target.email,
            phoneDisplay: target.phoneDisplay,
            dateOfBirth: target.dateOfBirth,
            gender: target.gender,
            shippingAddress: target.shippingAddress,
            isFollowing: target.isFollowing,
            postageOptions: target.postageOptions,
            payoutBankAccount: target.payoutBankAccount,
            sellerGoldRenewsAt: target.sellerGoldRenewsAt,
            isBanned: target.isBanned,
            suspendedUntil: target.suspendedUntil
        )
    }

    private func run(_ op: () async throws -> (success: Bool, message: String?), onSuccess: @escaping () -> Void) async {
        guard uid >= 0 else {
            errorAlert = L10n.string("Could not resolve this user’s id. Pull to refresh on their profile and try again.")
            return
        }
        busy = true
        defer { busy = false }
        do {
            let (ok, msg) = try await op()
            if ok {
                onSuccess()
                await onProfileChanged()
            } else {
                errorAlert = msg ?? L10n.string("Request failed.")
            }
        } catch {
            errorAlert = L10n.userFacingError(error)
        }
    }
}
