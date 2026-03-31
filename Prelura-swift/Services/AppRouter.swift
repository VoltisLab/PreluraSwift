import Combine
import Foundation
import SwiftUI

/// Destination opened from a deep link or push notification (matches Flutter notification_service routes).
enum DeepLinkDestination: Equatable {
    case product(productId: Int)
    case user(username: String)
    case conversation(conversationId: String, username: String, isOffer: Bool, isOrder: Bool)
    /// Push: order shipped / generic order tap when no chat thread id is present.
    case orderDetail(orderId: Int)
    /// Push: `ORDER_ISSUE` with buyer–seller order conversation id.
    case orderIssueSupport(conversationId: String, orderId: String?, peerUsername: String)
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

    private static func stringKey(_ any: AnyHashable) -> String {
        (any as? String) ?? String(describing: any)
    }

    /// Read notification payload values (FCM often sends strings; keys may vary in casing).
    static func pushValue(_ p: [AnyHashable: Any], _ key: String) -> Any? {
        if let v = p[AnyHashable(key)] { return v }
        let lower = key.lowercased()
        for (k, v) in p {
            let ks = stringKey(k)
            if ks.lowercased() == lower { return v }
        }
        return nil
    }

    static func pushString(_ p: [AnyHashable: Any], _ key: String) -> String? {
        guard let raw = pushValue(p, key) else { return nil }
        if let s = raw as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t.lowercased() == "none" { return nil }
            return t
        }
        if let i = raw as? Int { return String(i) }
        if let n = raw as? NSNumber { return n.stringValue }
        return nil
    }

    /// Parses booleans from FCM (`"True"`, `"1"`) and JSON types.
    static func pushTruthy(_ p: [AnyHashable: Any], _ key: String) -> Bool {
        guard let raw = pushValue(p, key) else { return false }
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n.boolValue }
        if let s = raw as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return ["true", "1", "yes"].contains(t)
        }
        return false
    }

    static func conversationIdFromPayload(_ p: [AnyHashable: Any]) -> String? {
        if let s = pushString(p, "conversation_id"), !s.isEmpty { return s }
        let page = pushString(p, "page")?.uppercased()
        if page == "CONVERSATION", let oid = pushString(p, "object_id"), !oid.isEmpty {
            return oid
        }
        return nil
    }

    /// Flattens FCM/APNs `userInfo` so backend custom keys are readable (top-level, nested `data`, JSON string, `google.c.fcm_data`).
    static func normalizedPushUserInfo(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
        var out: [String: Any] = [:]
        for (k, v) in userInfo {
            out[stringKey(k)] = v
        }
        if let nested = userInfo[AnyHashable("data")] as? [String: Any] {
            for (k, v) in nested {
                out[String(describing: k)] = v
            }
        }
        if let dataStr = userInfo[AnyHashable("data")] as? String,
           let d = dataStr.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            for (k, v) in obj {
                out[String(describing: k)] = v
            }
        }
        for (k, v) in userInfo {
            let ks = stringKey(k)
            guard ks.contains("fcm_data") || ks == "google.c.fcm_data" else { continue }
            guard let s = v as? String,
                  let d = s.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
            for (kk, vv) in obj {
                out[String(describing: kk)] = vv
            }
        }
        return Dictionary(uniqueKeysWithValues: out.map { (AnyHashable($0.key), $0.value) })
    }

    /// Handle push notification payload (same keys as Flutter: page, object_id, conversation_id, title, is_offer, is_order).
    /// Also accepts `username` / `sender_username` for chat; `title` may come from aps.alert.
    func handle(notificationPayload: [AnyHashable: Any]) {
        let p = Self.normalizedPushUserInfo(notificationPayload)
        var page = Self.pushString(p, "page")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if page?.isEmpty != false {
            let hasConv = Self.conversationIdFromPayload(p) != nil
            if hasConv { page = "MESSAGE" }
        }
        guard let pageRaw = page, !pageRaw.isEmpty else { return }
        let pageUpper = pageRaw.uppercased()

        var dest: DeepLinkDestination?

        switch pageUpper {
        case "ORDER_ISSUE":
            if let cid = Self.conversationIdFromPayload(p), Int(cid) != nil {
                dest = .orderIssueSupport(
                    conversationId: cid,
                    orderId: Self.pushString(p, "order_id"),
                    peerUsername: Self.pushString(p, "title")
                        ?? Self.pushString(p, "username")
                        ?? Self.pushString(p, "sender_username")
                        ?? "Order"
                )
            } else if let oid = Self.pushString(p, "order_id").flatMap({ Int($0) }) {
                dest = .orderDetail(orderId: oid)
            }

        case "PRODUCT", "PRODUCT_FLAG", "LISTING":
            if let s = Self.pushString(p, "object_id"), let id = Int(s) {
                dest = .product(productId: id)
            } else if let id = Self.pushValue(p, "object_id") as? Int {
                dest = .product(productId: id)
            }

        case "USER", "PROFILE", "FOLLOW":
            if let username = Self.pushString(p, "object_id") {
                dest = .user(username: username)
            }

        case "ORDER":
            if let cid = Self.conversationIdFromPayload(p), !cid.isEmpty {
                let peerName: String = {
                    if let t = Self.pushString(p, "title"), !t.isEmpty { return t }
                    if let u = Self.pushString(p, "username"), !u.isEmpty { return u }
                    if let s = Self.pushString(p, "sender_username"), !s.isEmpty { return s }
                    return "Chat"
                }()
                let isOffer = Self.pushTruthy(p, "is_offer")
                let isOrder = true
                dest = .conversation(conversationId: cid, username: peerName, isOffer: isOffer, isOrder: isOrder)
            } else if let oid = Self.pushString(p, "order_id").flatMap({ Int($0) })
                ?? Self.pushString(p, "object_id").flatMap({ Int($0) }) {
                dest = .orderDetail(orderId: oid)
            }

        case "CONVERSATION", "OFFER", "MESSAGE", "CHAT":
            guard let convId = Self.conversationIdFromPayload(p), !convId.isEmpty else { break }
            let peerName: String = {
                if let t = Self.pushString(p, "title"), !t.isEmpty { return t }
                if let u = Self.pushString(p, "username"), !u.isEmpty { return u }
                if let s = Self.pushString(p, "sender_username"), !s.isEmpty { return s }
                if let aps = p[AnyHashable("aps")] as? [String: Any],
                   let alert = aps["alert"] as? [String: Any],
                   let t = alert["title"] as? String, !t.isEmpty {
                    return t
                }
                return "Chat"
            }()
            let isOffer = Self.pushTruthy(p, "is_offer") || pageUpper == "OFFER"
            let isOrder = Self.pushTruthy(p, "is_order") || pageUpper == "ORDER"
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
