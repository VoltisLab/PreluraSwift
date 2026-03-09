import Foundation

/// Notification preferences (in-app/push and email). Matches Flutter NotificationPreference + NotificationsPreferenceInputType.
struct NotificationPreference {
    var isPushNotification: Bool
    var isEmailNotification: Bool
    var inappNotifications: NotificationSubPreferences
    var emailNotifications: NotificationSubPreferences
}

struct NotificationSubPreferences {
    var likes: Bool
    var messages: Bool
    var newFollowers: Bool
    var profileView: Bool
}

@MainActor
class NotificationService {
    private var client: GraphQLClient

    init(client: GraphQLClient? = nil) {
        self.client = client ?? GraphQLClient()
        if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            self.client.setAuthToken(token)
        }
    }

    func updateAuthToken(_ token: String?) {
        client.setAuthToken(token)
    }

    /// Fetch notification preference. Matches Flutter getNotificationPreference.
    func getNotificationPreference() async throws -> NotificationPreference {
        let query = """
        query NotificationPreference {
          notificationPreference {
            isPushNotification
            isEmailNotification
            inappNotifications
            emailNotifications
          }
        }
        """
        struct Payload: Decodable {
            let notificationPreference: RawPreference?
        }
        struct RawPreference: Decodable {
            let isPushNotification: Bool?
            let isEmailNotification: Bool?
            let inappNotifications: String?
            let emailNotifications: String?
        }
        let response: Payload = try await client.execute(query: query, variables: nil, responseType: Payload.self)
        guard let raw = response.notificationPreference else {
            throw NSError(domain: "NotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No preference returned"])
        }
        return NotificationPreference(
            isPushNotification: raw.isPushNotification ?? true,
            isEmailNotification: raw.isEmailNotification ?? true,
            inappNotifications: parseSubPreferences(raw.inappNotifications),
            emailNotifications: parseSubPreferences(raw.emailNotifications)
        )
    }

    /// Parse JSON string from API (keys: likes, new_followers, profile_view, messages). Matches Flutter _parseNotifications.
    private func parseSubPreferences(_ jsonString: String?) -> NotificationSubPreferences {
        guard let str = jsonString, !str.isEmpty,
              let data = str.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return NotificationSubPreferences(likes: true, messages: true, newFollowers: true, profileView: true)
        }
        return NotificationSubPreferences(
            likes: (json["likes"] as? Bool) ?? true,
            messages: (json["messages"] as? Bool) ?? true,
            newFollowers: (json["new_followers"] as? Bool) ?? true,
            profileView: (json["profile_view"] as? Bool) ?? true
        )
    }

    /// Update preference on backend. Matches Flutter updateNotificationPreference (same mutation + input shape).
    func updateNotificationPreference(
        isPushNotification: Bool? = nil,
        isEmailNotification: Bool? = nil,
        inappNotifications: NotificationSubPreferences? = nil,
        emailNotifications: NotificationSubPreferences? = nil,
        isSilentModeOn: Bool = false
    ) async throws {
        let current = try await getNotificationPreference()
        let push = isPushNotification ?? current.isPushNotification
        let email = isEmailNotification ?? current.isEmailNotification
        let inapp = inappNotifications ?? current.inappNotifications
        let emailPrefs = emailNotifications ?? current.emailNotifications

        let mutation = """
        mutation UpdateNotificationPreference(
          $isPushNotification: Boolean!
          $isEmailNotification: Boolean!
          $isSilentModeOn: Boolean!
          $inappNotification: NotificationsPreferenceInputType
          $emailNotification: NotificationsPreferenceInputType
        ) {
          updateNotificationPreference(
            isPushNotification: $isPushNotification
            isEmailNotification: $isEmailNotification
            isSilentModeOn: $isSilentModeOn
            inappNotifications: $inappNotification
            emailNotifications: $emailNotification
          ) {
            success
          }
        }
        """
        let vars: [String: Any] = [
            "isPushNotification": push,
            "isEmailNotification": email,
            "isSilentModeOn": isSilentModeOn,
            "inappNotification": subPrefsToInput(inapp),
            "emailNotification": subPrefsToInput(emailPrefs)
        ]
        struct Payload: Decodable {
            let updateNotificationPreference: UpdateResult?
        }
        struct UpdateResult: Decodable {
            let success: Bool?
        }
        let response: Payload = try await client.execute(query: mutation, variables: vars, responseType: Payload.self)
        guard response.updateNotificationPreference?.success == true else {
            throw NSError(domain: "NotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Update failed"])
        }
    }

    private func subPrefsToInput(_ p: NotificationSubPreferences) -> [String: Any] {
        [
            "likes": p.likes,
            "messages": p.messages,
            "newFollowers": p.newFollowers,
            "profileView": p.profileView
        ]
    }
}
