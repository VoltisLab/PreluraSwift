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

    var body: some View {
        List {
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

                if !refreshNote.isEmpty {
                    Text(refreshNote)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            } footer: {
                Text("If “No FCM token yet” persists on a real iPhone, check Settings → Prelura → Notifications and Xcode Signing → Push capability. Deploy the latest API so GraphQL SendMessage schedules pushes.")
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
