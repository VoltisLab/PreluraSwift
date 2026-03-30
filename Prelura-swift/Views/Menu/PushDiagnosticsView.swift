import SwiftUI
import UIKit
import UserNotifications
import FirebaseCore

private enum PushTestInstructionKind {
    case localOnDevice
    case serverFCM

    var sheetTitle: String {
        switch self {
        case .localOnDevice: return "Local test (no server)"
        case .serverFCM: return "Server test push"
        }
    }

    var shortLabel: String {
        switch self {
        case .localOnDevice:
            return "Only your iPhone schedules this alert — no Prelura API, no Firebase, no APNs. Use it to confirm notification permission and banners work."
        case .serverFCM:
            return "Prelura’s API asks Firebase to send APNs to this app. That only matches if Firebase has the Swift app (com.prelura.preloved) set up with the same keys as Flutter’s bundle."
        }
    }
}

/// Menu → Debug — confirms Firebase, permission, local FCM token, and last `updateProfile(fcmToken:)` result.
struct PushDiagnosticsView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var permissionText = "…"
    @State private var firebaseOk = false
    @State private var tokenPreview = "—"
    @State private var uploadSummary = "—"
    @State private var uploadDetail = ""
    @State private var uploadTime = "—"
    @State private var isRefreshing = false
    @State private var refreshNote = ""
    @State private var testPushCountdown: Int?
    @State private var testPushBusy = false
    @State private var traceEntries: [NotificationDebugLog.Entry] = []
    @State private var showBackgroundSheet = false
    @State private var backgroundSheetKind: PushTestInstructionKind = .localOnDevice

    /// Seconds to wait so you can swipe home before a test fires (`UNLocalNotification` or server push).
    private let pushTestLeadSeconds = 8

    var body: some View {
        List {
            Section {
                Text(
                    "Step 1 — Prove the OS: use **Local on-device test** below, background Prelura when the sheet says so, and see a banner. That needs no server.\n\n"
                        + "Step 2 — Remote push: use **Server test push** (or Firebase console with your token). Flutter’s bundle (com.prelura.app) can work while Swift (com.prelura.preloved) does not until that app is registered in Firebase with the same APNs key."
                )
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .listRowBackground(Color.clear)
            } header: {
                Text("Why Swift might differ from Flutter")
            }

            Section {
                LabeledContent("Firebase in app") {
                    Text(firebaseOk ? "Configured" : "Missing / invalid plist")
                        .foregroundColor(firebaseOk ? Theme.Colors.primaryText : .red)
                }
                LabeledContent("Notification permission") {
                    Text(permissionText)
                }
                LabeledContent("Signed in") {
                    Text(authService.isAuthenticated ? "Yes" : "No — token not uploaded")
                }
                LabeledContent("FCM token (device)") {
                    Text(tokenPreview)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Device")
            }

            Section {
                LabeledContent("Last API upload") {
                    Text(uploadSummary)
                }
                if !uploadDetail.isEmpty {
                    Text(uploadDetail)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                Text("At: \(uploadTime)")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.secondaryText)
            } header: {
                Text("Backend")
            }

            Section {
                Button {
                    Task { await refreshFromFirebaseAndUpload() }
                } label: {
                    HStack {
                        Text("Refresh FCM token & upload")
                        if isRefreshing { ProgressView() }
                    }
                }
                .disabled(isRefreshing || !authService.isAuthenticated)

                if let full = UserDefaults.standard.string(forKey: kDeviceTokenKey), !full.isEmpty {
                    Button("Copy full FCM token") {
                        UIPasteboard.general.string = full
                        refreshNote = "Token copied — paste into Firebase → Messaging → Send test message."
                    }
                }

                if !refreshNote.isEmpty {
                    Text(refreshNote)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            } header: {
                Text("Registration")
            } footer: {
                Text("If “No FCM token yet” persists on a real iPhone, check Settings → Prelura → Notifications and Xcode Signing → Push capability.")
            }

            Section {
                Button {
                    startLocalOnDeviceTest()
                } label: {
                    HStack {
                        Text("Local on-device test (no server)")
                        if testPushBusy, backgroundSheetKind == .localOnDevice, testPushCountdown != nil {
                            ProgressView()
                        }
                    }
                }
                .disabled(testPushBusy)

                Button {
                    scheduleServerTestPushAfterDelay()
                } label: {
                    HStack {
                        if let c = testPushCountdown, backgroundSheetKind == .serverFCM {
                            Text("Server test — \(c)s…")
                        } else {
                            Text("Server test push (FCM)")
                        }
                        if testPushBusy, backgroundSheetKind == .serverFCM, testPushCountdown == nil { ProgressView() }
                    }
                }
                .disabled(!authService.isAuthenticated || testPushBusy)

                Text(
                    "Both tests wait \(pushTestLeadSeconds) seconds. When the sheet appears, **leave Prelura** (swipe up / Home) so the alert can appear like a real push. Keeping the app open may still show a banner in some cases."
                )
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
            } header: {
                Text("Push tests")
            } footer: {
                Text("Server test: wait at least 60 seconds between attempts if the API rate-limits. Local test can be repeated anytime.")
            }

            Section {
                Text(
                    "If local test works but server test never shows a banner, fix **Firebase → iOS app com.prelura.preloved → Cloud Messaging → APNs key** (same .p8 as Flutter is OK; it must be on this app entry)."
                )
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .listRowBackground(Color.clear)
            } header: {
                Text("Upload OK but no remote alerts?")
            }

            Section {
                if traceEntries.isEmpty {
                    Text("No events yet. Run a local or server test — lines appear here.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                } else {
                    ForEach(traceEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.at)
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Text("[\(entry.source)] \(entry.message)")
                                .font(.caption)
                                .foregroundStyle(entry.isError ? Color.red : Theme.Colors.primaryText)
                                .textSelection(.enabled)
                        }
                    }
                }
                Button("Clear event trace", role: .destructive) {
                    NotificationDebugLog.clear()
                    reloadTrace()
                }
            } header: {
                Text("Notification event trace")
            } footer: {
                Text("“local” = on-device test only. “remote” / “present” / “tap” = FCM-style payloads. If local works but you never see remote lines, Apple is not delivering FCM to this bundle — fix Firebase APNs for com.prelura.preloved.")
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Push diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBackgroundSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text(backgroundSheetKind.sheetTitle)
                        .font(.title2.weight(.semibold))
                    Text(backgroundSheetKind.shortLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("**Now background Prelura:** swipe up from the bottom edge, double-tap Home, or use the Home button — then stay out of the app until the time hits zero.")
                        .font(.body)
                    if let c = testPushCountdown {
                        Text("Fires in \(c)s")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Starting…")
                            .font(.title)
                            .frame(maxWidth: .infinity)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Dismiss") {
                            showBackgroundSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            loadStaticState()
            reloadTrace()
        }
        .onReceive(NotificationCenter.default.publisher(for: .preluraNotificationDebugLogDidChange)) { _ in
            reloadTrace()
        }
    }

    private func reloadTrace() {
        traceEntries = NotificationDebugLog.entries()
    }

    private func loadStaticState() {
        firebaseOk = FirebaseApp.app() != nil
        if let t = UserDefaults.standard.string(forKey: kDeviceTokenKey), !t.isEmpty {
            tokenPreview = tokenSnippet(t)
        } else {
            tokenPreview = "(none — not generated yet)"
        }
        uploadSummary = UserDefaults.standard.string(forKey: PushRegistrationDebug.uploadSummaryKey) ?? "—"
        uploadDetail = UserDefaults.standard.string(forKey: PushRegistrationDebug.uploadDetailKey) ?? ""
        uploadTime = UserDefaults.standard.string(forKey: PushRegistrationDebug.uploadTimestampKey) ?? "—"

        UNUserNotificationCenter.current().getNotificationSettings { s in
            let t: String
            switch s.authorizationStatus {
            case .authorized: t = "Authorized"
            case .denied: t = "Denied — enable in Settings"
            case .notDetermined: t = "Not determined"
            case .provisional: t = "Provisional"
            case .ephemeral: t = "Ephemeral"
            @unknown default: t = "Unknown"
            }
            DispatchQueue.main.async { permissionText = t }
        }
    }

    private func tokenSnippet(_ full: String) -> String {
        guard full.count > 16 else { return full }
        let a = full.prefix(12)
        let b = full.suffix(8)
        return "\(a)…\(b) (\(full.count) chars)"
    }

    /// Proves alerts work using only `UserNotifications` (no API, no FCM, no APNs from Prelura).
    private func startLocalOnDeviceTest() {
        guard !testPushBusy else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let ok: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: ok = true
            default: ok = false
            }
            guard ok else {
                DispatchQueue.main.async {
                    NotificationDebugLog.append(
                        source: "local",
                        message: "Local test skipped — notification permission not granted (Settings → Prelura → Notifications)",
                        isError: true
                    )
                    reloadTrace()
                    loadStaticState()
                }
                return
            }
            DispatchQueue.main.async {
                runCountdownThen(kind: .localOnDevice) {
                    await scheduleLocalTestNotification()
                }
            }
        }
    }

    @MainActor
    private func scheduleLocalTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Prelura — on-device test"
        content.body = "This alert did not use any server. If you see it, notifications work on this iPhone."
        content.sound = .default
        content.userInfo = [kPreluraLocalPushTestUserInfoKey: 1]

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [kPreluraLocalPushTestNotificationId])
        center.removeDeliveredNotifications(withIdentifiers: [kPreluraLocalPushTestNotificationId])

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: kPreluraLocalPushTestNotificationId,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
            NotificationDebugLog.append(
                source: "local",
                message: "Scheduled on-device notification (fires in ~1s — Lock Screen / banner)",
                isError: false
            )
        } catch {
            NotificationDebugLog.append(
                source: "local",
                message: "Failed to schedule local notification: \(error.localizedDescription)",
                isError: true
            )
        }
        reloadTrace()
    }

    private func scheduleServerTestPushAfterDelay() {
        guard authService.isAuthenticated, let bearer = authService.authToken, !testPushBusy else { return }
        runCountdownThen(kind: .serverFCM) {
            await sendServerDebugPush(bearer: bearer)
        }
    }

    @MainActor
    private func sendServerDebugPush(bearer: String) async {
        NotificationDebugLog.append(source: "diagnostics", message: "Calling sendDebugTestPush (GraphQL)…", isError: false)
        let userService = UserService()
        userService.updateAuthToken(bearer)
        do {
            let result = try await userService.sendDebugTestPush()
            if result.success {
                NotificationDebugLog.append(
                    source: "diagnostics",
                    message: "sendDebugTestPush OK — \(result.message ?? "sent")",
                    isError: false
                )
            } else {
                NotificationDebugLog.append(
                    source: "diagnostics",
                    message: "sendDebugTestPush: \(result.message ?? "failed")",
                    isError: true
                )
            }
        } catch {
            NotificationDebugLog.append(
                source: "diagnostics",
                message: "sendDebugTestPush GraphQL error: \(error.localizedDescription)",
                isError: true
            )
        }
        reloadTrace()
    }

    /// Shows the background sheet, counts down, then runs `action` (local schedule or server mutation).
    private func runCountdownThen(
        kind: PushTestInstructionKind,
        action: @escaping @MainActor () async -> Void
    ) {
        testPushBusy = true
        backgroundSheetKind = kind
        showBackgroundSheet = true
        NotificationDebugLog.append(
            source: "diagnostics",
            message: "Push test (\(kind == .localOnDevice ? "local" : "server")) — \(pushTestLeadSeconds)s: leave the app (Home) for a real push-style banner",
            isError: false
        )
        reloadTrace()
        Task { @MainActor in
            defer {
                testPushBusy = false
                testPushCountdown = nil
                showBackgroundSheet = false
                reloadTrace()
            }
            for s in stride(from: pushTestLeadSeconds, through: 1, by: -1) {
                testPushCountdown = s
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            testPushCountdown = nil
            await action()
        }
    }

    @MainActor
    private func refreshFromFirebaseAndUpload() async {
        isRefreshing = true
        refreshNote = ""
        defer { isRefreshing = false }

        UIApplication.shared.registerForRemoteNotifications()

        guard FirebaseApp.app() != nil else {
            refreshNote = "Firebase not configured."
            NotificationDebugLog.append(source: "diagnostics", message: "Manual refresh: Firebase not configured", isError: true)
            loadStaticState()
            return
        }

        let token: String? = await withCheckedContinuation { cont in
            PreluraFCMRegistration.fetchRegistrationToken { result in
                switch result {
                case .success(let t):
                    cont.resume(returning: t)
                case .failure(let err):
                    cont.resume(returning: nil)
                    DispatchQueue.main.async {
                        self.refreshNote = "FCM token: \(err.localizedDescription)"
                    }
                    NotificationDebugLog.append(
                        source: "diagnostics",
                        message: "Manual refresh FCM error (after APNs wait): \(err.localizedDescription)",
                        isError: true
                    )
                }
            }
        }

        guard let token, !token.isEmpty else {
            refreshNote = "FCM returned no token (APNs may not be registered — common on simulator or if Push capability is off)."
            NotificationDebugLog.append(source: "diagnostics", message: "Manual refresh: empty FCM token", isError: true)
            loadStaticState()
            return
        }

        UserDefaults.standard.set(token, forKey: kDeviceTokenKey)
        NotificationCenter.default.post(name: .preluraDeviceTokenDidUpdate, object: nil)

        guard authService.isAuthenticated, let bearer = authService.authToken else {
            refreshNote = "Token received; sign in to upload to API."
            NotificationDebugLog.append(source: "diagnostics", message: "Manual refresh: FCM OK but not signed in", isError: false)
            loadStaticState()
            return
        }

        let userService = UserService()
        userService.updateAuthToken(bearer)
        do {
            _ = try await userService.updateProfile(fcmToken: token)
            PushRegistrationDebug.recordUploadSuccess()
            refreshNote = "Uploaded OK."
        } catch {
            PushRegistrationDebug.recordUploadFailure(error.localizedDescription)
            refreshNote = "Upload failed — see Last API upload."
        }
        loadStaticState()
    }
}
