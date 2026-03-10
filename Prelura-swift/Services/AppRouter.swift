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

    /// Handle push notification payload (same keys as Flutter: page, object_id, conversation_id, title, is_offer, is_order).
    func handle(notificationPayload: [AnyHashable: Any]) {
        guard let page = notificationPayload["page"] as? String else { return }
        var dest: DeepLinkDestination?
        switch page {
        case "PRODUCT":
            if let objectId = notificationPayload["object_id"] as? String, let id = Int(objectId) {
                dest = .product(productId: id)
            } else if let objectId = notificationPayload["object_id"] as? Int {
                dest = .product(productId: objectId)
            }
        case "USER":
            if let username = notificationPayload["object_id"] as? String {
                dest = .user(username: username)
            }
        case "CONVERSATION", "OFFER", "ORDER":
            let convId: String? = {
                if let s = notificationPayload["conversation_id"] as? String { return s }
                if let i = notificationPayload["conversation_id"] as? Int { return String(i) }
                return nil
            }()
            if let convId = convId, let title = notificationPayload["title"] as? String {
                let isOffer: Bool = (notificationPayload["is_offer"] as? String)?.lowercased() == "true" || page == "OFFER"
                let isOrder: Bool = (notificationPayload["is_order"] as? String)?.lowercased() == "true" || page == "ORDER"
                dest = .conversation(conversationId: convId, username: title, isOffer: isOffer, isOrder: isOrder)
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

    func clearPending() {
        Task { @MainActor in
            self.pendingItem = nil
        }
    }
}
