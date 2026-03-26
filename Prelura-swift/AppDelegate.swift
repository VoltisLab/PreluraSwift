import OSLog
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

private let pushBootstrapLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Prelura", category: "PushBootstrap")

/// Name for the notification posted when user taps a push notification (payload in userInfo).
let kNotificationTapPayloadKey = "payload"

/// UserDefaults key for the current APNs device token (hex string). Used to send token to backend when user is logged in.
let kDeviceTokenKey = "prelura_device_token"

extension Notification.Name {
    static let preluraNotificationTapped = Notification.Name("PreluraNotificationTapped")
    /// Posted when a new APNs device token is received so the app can register it with the backend.
    static let preluraDeviceTokenDidUpdate = Notification.Name("PreluraDeviceTokenDidUpdate")
    /// Posted when vacation mode (or other profile flags) are updated so Profile can refresh.
    static let preluraUserProfileDidUpdate = Notification.Name("PreluraUserProfileDidUpdate")
    /// Posted when the user views a product so Discover (and Recently viewed) can refresh.
    static let preluraRecentlyViewedDidUpdate = Notification.Name("PreluraRecentlyViewedDidUpdate")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    /// Payload to route after splash: cold-open from push (`launchOptions`) or tap received while splash is visible (root `onReceive` cannot present yet).
    static var pendingPostSplashNotificationUserInfo: [AnyHashable: Any]?

    static func takePendingPostSplashNotificationUserInfo() -> [AnyHashable: Any]? {
        defer { pendingPostSplashNotificationUserInfo = nil }
        return pendingPostSplashNotificationUserInfo
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) as? [String: Any],
           let projectId = plist["PROJECT_ID"] as? String {
            pushBootstrapLog.info("Firebase PROJECT_ID=\(projectId, privacy: .public) — must match server GOOGLE_CRED_PROJECT_ID.")
            #if DEBUG
            print("[Push] Firebase PROJECT_ID=\(projectId)")
            #endif
        } else {
            pushBootstrapLog.error("GoogleService-Info.plist missing from app bundle — Firebase push will not work.")
        }
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Self.pendingPostSplashNotificationUserInfo = remote
        }
        requestNotificationPermissionAndRegister(application: application)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let ok: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: ok = true
            default: ok = false
            }
            guard ok else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
                // After Firebase/backend changes, FCM token can rotate; refresh and notify only if it changed
                // so we re-run updateProfile(fcmToken:) without spamming identical tokens each foreground.
                Messaging.messaging().token { token, error in
                    if let error {
                        pushBootstrapLog.error("Messaging.token() (foreground) error: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    guard let token, !token.isEmpty else { return }
                    let prev = UserDefaults.standard.string(forKey: kDeviceTokenKey)
                    if prev != token {
                        UserDefaults.standard.set(token, forKey: kDeviceTokenKey)
                        NotificationCenter.default.post(name: .preluraDeviceTokenDidUpdate, object: nil)
                    }
                }
            }
        }
    }

    /// Registers for APNs when already allowed; only prompts when status is `notDetermined`.
    private func requestNotificationPermissionAndRegister(application: UIApplication) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    application.registerForRemoteNotifications()
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                        DispatchQueue.main.async {
                            if granted {
                                application.registerForRemoteNotifications()
                            } else {
                                pushBootstrapLog.warning("User declined notification permission — enable in Settings → Prelura → Notifications.")
                            }
                        }
                    }
                case .denied:
                    pushBootstrapLog.warning("Notifications denied for Prelura — enable in Settings → Notifications.")
                @unknown default:
                    break
                }
            }
        }
    }

    /// Store device token and notify so the app can send it to the backend when the user is logged in.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        // Explicit fetch: delegate can lag; ensures UserDefaults + backend sync see a token.
        Messaging.messaging().token { token, error in
            if let token, !token.isEmpty {
                UserDefaults.standard.set(token, forKey: kDeviceTokenKey)
                NotificationCenter.default.post(name: .preluraDeviceTokenDidUpdate, object: nil)
            }
            if let error {
                pushBootstrapLog.error("Messaging.token() error: \(error.localizedDescription, privacy: .public)")
                #if DEBUG
                print("[Push] Messaging.token() error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        pushBootstrapLog.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        UserDefaults.standard.set(fcmToken, forKey: kDeviceTokenKey)
        NotificationCenter.default.post(name: .preluraDeviceTokenDidUpdate, object: nil)
        pushBootstrapLog.debug("FCM registration token refreshed (length \(fcmToken.count))")
        #if DEBUG
        print("[FCM TEST] Copy this token into Firebase → Send test message:\n\(fcmToken)")
        #endif
    }

    /// Called when user taps a notification (foreground or background). Post so SwiftUI can route.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(
            name: .preluraNotificationTapped,
            object: nil,
            userInfo: [kNotificationTapPayloadKey: userInfo]
        )
        completionHandler()
    }

    /// Show banner + sound when a notification arrives while the app is open (otherwise iOS stays silent).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}
