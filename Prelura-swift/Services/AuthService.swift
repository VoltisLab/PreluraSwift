import Combine
import FirebaseCore
import FirebaseMessaging
import Foundation
import OSLog
import UIKit
import UserNotifications

private let authSessionLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Wearhouse", category: "AuthSession")

@MainActor
class AuthService: ObservableObject {
    private let client: GraphQLClient
    @Published var authToken: String?
    @Published var refreshToken: String?
    @Published var username: String?
    /// When true, user chose "Continue as guest" and can browse without logging in. No auth sent for feed/product APIs.
    @Published var isGuestMode: Bool = false
    /// Set to true after email verification + login so the app shows onboarding then feed.
    @Published var shouldShowOnboardingAfterLogin: Bool = false
    /// From `viewMe` — full-screen ban / suspension gate when active.
    @Published private(set) var accountIsBanned: Bool = false
    @Published private(set) var accountSuspendedUntil: Date?

    private static let kGuestMode = "IS_GUEST_MODE"
    private static let kOnboardingCompleted = "ONBOARDING_COMPLETED"
    private static let kLoginDeviceInstallId = "wearhouse_login_device_install_id_v1"
    /// Cached from last `viewMe` / `getUser` — staff users may use multi-account switching.
    private static let kViewMeIsStaff = "wearhouse_viewme_is_staff"
    /// Persisted JWT pairs for staff multi-account (usernames must be unique).
    private static let kStaffMultiSessions = "wearhouse_staff_multi_sessions_v1"

    private struct StaffSession: Codable, Equatable {
        var username: String
        var authToken: String
        var refreshToken: String
    }

    /// True when the signed-in user is staff (from last profile refresh). Used for menu visibility.
    var isStaffMember: Bool {
        UserDefaults.standard.bool(forKey: Self.kViewMeIsStaff)
    }

    /// Staff: saved sessions for switching (includes current user after sync).
    var staffSessionsForUI: [(username: String, isActive: Bool)] {
        let list = loadStaffSessions()
        let current = username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return list.map { s in
            (s.username, s.username.lowercased() == current)
        }
    }

    /// Call immediately before logging into an **additional** account (staff only). Persists the current session so you can switch back.
    func prepareForAdditionalStaffLogin() {
        guard isAuthenticated else { return }
        guard UserDefaults.standard.bool(forKey: Self.kViewMeIsStaff) else { return }
        guard let t = authToken, let r = refreshToken, let u = username else { return }
        upsertStaffSession(StaffSession(username: u, authToken: t, refreshToken: r))
    }

