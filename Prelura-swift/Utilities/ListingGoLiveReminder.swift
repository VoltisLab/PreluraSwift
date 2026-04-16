import Foundation
import UserNotifications

/// Local notification when a scheduled listing’s go-live time is reached. Tap / “View” opens Profile and the listing.
enum ListingGoLiveReminder {
    static let notificationCategoryId = "SCHEDULED_LISTING_READY"
    private static let viewListingActionId = "VIEW_NEW_LISTING"

    private static func requestId(productId: Int) -> String {
        "com.prelura.scheduledListing.\(productId)"
    }

    /// Call once at launch so the notification shows a “View” action and routes correctly when tapped.
    static func registerNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: viewListingActionId,
            title: L10n.string("View"),
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: notificationCategoryId,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Schedules a one-shot notification at `fireDate`. No-op if permission denied or date is too soon.
    static func schedule(productId: Int, fireDate: Date, listingTitle: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        let updated = await center.notificationSettings()
        guard updated.authorizationStatus == .authorized || updated.authorizationStatus == .provisional else {
            return
        }
        guard fireDate.timeIntervalSinceNow > 60 else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.string("Your post is ready")
        let trimmed = listingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = trimmed.count > 80 ? String(trimmed.prefix(77)) + "…" : trimmed
        content.body = String(format: L10n.string("“%@” is live. Tap to open your profile and view it."), displayTitle)
        content.sound = .default
        content.categoryIdentifier = notificationCategoryId
        content.userInfo = [
            "page": "SCHEDULED_LISTING_READY",
            "object_id": String(productId)
        ]

        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = requestId(productId: productId)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(req)
    }

    /// Removes the pending reminder (e.g. after the app activated the listing early).
    static func cancel(productId: Int) {
        let id = requestId(productId: productId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}
