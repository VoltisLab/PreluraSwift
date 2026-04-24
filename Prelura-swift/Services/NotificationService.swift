import Foundation

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
}

/// Sub-preferences for in-app or email (likes, messages, newFollowers, profileView). Matches Flutter NotificationsPreferenceInputType.
struct NotificationSubPreferences {
    var likes: Bool
    var messages: Bool
    var newFollowers: Bool
    var profileView: Bool
}

/// Full notification preference (push, email, inapp, email sub). Matches Flutter NotificationPreference / GraphQL NotificationPreferenceType.
struct NotificationPreference {
    var isPushNotification: Bool
    var isEmailNotification: Bool
    var inappNotifications: NotificationSubPreferences
    var emailNotifications: NotificationSubPreferences
}

/// Fetches in-app notifications and notification preference (matches Flutter notificationRepo).
final class NotificationService {
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

    // MARK: - Notification preference (settings)

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
            let notificationPreference: RawPref?
        }
        struct RawPref: Decodable {
            let isPushNotification: Bool?
            let isEmailNotification: Bool?
            let inappNotifications: String?
            let emailNotifications: String?
        }
        let response: Payload = try await client.execute(query: query, variables: nil, responseType: Payload.self)
        guard let raw = response.notificationPreference else {
            throw NSError(domain: "NotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No notification preference"])
        }
        let inapp = parseSubPref(raw.inappNotifications) ?? NotificationSubPreferences(likes: true, messages: true, newFollowers: true, profileView: true)
        let email = parseSubPref(raw.emailNotifications) ?? NotificationSubPreferences(likes: true, messages: true, newFollowers: true, profileView: true)
        return NotificationPreference(
            isPushNotification: raw.isPushNotification ?? true,
            isEmailNotification: raw.isEmailNotification ?? true,
            inappNotifications: inapp,
            emailNotifications: email
        )
    }

    private func parseSubPref(_ jsonString: String?) -> NotificationSubPreferences? {
        guard let s = jsonString, !s.isEmpty, let data = s.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return NotificationSubPreferences(
            likes: (json["likes"] as? Bool) ?? true,
            messages: (json["messages"] as? Bool) ?? true,
            newFollowers: (json["new_followers"] as? Bool) ?? true,
            profileView: (json["profile_view"] as? Bool) ?? true
        )
    }

    private func subPrefToJson(_ sub: NotificationSubPreferences) -> [String: Any] {
        ["likes": sub.likes, "newFollowers": sub.newFollowers, "profileView": sub.profileView, "messages": sub.messages]
    }

    func updateNotificationPreference(isPushNotification: Bool? = nil, isEmailNotification: Bool? = nil, inappNotifications: NotificationSubPreferences? = nil, emailNotifications: NotificationSubPreferences? = nil) async throws {
        let current = try await getNotificationPreference()
        let push = isPushNotification ?? current.isPushNotification
        let email = isEmailNotification ?? current.isEmailNotification
        let inapp = inappNotifications ?? current.inappNotifications
        let emailSub = emailNotifications ?? current.emailNotifications
        let mutation = """
        mutation UpdateNotificationPreference($isPushNotification: Boolean!, $isEmailNotification: Boolean!, $isSilentModeOn: Boolean!, $inappNotification: NotificationsPreferenceInputType, $emailNotification: NotificationsPreferenceInputType) {
          updateNotificationPreference(
            isPushNotification: $isPushNotification,
            isEmailNotification: $isEmailNotification,
            isSilentModeOn: $isSilentModeOn,
            inappNotifications: $inappNotification,
            emailNotifications: $emailNotification
          ) {
            success
          }
        }
        """
        let inappDict = subPrefToJson(inapp)
        let emailDict = subPrefToJson(emailSub)
        let variables: [String: Any] = [
            "isPushNotification": push,
            "isEmailNotification": email,
            "isSilentModeOn": false,
            "inappNotification": inappDict,
            "emailNotification": emailDict
        ]
        struct Payload: Decodable {
            let updateNotificationPreference: UpdateResult?
        }
        struct UpdateResult: Decodable {
            let success: Bool?
        }
        let response: Payload = try await client.execute(query: mutation, variables: variables, responseType: Payload.self)
        if response.updateNotificationPreference?.success != true {
            throw NSError(domain: "NotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update preference"])
        }
    }

    // MARK: - Notifications list

    /// Query notifications with pagination. Matches existing backend query Notifications(pageCount, pageNumber).
    func getNotifications(pageCount: Int = 15, pageNumber: Int = 1) async throws -> (notifications: [AppNotification], totalNumber: Int) {
        let query = """
        query Notifications($pageCount: Int, $pageNumber: Int) {
          notifications(pageCount: $pageCount, pageNumber: $pageNumber) {
            id
            message
            model
            modelId
            modelGroup
            isRead
            createdAt
            meta
            sender {
              username
              profilePictureUrl
              thumbnailUrl
            }
          }
          notificationsTotalNumber
        }
        """
        struct Payload: Decodable {
            let notifications: [RawNotification]?
            let notificationsTotalNumber: Int?
        }
        struct RawNotification: Decodable {
            let id: String
            let message: String?
            let model: String?
            let modelId: String?
            let modelGroup: String?
            let isRead: Bool?
            let createdAt: String?
            let metaDict: [String: String]?
            let productThumbnailUrl: String?
            let relatedProductIsMysteryBox: Bool?
            let sender: RawSender?
            enum CodingKeys: String, CodingKey {
                case id, message, model, modelId, modelGroup, isRead, createdAt, meta, sender
                case productThumbnailUrl, relatedProductIsMysteryBox
            }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                let idValue: String
                if let s = try? c.decode(String.self, forKey: .id) { idValue = s }
                else if let i = try? c.decode(Int.self, forKey: .id) { idValue = String(i) }
                else { idValue = "" }
                id = idValue
                message = try c.decodeIfPresent(String.self, forKey: .message)
                model = try c.decodeIfPresent(String.self, forKey: .model)
                modelId = try c.decodeIfPresent(String.self, forKey: .modelId)
                modelGroup = try c.decodeIfPresent(String.self, forKey: .modelGroup)
                if let b = try? c.decode(Bool.self, forKey: .isRead) {
                    isRead = b
                } else if let i = try? c.decode(Int.self, forKey: .isRead) {
                    isRead = i != 0
                } else if let s = try? c.decode(String.self, forKey: .isRead) {
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if ["true", "1", "yes", "y"].contains(t) { isRead = true }
                    else if ["false", "0", "no", "n"].contains(t) { isRead = false }
                    else { isRead = nil }
                } else {
                    isRead = nil
                }
                createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
                sender = try c.decodeIfPresent(RawSender.self, forKey: .sender)
                productThumbnailUrl = try c.decodeIfPresent(String.self, forKey: .productThumbnailUrl)
                relatedProductIsMysteryBox = try c.decodeIfPresent(Bool.self, forKey: .relatedProductIsMysteryBox)

                if c.contains(.meta) {
                    if try c.decodeNil(forKey: .meta) {
                        metaDict = nil
                    } else if let s = try? c.decode(String.self, forKey: .meta), !s.isEmpty {
                        metaDict = Self.parseMetaFromString(s)
                    } else if let nested = try? c.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .meta) {
                        metaDict = Self.flattenMetaContainer(nested)
                    } else {
                        metaDict = nil
                    }
                } else {
                    metaDict = nil
                }
            }

            private static func parseMetaFromString(_ s: String) -> [String: String]? {
                guard let data = s.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                return stringifyMetaObject(json)
            }

            /// Converts JSON meta to flat `[String: String]` without `String(describing:)` (which breaks nested image objects).
            private static func stringifyMetaObject(_ json: [String: Any]) -> [String: String] {
                var out: [String: String] = [:]
                for (k, v) in json {
                    switch v {
                    case let s as String:
                        out[k] = s
                    case let i as Int:
                        out[k] = String(i)
                    case let b as Bool:
                        out[k] = b ? "true" : "false"
                    case let d as Double:
                        out[k] = String(d)
                    case let nested as [String: Any]:
                        if let url = ProductListImageURL.preferredString(fromJSONObject: nested) {
                            out[k] = url
                        } else if let data = try? JSONSerialization.data(withJSONObject: nested),
                                  let jsonStr = String(data: data, encoding: .utf8) {
                            out[k] = jsonStr
                        }
                    default:
                        break
                    }
                }
                return out
            }

            private static func flattenMetaContainer(_ nested: KeyedDecodingContainer<DynamicCodingKeys>) -> [String: String] {
                var out: [String: String] = [:]
                for key in nested.allKeys {
                    if let s = try? nested.decode(String.self, forKey: key) {
                        out[key.stringValue] = s
                    } else if let i = try? nested.decode(Int.self, forKey: key) {
                        out[key.stringValue] = String(i)
                    } else if let b = try? nested.decode(Bool.self, forKey: key) {
                        out[key.stringValue] = b ? "true" : "false"
                    } else if let d = try? nested.decode(Double.self, forKey: key) {
                        out[key.stringValue] = String(d)
                    } else if let sub = try? nested.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: key) {
                        let inner = Self.flattenMetaContainer(sub)
                        if let resolved = ProductListImageURL.preferredString(fromStringKeyedJSON: inner) {
                            out[key.stringValue] = resolved
                        } else {
                            for (ik, iv) in inner {
                                out["\(key.stringValue).\(ik)"] = iv
                            }
                        }
                    }
                }
                return out
            }
        }
        struct RawSender: Decodable {
            let username: String?
            let profilePictureUrl: String?
            let thumbnailUrl: String?
        }
        let variables: [String: Any] = ["pageCount": pageCount, "pageNumber": pageNumber]
        let response: Payload = try await client.execute(query: query, variables: variables, responseType: Payload.self)
        let list = response.notifications ?? []
        let total = response.notificationsTotalNumber ?? 0
        let parsed = list.map { raw in
            let createdAt: Date? = {
                guard let s = raw.createdAt else { return nil }
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = iso.date(from: s) { return d }
                iso.formatOptions = [.withInternetDateTime]
                return iso.date(from: s)
            }()
            return AppNotification(
                id: raw.id,
                sender: raw.sender.map { s in
                    AppNotification.NotificationSender(
                        username: s.username,
                        profilePictureUrl: s.profilePictureUrl,
                        thumbnailUrl: s.thumbnailUrl
                    )
                },
                message: raw.message ?? "",
                model: raw.model ?? "",
                modelId: raw.modelId,
                modelGroup: raw.modelGroup,
                isRead: raw.isRead ?? false,
                createdAt: createdAt,
                meta: raw.metaDict,
                productThumbnailUrl: raw.productThumbnailUrl,
                relatedProductIsMysteryBox: raw.relatedProductIsMysteryBox
            )
        }
        return (parsed, total)
    }

    /// Unread notifications that belong on the bell list (excludes fresh chat; matches `shouldShowOnNotificationsPage`).
    func countUnreadBellEligibleNotifications(pageCount: Int = 15, maxPages: Int = 8) async throws -> Int {
        var count = 0
        for page in 1...maxPages {
            let (batch, _) = try await getNotifications(pageCount: pageCount, pageNumber: page)
            for n in batch where n.shouldCountTowardBellBadge {
                count += 1
            }
            if batch.count < pageCount { break }
        }
        return count
    }

    /// Marks every unread notification that counts toward the home bell badge as read (same rules and pagination cap as `countUnreadBellEligibleNotifications`). On iOS, ``NotificationsListView`` calls this on the **second** consecutive visit to the list (or after individual row taps via `readNotifications`); the first visit only primes-no mutation-so “accent = unread” until tap or second open.
    func markAllBellEligibleUnreadRead(pageCount: Int = 40, maxPages: Int = 6) async throws {
        var ids: [Int] = []
        for page in 1...maxPages {
            let (batch, _) = try await getNotifications(pageCount: pageCount, pageNumber: page)
            for n in batch where n.shouldCountTowardBellBadge {
                if let id = n.bellNotificationDatabaseIntId { ids.append(id) }
            }
            if batch.count < pageCount { break }
        }
        guard !ids.isEmpty else { return }
        _ = try await readNotifications(notificationIds: ids)
    }

    /// Mark notifications as read. Matches Flutter readNotification(notificationIds).
    func readNotifications(notificationIds: [Int]) async throws -> Bool {
        guard !notificationIds.isEmpty else { return true }
        let mutation = """
        mutation ReadNotification($notificationId: [Int]) {
          readNotifications(notificationId: $notificationId) {
            success
          }
        }
        """
        let variables: [String: Any] = ["notificationId": notificationIds]
        struct Payload: Decodable { let readNotifications: ReadResult? }
        struct ReadResult: Decodable { let success: Bool? }
        let response: Payload = try await client.execute(query: mutation, variables: variables, responseType: Payload.self)
        let ok = response.readNotifications?.success ?? false
        if !ok {
            throw NSError(
                domain: "NotificationService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "readNotifications returned success=false"]
            )
        }
        return true
    }
    
    /// Delete a notification. Matches Flutter deleteNotification(notificationId).
    func deleteNotification(notificationId: Int) async throws -> Bool {
        let mutation = """
        mutation DeleteNotification($notificationId: Int!) {
          deleteNotification(notificationId: $notificationId) {
            success
          }
        }
        """
        let variables: [String: Any] = ["notificationId": notificationId]
        struct Payload: Decodable { let deleteNotification: DeleteResult? }
        struct DeleteResult: Decodable { let success: Bool? }
        let response: Payload = try await client.execute(query: mutation, variables: variables, responseType: Payload.self)
        return response.deleteNotification?.success ?? false
    }

    // MARK: - Push notification device token (APNs)

    /// Register the APNs device token with the backend so the server can send push notifications to this device.
    /// Mutation name and arguments must match the backend schema (same as used by Flutter for FCM). If the backend uses a different mutation (e.g. savePushToken), update the mutation string below.
    func registerDeviceToken(token: String) async throws {
        guard !token.isEmpty else { return }
        let mutation = """
        mutation RegisterDeviceToken($token: String!, $platform: String!) {
          registerDevice(token: $token, platform: $platform) {
            success
          }
        }
        """
        let variables: [String: Any] = ["token": token, "platform": "ios"]
        struct Payload: Decodable {
            let registerDevice: Result?
            struct Result: Decodable { let success: Bool? }
        }
        do {
            let response: Payload = try await client.execute(query: mutation, variables: variables, responseType: Payload.self)
            if response.registerDevice?.success != true {
                throw NSError(domain: "NotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to register device token"])
            }
        } catch {
            #if DEBUG
            print("Wearhouse: registerDeviceToken failed (backend may use a different mutation name): \(error)")
            #endif
            throw error
        }
    }
}