    func switchToStaffAccount(username: String) async throws {
        guard UserDefaults.standard.bool(forKey: Self.kViewMeIsStaff) else {
            throw NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Only staff accounts can switch."])
        }
        if let t = authToken, let r = refreshToken, let u = self.username {
            upsertStaffSession(StaffSession(username: u, authToken: t, refreshToken: r))
        }
        guard let s = loadStaffSessions().first(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) else {
            throw NSError(domain: "AuthService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Session not found. Sign in again from Accounts."])
        }
        storeTokens(token: s.authToken, refreshToken: s.refreshToken, username: s.username)
        await refreshAccountModerationFromServer()
        NotificationCenter.default.post(name: .wearhouseUserProfileDidUpdate, object: nil)
    }

    /// Removes one account from the server (FCM unregistered for that user) and from the local session list.
    func logoutStaffAccount(username: String) async {
        guard let s = loadStaffSessions().first(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) else { return }
        let isCurrent = self.username?.caseInsensitiveCompare(username) == .orderedSame
        await serverLogoutWithBearer(accessToken: s.authToken, refreshToken: s.refreshToken)
        var list = loadStaffSessions().filter { $0.username.caseInsensitiveCompare(username) != .orderedSame }
        saveStaffSessions(list)
        if isCurrent {
            if let next = list.first {
                storeTokens(token: next.authToken, refreshToken: next.refreshToken, username: next.username)
                await refreshAccountModerationFromServer()
                NotificationCenter.default.post(name: .wearhouseUserProfileDidUpdate, object: nil)
            } else {
                await performFullLogoutClearingEverything()
            }
        }
    }

    /// Signs out every saved staff session on the server, then clears local state (no duplicate server logout).
    func logoutAllStaffSessions() async {
        let snapshot = loadStaffSessions()
        guard !snapshot.isEmpty else {
            await performFullLogoutClearingEverything()
            return
        }
        for s in snapshot {
            await serverLogoutWithBearer(accessToken: s.authToken, refreshToken: s.refreshToken)
        }
        saveStaffSessions([])
        UserDefaults.standard.removeObject(forKey: Self.kViewMeIsStaff)
        UserDefaults.standard.removeObject(forKey: Self.kStaffMultiSessions)
        clearTokens()
        UserDefaults.standard.removeObject(forKey: kDeviceTokenKey)
        UserDefaults.standard.removeObject(forKey: PushRegistrationDebug.uploadSummaryKey)
        UserDefaults.standard.removeObject(forKey: PushRegistrationDebug.uploadDetailKey)
        UserDefaults.standard.removeObject(forKey: PushRegistrationDebug.uploadTimestampKey)
        clearLocalNotificationState()
        await revokeLocalFCMRegistration()
        objectWillChange.send()
    }

    /// Registers the device FCM token with **every** saved staff session on the server so pushes reach all signed-in accounts. Returns `true` when staff mirroring ran.
    func registerFCMTokenWithAllStaffSessionsIfNeeded(_ token: String) async -> Bool {
        guard UserDefaults.standard.bool(forKey: Self.kViewMeIsStaff) else { return false }
        let sessions = loadStaffSessions()
        guard !sessions.isEmpty else { return false }
        for s in sessions {
            let us = UserService()
            us.updateAuthToken(s.authToken)
            do {
                _ = try await us.updateProfile(fcmToken: token)
            } catch {
                authSessionLogger.warning("FCM for staff session \(s.username, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return true
    }

    private func loadStaffSessions() -> [StaffSession] {
        guard let data = UserDefaults.standard.data(forKey: Self.kStaffMultiSessions),
              let list = try? JSONDecoder().decode([StaffSession].self, from: data) else { return [] }
        return list
    }

    private func saveStaffSessions(_ sessions: [StaffSession]) {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.kStaffMultiSessions)
        }
    }

    private func upsertStaffSession(_ session: StaffSession) {
        var list = loadStaffSessions()
        if let i = list.firstIndex(where: { $0.username.caseInsensitiveCompare(session.username) == .orderedSame }) {
            list[i] = session
        } else {
            list.append(session)
        }
        saveStaffSessions(list)
    }

    private func syncStaffSessionsAfterProfileLoad(user: User) {
        UserDefaults.standard.set(user.isStaff, forKey: Self.kViewMeIsStaff)
        guard user.isStaff else {
            UserDefaults.standard.removeObject(forKey: Self.kStaffMultiSessions)
            return
        }
        guard let t = authToken, let r = refreshToken, let un = username else { return }
        upsertStaffSession(StaffSession(username: un, authToken: t, refreshToken: r))
    }

    private func serverLogoutWithBearer(accessToken: String, refreshToken: String) async {
        let fcmFromDevice = UserDefaults.standard.string(forKey: kDeviceTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fcmLastUploaded = UserDefaults.standard.string(forKey: kLastFcmTokenSentToBackendKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fcmForServer = [fcmFromDevice, fcmLastUploaded].compactMap { $0 }.first { !$0.isEmpty }
        let refresh = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !refresh.isEmpty else { return }
        let gql = GraphQLClient()
        gql.setAuthToken(accessToken)
        let mutation = """
        mutation Logout($refreshToken: String!, $fcmToken: String) {
          logout(refreshToken: $refreshToken, fcmToken: $fcmToken) {
            message
          }
        }
        """
        struct LogoutPayload: Decodable {
            let logout: LogoutMessage?
        }
        struct LogoutMessage: Decodable {
            let message: String?
        }
        var variables: [String: Any] = ["refreshToken": refresh]
        if let t = fcmForServer, !t.isEmpty {
            variables["fcmToken"] = t
        }
        for attempt in 1...3 {
            do {
                _ = try await gql.execute(query: mutation, variables: variables, responseType: LogoutPayload.self)
                break
            } catch {
                if attempt == 3 { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func performFullLogoutClearingEverything() async {
        let refresh = refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fcmFromDevice = UserDefaults.standard.string(forKey: kDeviceTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fcmLastUploaded = UserDefaults.standard.string(forKey: kLastFcmTokenSentToBackendKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fcmForServer = [fcmFromDevice, fcmLastUploaded].compactMap { $0 }.first { !$0.isEmpty }
        if !refresh.isEmpty, authToken != nil {
            let mutation = """
            mutation Logout($refreshToken: String!, $fcmToken: String) {
              logout(refreshToken: $refreshToken, fcmToken: $fcmToken) {
                message
              }
            }
            """
            struct LogoutPayload: Decodable {
                let logout: LogoutMessage?
            }
            struct LogoutMessage: Decodable {
                let message: String?
            }
            var variables: [String: Any] = ["refreshToken": refresh]
            if let t = fcmForServer, !t.isEmpty {
                variables["fcmToken"] = t
            }
            for attempt in 1...3 {
                do {
                    _ = try await client.execute(query: mutation, variables: variables, responseType: LogoutPayload.self)
                    break
                } catch {
                    if attempt == 3 { break }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        UserDefaults.standard.removeObject(forKey: Self.kStaffMultiSessions)
        UserDefaults.standard.removeObject(forKey: Self.kViewMeIsStaff)
        clearTokens()
        UserDefaults.standard.removeObject(forKey: kDeviceTokenKey)
        UserDefaults.standard.removeObject(forKey: PushRegistrationDebug.uploadSummaryKey)
        UserDefaults.standard.removeObject(forKey: PushRegistrationDebug.uploadDetailKey)
        UserDefaults.standard.removeObject(forKey: PushRegistrationDebug.uploadTimestampKey)
        clearLocalNotificationState()
        await revokeLocalFCMRegistration()
        objectWillChange.send()
    }
    
    init(client: GraphQLClient = GraphQLClient()) {
        StartupTiming.mark("AuthService.init — begin")
        self.client = client
        loadStoredTokens()
        StartupTiming.mark("AuthService.init — after loadStoredTokens; scheduling moderation refresh")
        Task {
            StartupTiming.mark("AuthService Task — refreshAccountModerationFromServer started")
            await refreshAccountModerationFromServer()
            StartupTiming.mark("AuthService Task — refreshAccountModerationFromServer finished")
        }
    }
    
    private func loadStoredTokens() {
        // Load from UserDefaults
        authToken = UserDefaults.standard.string(forKey: "AUTH_TOKEN")
        refreshToken = UserDefaults.standard.string(forKey: "REFRESH_TOKEN")
        username = UserDefaults.standard.string(forKey: "USERNAME")
        isGuestMode = UserDefaults.standard.bool(forKey: Self.kGuestMode)
        
        if isGuestMode {
            authToken = nil
            refreshToken = nil
            username = nil
            client.setAuthToken(nil)
        } else if let token = authToken {
            client.setAuthToken(token)
        }
    }
    
    private func storeTokens(token: String, refreshToken: String, username: String) {
        UserDefaults.standard.set(token, forKey: "AUTH_TOKEN")
        UserDefaults.standard.set(refreshToken, forKey: "REFRESH_TOKEN")
        UserDefaults.standard.set(username, forKey: "USERNAME")
        UserDefaults.standard.set(false, forKey: Self.kGuestMode)
        self.authToken = token
        self.refreshToken = refreshToken
        self.username = username
        self.isGuestMode = false
        client.setAuthToken(token)
        // After login, upload FCM token to backend (same moment GraphQL has Bearer token).
        NotificationCenter.default.post(name: .wearhouseDeviceTokenDidUpdate, object: nil)
        // OSLog: visible when filtering `subsystem == com.prelura.preloved`. Never log raw JWTs.
        authSessionLogger.info("Session stored for \(username, privacy: .public) — access JWT \(token.count, privacy: .public) chars, refresh \(refreshToken.count, privacy: .public) chars.")
        print("[Auth] Session stored for \(username) — access JWT \(token.count) chars, refresh \(refreshToken.count) chars.")
    }
    
    func login(username: String, password: String) async throws -> LoginResponse {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        try enforceClientLoginLockIfNeeded(username: u)
        do {
            let response = try await loginWithCredentials(username: u, password: p)
            LoginRateLimitGuard.clearStateForSuccessfulLogin(username: u, password: p, deviceInstallId: loginDeviceInstallId())
            return response
        } catch {
            // Same domain as scripts/seed-register-users.sh (`username@wearhouse.co.uk`). Some backends only match when the login field is the full email.
            if !u.contains("@"),
               Self.shouldRetrySeedLoginWithEmailDomain(error),
               let email = Self.seedLoginEmail(forUsername: u) {
                do {
                    let response = try await loginWithCredentials(username: email, password: p)
                    LoginRateLimitGuard.clearStateForSuccessfulLogin(username: u, password: p, deviceInstallId: loginDeviceInstallId())
                    return response
                } catch {
                    throw mapLoginFailure(username: u, password: p, error: error)
                }
            }
            throw mapLoginFailure(username: u, password: p, error: error)
        }
    }

    /// Matches default `SEED_EMAIL_DOMAIN` in seed scripts (`wearhouse.co.uk`).
    private static let seedEmailDomainForLoginRetry = "wearhouse.co.uk"

    private static func seedLoginEmail(forUsername username: String) -> String? {
        guard !username.isEmpty else { return nil }
        // Seed accounts from scripts typically use lowercase local parts; retry matches `user@wearhouse.co.uk`.
        return "\(username.lowercased())@\(seedEmailDomainForLoginRetry)"
    }

    private static func shouldRetrySeedLoginWithEmailDomain(_ error: Error) -> Bool {
        guard case let GraphQLError.graphQLErrors(errors) = error else { return false }
        let msg = errors.first?.message.lowercased() ?? ""
        return msg.contains("valid credentials") || msg.contains("please enter valid")
    }

    private func loginWithCredentials(username: String, password: String) async throws -> LoginResponse {
        let query = """
        mutation Login($username: String!, $password: String!) {
          login(username: $username, password: $password) {
            token
            refreshToken
            user {
              id
              username
              email
            }
          }
        }
        """

        let variables: [String: Any] = [
            "username": username,
            "password": password,
        ]

        let response: LoginGraphQLResponse = try await client.execute(
            query: query,
            variables: variables,
            additionalHeaders: loginAttemptHeaders(username: username, password: password),
            includeAuthorization: false,
            responseType: LoginGraphQLResponse.self
        )

        guard let loginData = response.login else {
            throw AuthError.invalidResponse
        }

        guard let token = loginData.token,
              let refreshToken = loginData.refreshToken else {
            throw AuthError.invalidResponse
        }

        storeTokens(
            token: token,
            refreshToken: refreshToken,
            username: loginData.user?.username ?? username
        )

        Task { await refreshAccountModerationFromServer() }

        objectWillChange.send()

        return loginData
    }

    private func loginDeviceInstallId() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: Self.kLoginDeviceInstallId),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return existing
        }
        let next = UUID().uuidString.lowercased()
        defaults.set(next, forKey: Self.kLoginDeviceInstallId)
        return next
    }

    private func loginAttemptHeaders(username: String, password: String) -> [String: String] {
        let installId = loginDeviceInstallId()
        let usernameKey = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let credentialFingerprint = LoginRateLimitGuard.credentialFingerprint(
            username: username,
            password: password,
            deviceInstallId: installId
        )
        return [
            "X-Prelura-Device-Install-Id": installId,
            "X-Prelura-Login-Identifier": usernameKey,
            "X-Prelura-Login-Credential-Fingerprint": credentialFingerprint,
        ]
    }

    private func enforceClientLoginLockIfNeeded(username: String) throws {
        guard let remaining = LoginRateLimitGuard.activeLockRemainingSeconds(for: username) else { return }
        throw AuthError.loginRateLimited(remainingSeconds: Int(remaining.rounded(.up)))
    }

    private func mapLoginFailure(username: String, password: String, error: Error) -> Error {
        if let lockSeconds = Self.serverLoginRateLimitSeconds(from: error) {
            return AuthError.loginRateLimited(remainingSeconds: lockSeconds)
        }
        if let lockSeconds = LoginRateLimitGuard.registerFailedAttempt(
            username: username,
            password: password,
            deviceInstallId: loginDeviceInstallId()
        ) {
            return AuthError.loginRateLimited(remainingSeconds: Int(lockSeconds.rounded(.up)))
        }
        return error
    }

    private static func serverLoginRateLimitSeconds(from error: Error) -> Int? {
        guard case let GraphQLError.graphQLErrors(errors) = error else { return nil }
        for e in errors {
            let message = e.message.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = message.lowercased()
            let hints = [
                "too many login attempts",
                "too many failed login attempts",
                "rate limit",
                "login temporarily locked",
                "account temporarily locked",
                "try again in",
            ]
            guard hints.contains(where: { lower.contains($0) }) else { continue }
            if let parsed = parseRetryDurationSeconds(from: lower) {
                return max(60, parsed)
            }
            // Cross-device account lock policy minimum.
            return 30 * 60
        }
        return nil
    }

    private static func parseRetryDurationSeconds(from lower: String) -> Int? {
        let minutePattern = #"(\d+)\s*(minute|minutes|min|mins|m)\b"#
        if let minutes = firstRegexCaptureInt(pattern: minutePattern, input: lower) {
            return minutes * 60
        }
        let secondPattern = #"(\d+)\s*(second|seconds|sec|secs|s)\b"#
        if let seconds = firstRegexCaptureInt(pattern: secondPattern, input: lower) {
            return seconds
        }
        return nil
    }

    private static func firstRegexCaptureInt(pattern: String, input: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, options: [], range: range), match.numberOfRanges > 1 else { return nil }
        let valueRange = match.range(at: 1)
        guard valueRange.location != NSNotFound,
              let swiftRange = Range(valueRange, in: input) else { return nil }
        return Int(input[swiftRange])
    }
    
    /// Verify email/account with code from verification link. Matches Flutter verifyAccount(code). No auth required.
    func verifyAccount(code: String) async throws -> Bool {
        let mutation = """
        mutation VerifyAccount($code: String!) {
          verifyAccount(code: $code) {
            success
          }
        }
        """
        struct Payload: Decodable { let verifyAccount: VerifyResult? }
        struct VerifyResult: Decodable { let success: Bool? }
        let response: Payload = try await client.execute(
            query: mutation,
            variables: ["code": code],
            includeAuthorization: false,
            responseType: Payload.self
        )
        return response.verifyAccount?.success ?? false
    }

    /// Resend verification code to the given email. No auth required. Use when user didn't receive the code.
    func resendActivationEmail(email: String) async throws -> Bool {
        let mutation = """
        mutation ResendActivationEmail($email: String!) {
          resendActivationEmail(email: $email) {
            success
          }
        }
        """
        struct Payload: Decodable { let resendActivationEmail: ResendResult? }
        struct ResendResult: Decodable { let success: Bool? }
        let response: Payload = try await client.execute(
            query: mutation,
            variables: ["email": email],
            includeAuthorization: false,
            responseType: Payload.self
        )
        return response.resendActivationEmail?.success ?? false
    }

    func register(
        email: String,
        firstName: String,
        lastName: String,
        username: String,
        password1: String,
        password2: String
    ) async throws -> RegisterResponse {
        let query = """
        mutation Register($email: String!, $firstName: String!, $lastName: String!, $username: String!, $password1: String!, $password2: String!) {
          register(
            email: $email
            firstName: $firstName
            lastName: $lastName
            username: $username
            password1: $password1
            password2: $password2
          ) {
            success
            errors
          }
        }
        """
        
        let variables: [String: Any] = [
            "email": email,
            "firstName": firstName,
            "lastName": lastName,
            "username": username,
            "password1": password1,
            "password2": password2
        ]
        
        let response: RegisterGraphQLResponse = try await client.execute(
            query: query,
            variables: variables,
            includeAuthorization: false,
            responseType: RegisterGraphQLResponse.self
        )
        
        guard let registerData = response.register else {
            throw AuthError.invalidResponse
        }
        
        if let errors = registerData.errors, !errors.isEmpty {
            // Extract first error message
            for (_, messages) in errors {
                if let firstMessage = messages.first {
                    throw AuthError.registrationError(firstMessage)
                }
            }
            throw AuthError.registrationError("Registration failed")
        }
        
        return registerData
    }
    
    /// Signs out. Staff users with more than one saved session log out only the **current** account and switch to another; otherwise full sign-out.
    func logout() async {
        let sessions = loadStaffSessions()
        let staff = UserDefaults.standard.bool(forKey: Self.kViewMeIsStaff)
        if staff, sessions.count > 1, let u = username {
            await logoutStaffAccount(username: u)
            return
        }
        await performFullLogoutClearingEverything()
    }

    /// Invalidates the FCM instance token so this install stops receiving pushes targeted at the old registration.
    private func revokeLocalFCMRegistration() async {
        guard FirebaseApp.app() != nil else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            Messaging.messaging().deleteToken { _ in
                cont.resume()
            }
        }
    }

    /// Continue as guest: clear tokens and set flag so feed uses public (no-auth) API. Matches Flutter isGuestModeProvider + clearTokenForGuest.
    func continueAsGuest() {
        UserDefaults.standard.removeObject(forKey: "AUTH_TOKEN")
        UserDefaults.standard.removeObject(forKey: "REFRESH_TOKEN")
        UserDefaults.standard.removeObject(forKey: "USERNAME")
        UserDefaults.standard.set(true, forKey: Self.kGuestMode)
        authToken = nil
        refreshToken = nil
        username = nil
        isGuestMode = true
        client.setAuthToken(nil)
        clearAccountModeration()
        UserDefaults.standard.removeObject(forKey: kDeviceTokenKey)
        UserDefaults.standard.removeObject(forKey: kLastFcmTokenSentToBackendKey)
        clearLocalNotificationState()
        Task { await revokeLocalFCMRegistration() }
        objectWillChange.send()
    }

    /// Leave guest mode and return to login screen (no token).
    func clearGuestMode() {
        UserDefaults.standard.set(false, forKey: Self.kGuestMode)
        isGuestMode = false
        objectWillChange.send()
    }

    /// Request password reset: sends OTP/code to email (matches Flutter resetPassword(email)).
    func requestPasswordReset(email: String) async throws {
        let query = """
        mutation ResetPassword($email: String) {
          resetPassword(email: $email) {
            message
          }
        }
        """
        struct Payload: Decodable {
            let resetPassword: ResetPasswordResult?
        }
        struct ResetPasswordResult: Decodable {
            let message: String?
        }
        let response: Payload = try await client.execute(query: query, variables: ["email": email], includeAuthorization: false, responseType: Payload.self)
        if response.resetPassword == nil {
            throw AuthError.invalidResponse
        }
    }

    /// Set new password with code from email (matches Flutter passwordReset).
    func resetPasswordWithCode(email: String, code: String, newPassword: String) async throws {
        let query = """
        mutation PasswordReset($email: String!, $code: String!, $password: String!) {
          passwordReset(email: $email, code: $code, password: $password) {
            message
          }
        }
        """
        struct Payload: Decodable {
            let passwordReset: PasswordResetResult?
        }
        struct PasswordResetResult: Decodable {
            let message: String?
        }
        let variables: [String: Any] = ["email": email, "code": code, "password": newPassword]
        let response: Payload = try await client.execute(query: query, variables: variables, includeAuthorization: false, responseType: Payload.self)
        if response.passwordReset == nil {
            throw AuthError.invalidResponse
        }
    }

    private func clearTokens() {
        UserDefaults.standard.removeObject(forKey: kLastFcmTokenSentToBackendKey)
        UserDefaults.standard.removeObject(forKey: "AUTH_TOKEN")
        UserDefaults.standard.removeObject(forKey: "REFRESH_TOKEN")
        UserDefaults.standard.removeObject(forKey: "USERNAME")
        UserDefaults.standard.set(false, forKey: Self.kGuestMode)
        authToken = nil
        refreshToken = nil
        username = nil
        isGuestMode = false
        client.setAuthToken(nil)
        clearAccountModeration()
    }

    private func clearLocalNotificationState() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    var isAuthenticated: Bool {
        authToken != nil
    }

    /// True when the user must see the account restriction screen (banned or suspension still in effect).
    var isAccountRestricted: Bool {
        if accountIsBanned { return true }
        if let end = accountSuspendedUntil, end > Date() { return true }
        return false
    }

    func applyAccountModeration(from user: User) {
        accountIsBanned = user.isBanned
        accountSuspendedUntil = user.suspendedUntil
        UserService.shouldSkipProfanityStrikeRecording = user.isStaff
    }

    func refreshAccountModerationFromServer() async {
        guard isAuthenticated else {
            clearAccountModeration()
            return
        }
        let us = UserService()
        us.updateAuthToken(authToken)
        guard let u = try? await us.getUser() else { return }
        applyAccountModeration(from: u)
        syncStaffSessionsAfterProfileLoad(user: u)
    }

    private func clearAccountModeration() {
        accountIsBanned = false
        accountSuspendedUntil = nil
        UserService.shouldSkipProfanityStrikeRecording = false
    }

    /// Call after user completes onboarding (e.g. after verify-email flow). Hides onboarding and persists so we don't show again.
    func markOnboardingCompleted() {
        shouldShowOnboardingAfterLogin = false
        UserDefaults.standard.set(true, forKey: Self.kOnboardingCompleted)
    }

    /// Whether we should show onboarding (e.g. first time after verification). Respects kOnboardingCompleted.
    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Self.kOnboardingCompleted)
    }
}

// Response Models
struct LoginGraphQLResponse: Decodable {
    let login: LoginResponse?
}

struct RegisterGraphQLResponse: Decodable {
    let register: RegisterResponse?
}

struct LoginResponse: Decodable {
    let token: String?
    let refreshToken: String?
    let user: UserResponse?
}

struct UserResponse: Decodable {
    let id: String?
    let username: String?
    let email: String?
}

struct RegisterResponse: Decodable {
    let success: Bool?
    let errors: [String: [String]]?
}

enum AuthError: Error, LocalizedError {
    case invalidResponse
    case registrationError(String)
    case networkError(Error)
    case loginRateLimited(remainingSeconds: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .registrationError(let message):
            return message
        case .networkError(let error):
            return L10n.userFacingError(error)
        case .loginRateLimited(let remainingSeconds):
            let mins = max(1, Int(ceil(Double(remainingSeconds) / 60.0)))
            if mins == 1 {
                return "Too many login attempts. Try again in about 1 minute."
            }
            return "Too many login attempts. Try again in about \(mins) minutes."
        }
    }
}
