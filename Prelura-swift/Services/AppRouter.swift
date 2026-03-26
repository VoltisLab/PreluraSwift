import Combine
import Foundation
import SwiftUI

/// Destination opened from a deep link or push notification (matches Flutter notification_service routes).
enum DeepLinkDestination: Equatable {
    case product(productId: Int)
    case user(username: String)
    case conversation(conversationId: String, username: String, isOffer: Bool, isOrder: Bool)
}

/// Wrapper so we can use fullScreenCover(item:) with optional DeepLinkDestination.
struct DeepLinkDestinationItem: Identifiable {
    let id = UUID()
    let destination: DeepLinkDestination
}

/// Handles deep links (URL scheme / universal links) and push notification tap payloads; holds pending destination for the UI to present.
final class AppRouter: ObservableObject {
    @Published var pendingItem: DeepLinkDestinationItem?

    /// Handle URL (e.g. prelura://product/123, prelura://user/john, prelura://chat/456?username=john&is_offer=true).
    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return
        }
        let pathComponents = components.path.split(separator: "/").map(String.init)
        var dest: DeepLinkDestination?
        switch host.lowercased() {
        case "product":
            if let idStr = pathComponents.first, let id = Int(idStr) {
                dest = .product(productId: id)
            }
        case "user", "profile":
            if let username = pathComponents.first, !username.isEmpty {
                dest = .user(username: username)
            }
        case "chat", "conversation":
            if let id = pathComponents.first {
                let username = components.queryItems?.first(where: { $0.name == "username" })?.value ?? ""
                let isOffer = (components.queryItems?.first(where: { $0.name == "is_offer" })?.value ?? "false").lowercased() == "true"
                let isOrder = (components.queryItems?.first(where: { $0.name == "is_order" })?.value ?? "false").lowercased() == "true"
                dest = .conversation(conversationId: String(id), username: username, isOffer: isOffer, isOrder: isOrder)
            }
        default:
            break
        }
        if let d = dest {
            Task { @MainActor in
                self.pendingItem = DeepLinkDestinationItem(destination: d)
            }
        }
    }

    /// Flattens FCM/APNs `userInfo` so backend custom keys are readable (top-level, nested `data`, or JSON string).
    static func normalizedPushUserInfo(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
        var out: [String: Any] = [:]
        for (key, value) in userInfo {
            guard let k = key as? String else { continue }
            out[k] = value
        }
        if let nested = userInfo[AnyHashable("data")] as? [String: Any] {
            for (k, v) in nested { out[k] = v }
        }
        if let dataStr = userInfo[AnyHashable("data")] as? String,
           let d = dataStr.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            for (k, v) in obj { out[k] = v }
        }
        return Dictionary(uniqueKeysWithValues: out.map { (AnyHashable($0.key), $0.value) })
    }

    /// Handle push notification payload (same keys as Flutter: page, object_id, conversation_id, title, is_offer, is_order).
    /// Also accepts `username` / `sender_username` for chat; `title` may come from aps.alert.
    func handle(notificationPayload: [AnyHashable: Any]) {
        let p = Self.normalizedPushUserInfo(notificationPayload)
        var page = (p["page"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if page?.isEmpty != false {
            let hasConv = (p["conversation_id"] as? String).map { !$0.isEmpty } == true
                || p["conversation_id"] as? Int != nil
            if hasConv { page = "MESSAGE" }
        }
        guard let page, !page.isEmpty else { return }
        var dest: DeepLinkDestination?
        switch page.uppercased() {
        case "PRODUCT":
            if let objectId = p["object_id"] as? String, let id = Int(objectId) {
                dest = .product(productId: id)
            } else if let objectId = p["object_id"] as? Int {
                dest = .product(productId: objectId)
            }
        case "USER":
            if let username = p["object_id"] as? String {
                dest = .user(username: username)
            }
        case "CONVERSATION", "OFFER", "ORDER", "MESSAGE", "CHAT":
            let convId: String? = {
                if let s = p["conversation_id"] as? String, !s.isEmpty { return s }
                if let i = p["conversation_id"] as? Int { return String(i) }
                return nil
            }()
            guard let convId, !convId.isEmpty else { break }
            let peerName: String = {
                if let t = p["title"] as? String, !t.isEmpty { return t }
                if let u = p["username"] as? String, !u.isEmpty { return u }
                if let s = p["sender_username"] as? String, !s.isEmpty { return s }
                if let aps = p["aps"] as? [String: Any],
                   let alert = aps["alert"] as? [String: Any],
                   let t = alert["title"] as? String, !t.isEmpty { return t }
                return "Chat"
            }()
            let pageUpper = page.uppercased()
            let isOffer: Bool = (p["is_offer"] as? String)?.lowercased() == "true" || pageUpper == "OFFER"
            let isOrder: Bool = (p["is_order"] as? String)?.lowercased() == "true" || pageUpper == "ORDER"
            dest = .conversation(conversationId: convId, username: peerName, isOffer: isOffer, isOrder: isOrder)
        default:
            break
        }
        if let d = dest {
            Task { @MainActor in
                self.pendingItem = DeepLinkDestinationItem(destination: d)
            }
        }
    }

    func clearPending() {
        Task { @MainActor in
            self.pendingItem = nil
        }
    }
}
