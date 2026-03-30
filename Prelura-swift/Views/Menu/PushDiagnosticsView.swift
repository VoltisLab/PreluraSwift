import SwiftUI
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

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

    var body: some View {
        List {
            Section {
                Text(
                    "If you see Authorized, an FCM token, and Last API upload: OK, the app and API did their job. No banner almost always means Firebase has not linked Apple Push to the iOS app com.prelura.preloved (Flutter uses com.prelura.app — that can work while Swift does not).\n\n"
                        + "Next: (1) Run Send server test push below and background the app before it runs. (2) If the log says API OK but no alert appears, open Firebase → project prelura-app → Project settings → Your apps → iOS com.prelura.preloved → Cloud Messaging → upload the APNs .p8 key. (3) Or use Firebase Send test message with your copied token; if that fails, the fix is Apple/Firebase, not reinstalling Prelura."
                )
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .listRowBackground(Color.clear)
            } header: {
                Text("Read this if push never shows")
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

                Button {
                    scheduleServerTestPushAfterDelay()
                } label: {
                    HStack {
                        if let c = testPushCountdown {
                            Text("Test push in \(c)s…")
                        } else {
                            Text("Send server test push (waits 5s)")
                        }
                        if testPushBusy && testPushCountdown == nil { ProgressView() }
                    }
                }
                .disabled(!authService.isAuthenticated || testPushBusy)
            } footer: {
                Text("If “No FCM token yet” persists on a real iPhone, check Settings → Prelura → Notifications and Xcode Signing → Push capability. Deploy the latest API so GraphQL SendMessage schedules pushes.")
            }

            Section {
                Text(
                    "Your screen shows the hard part (device + API) is working. Alerts are delivered by Apple via Firebase.\n\n"
                        + "1) Firebase Console → project prelura-app → Project settings → Your apps → select the iOS app with bundle ID com.prelura.preloved → Cloud Messaging → upload your APNs Authentication Key (.p8). Same .p8 as Flutter is fine; it must be attached to this app entry, not only com.prelura.app.\n\n"
                        + "2) Firebase → Send test message → paste the token you copied; background the app first. If the test fails, fix Apple/Firebase — not the Prelura API.\n\n"
                        + "3) In Prelura notification settings, ensure push is on. For chat, background the app — the server may skip FCM while that chat is open."
                )
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .listRowBackground(Color.clear)
            } header: {
                Text("Upload OK but still no alerts?")
            }

            Section {
                if traceEntries.isEmpty {
                    Text("No events recorded yet. Use the app, grant notifications, and run a server test — lines appear here automatically.")
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
                Text("Shows what the app knows: Firebase setup, APNs/FCM errors, token uploads, when a remote message arrives (background), when a banner is shown (foreground), and tap events. If the server sends FCM but Apple never delivers, you may see no “remote” or “present” lines — fix Firebase APNs for com.prelura.preloved. Server-side FCM rejections only appear if the API returns an error (e.g. debug test push message).")
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Push diagnostics")
        .navigationBarTitleDisplayMode(.inline)
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

    private func scheduleServerTestPushAfterDelay() {
        guard authService.isAuthenticated, let bearer = authService.authToken, !testPushBusy else { return }
        testPushBusy = true
        NotificationDebugLog.append(source: "diagnostics", message: "Scheduled server test push — 5s countdown…", isError: false)
        Task { @MainActor in
            defer {
                testPushBusy = false
                testPushCountdown = nil
            }
            for s in stride(from: 5, through: 1, by: -1) {
                testPushCountdown = s
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            testPushCountdown = nil
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
            Messaging.messaging().token { tok, err in
                if let err {
                    cont.resume(returning: nil)
                    DispatchQueue.main.async {
                        self.refreshNote = "Messaging.token: \(err.localizedDescription)"
                    }
                    NotificationDebugLog.append(
                        source: "diagnostics",
                        message: "Manual refresh Messaging.token error: \(err.localizedDescription)",
                        isError: true
                    )
                    return
                }
                cont.resume(returning: tok)
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
