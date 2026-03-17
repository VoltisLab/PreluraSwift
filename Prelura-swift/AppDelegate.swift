import UIKit
import UserNotifications

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

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissionAndRegister(application: application)
        return true
    }

    /// Request notification authorization and register for remote notifications so we receive APNs device token.
    private func requestNotificationPermissionAndRegister(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }

    /// Store device token and notify so the app can send it to the backend when the user is logged in.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: kDeviceTokenKey)
        NotificationCenter.default.post(name: .preluraDeviceTokenDidUpdate, object: nil)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("Prelura: Failed to register for remote notifications: \(error.localizedDescription)")
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
}
