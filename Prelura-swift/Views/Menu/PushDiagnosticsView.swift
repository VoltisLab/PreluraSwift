import SwiftUI
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

private struct DiagnosticLogEntry: Identifiable {
    let id = UUID()
    let text: String
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
    @State private var eventLog: [DiagnosticLogEntry] = []

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
                if eventLog.isEmpty {
                    Text("No test events yet — use the button above to run a server test.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                } else {
                    ForEach(eventLog) { entry in
                        Text(entry.text)
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .textSelection(.enabled)
                    }
                }
            } header: {
                Text("Notification test log")
            } footer: {
                Text("The API allows one server test push every 60 seconds per account. Background the app before the countdown ends to see the banner clearly.")
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Push diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadStaticState() }
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

    private func logEvent(_ msg: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let line = "\(f.string(from: Date()))  \(msg)"
        eventLog.insert(DiagnosticLogEntry(text: line), at: 0)
        if eventLog.count > 40 {
            eventLog.removeLast()
        }
    }

    private func scheduleServerTestPushAfterDelay() {
        guard authService.isAuthenticated, let bearer = authService.authToken, !testPushBusy else { return }
        testPushBusy = true
        logEvent("Scheduled server test push — 5s countdown…")
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
            logEvent("Calling sendDebugTestPush…")
            let userService = UserService()
            userService.updateAuthToken(bearer)
            do {
                let result = try await userService.sendDebugTestPush()
                if result.success {
                    logEvent("API OK — \(result.message ?? "sent")")
                } else {
                    logEvent("API: \(result.message ?? "failed")")
                }
            } catch {
                logEvent("API error: \(error.localizedDescription)")
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
                    return
                }
                cont.resume(returning: tok)
            }
        }

        guard let token, !token.isEmpty else {
            refreshNote = "FCM returned no token (APNs may not be registered — common on simulator or if Push capability is off)."
            loadStaticState()
            return
        }

        UserDefaults.standard.set(token, forKey: kDeviceTokenKey)
        NotificationCenter.default.post(name: .preluraDeviceTokenDidUpdate, object: nil)

        guard authService.isAuthenticated, let bearer = authService.authToken else {
            refreshNote = "Token received; sign in to upload to API."
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
