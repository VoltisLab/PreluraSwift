import Foundation
import UserNotifications

/// Local reminder when a seller schedules a listing (optional; listing also activates when you open the app after the chosen time).
enum ListingGoLiveReminder {
    private static func requestId(productId: Int) -> String {
        "com.prelura.scheduledListing.\(productId)"
    }

    /// Schedules a one-shot notification at `fireDate` (device timezone). No-op if permission denied or date is not in the future.
    static func schedule(productId: Int, fireDate: Date, listingTitle: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        let updated = await center.notificationSettings()
        guard updated.authorizationStatus == .authorized || updated.authorizationStatus == .provisional else {
            return
        }
        guard fireDate.timeIntervalSinceNow > 60 else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.string("Your listing")
        let trimmed = listingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = trimmed.count > 80 ? String(trimmed.prefix(77)) + "…" : trimmed
        content.body = String(format: L10n.string("\"%@\" should appear on your profile around this time. Open Prelura to refresh your shop."), displayTitle)
        content.sound = .default

        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = requestId(productId: productId)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(req)
    }
}
