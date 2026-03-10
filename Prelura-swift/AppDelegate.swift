import UIKit
import UserNotifications

/// Name for the notification posted when user taps a push notification (payload in userInfo).
let kNotificationTapPayloadKey = "payload"

extension Notification.Name {
    static let preluraNotificationTapped = Notification.Name("PreluraNotificationTapped")
    /// Posted when vacation mode (or other profile flags) are updated so Profile can refresh.
    static let preluraUserProfileDidUpdate = Notification.Name("PreluraUserProfileDidUpdate")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
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
