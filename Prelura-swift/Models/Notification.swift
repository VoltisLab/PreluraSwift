import Foundation

/// In-app notification (matches Flutter NotificationModel / GraphQL NotificationType).
struct AppNotification: Identifiable {
    let id: String
    let sender: NotificationSender?
    let message: String
    let model: String
    let modelId: String?
    let modelGroup: String?
    let isRead: Bool
    let createdAt: Date?
    let meta: [String: String]?

    struct NotificationSender {
        let username: String?
        let profilePictureUrl: String?
    }
}

extension AppNotification {
    /// Chat / DM rows (new message, reactions) stay out of the bell list until they are unread this long.
    private static let chatNotificationMinAgeToShow: TimeInterval = 30 * 60

    /// Matches `model_group == "Chat"` from the backend (message + reaction pushes).
    var isChatCentricNotification: Bool {
        (modelGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Chat") == .orderedSame
    }

    /// Bell list + notification detail list: hide fresh chat noise; inbox tab holds the unread counter.
    func shouldShowOnNotificationsPage(referenceDate: Date = Date()) -> Bool {
        guard isChatCentricNotification else { return true }
        if isRead { return false }
        guard let created = createdAt else { return true }
        return referenceDate.timeIntervalSince(created) >= Self.chatNotificationMinAgeToShow
    }

    var shouldCountTowardBellBadge: Bool {
        shouldShowOnNotificationsPage() && !isRead
    }
}
