import Foundation

/// App-wide constants. **Wearhouse** client; API hostnames below are the shared production backend (unchanged).
///
/// **Backend repository (do not modify from this app):**
/// https://github.com/VoltisLab/prelura-app
///
/// This app uses the backend's GraphQL API at the URLs below; schema and endpoints are shared with the Flutter app and other clients.
struct Constants {
    #if DEBUG
    /// Set **`true`** only when `prelura-app` is running on this Mac (`docker compose up -d`, GraphQL on **8006**). Default **`false`** uses production `prelura.voltislabs.uk` so Debug builds work without Docker; if you see “Unable to connect” on login, either start local Docker or leave this **`false`**.
    static let preluraUseLocalDockerBackend = false
    private static let localDockerRoot = "http://127.0.0.1:8006"
    private static let localDockerWSRoot = "ws://127.0.0.1:8006"
    #endif

    // GraphQL Endpoints (backend: https://github.com/VoltisLab/prelura-app)
    static var graphQLBaseURL: String {
        #if DEBUG
        if preluraUseLocalDockerBackend { return "\(localDockerRoot)/graphql/" }
        #endif
        return "https://prelura.voltislabs.uk/graphql/"
    }

    static var graphQLUploadURL: String {
        #if DEBUG
        if preluraUseLocalDockerBackend { return "\(localDockerRoot)/graphql/uploads/" }
        #endif
        return "https://prelura.voltislabs.uk/graphql/uploads/"
    }

    /// WebSocket for chat (same host as GraphQL so messages send/save to the same backend).
    static var chatWebSocketBaseURL: String {
        #if DEBUG
        if preluraUseLocalDockerBackend { return "\(localDockerWSRoot)/ws/chat/" }
        #endif
        return "wss://prelura.voltislabs.uk/ws/chat/"
    }

    /// Django `ConversationsConsumer`: inbox list sync + typing for threads the user is in (not per-room chat).
    static var conversationsWebSocketURL: String {
        #if DEBUG
        if preluraUseLocalDockerBackend { return "\(localDockerWSRoot)/ws/conversations/" }
        #endif
        return "wss://prelura.voltislabs.uk/ws/conversations/"
    }
    
    /// Live consumer site: help, legal, profiles, invites, and **generated share links** (`/item/*`, `/lookbook/*`). Must match production web.
    static let publicWebsiteBaseURL = "https://mywearhouse.co.uk"

    // About WEARHOUSE screen (flat list → WebView on mywearhouse.co.uk)
    static var aboutUsURL: String { "\(publicWebsiteBaseURL)/about" }
    static var termsAndConditionsURL: String { "\(publicWebsiteBaseURL)/about" }
    static var privacyPolicyURL: String { "\(publicWebsiteBaseURL)/privacy" }

    // MARK: - Help Centre (paths must exist on `publicWebsiteBaseURL`; each comment ties the article to native app behaviour)

    /// **UserService.cancelOrder**, **sellerRequestOrderCancellation**, **approveOrderCancellation** / **rejectOrderCancellation**; buyer/seller flows in **OrderDetailView**.
    static var helpArticleCancelOrderURL: String { "\(publicWebsiteBaseURL)/help/cancel-order" }

    /// Order status **REFUNDED** and post-payment reversal; status strings in **OrderDetailView** / **AnnChatView** product rows.
    static var helpArticleRefundsURL: String { "\(publicWebsiteBaseURL)/help/refunds" }

    /// Delivery timing for **HOME_DELIVERY** vs **LOCAL_PICKUP** / collection-point checkout in **PaymentView** (`DeliveryTypeEnum`).
    static var helpArticleDeliveryURL: String { "\(publicWebsiteBaseURL)/help/delivery" }

    /// **SHIPPED**, **IN_TRANSIT**, **READY_FOR_PICKUP** in **OrderDetailView**; tracking row **OrderTrackingCodeHelpView**; order-related push notifications.
    static var helpArticleOrderShippedURL: String { "\(publicWebsiteBaseURL)/help/order-shipped" }

    /// **PaymentView** collection-point option (maps to carrier **LOCAL_PICKUP** vs home delivery).
    static var helpArticleCollectionPointURL: String { "\(publicWebsiteBaseURL)/help/collection-point" }

    /// **OrderHelpView** → **ItemNotReceivedGuidanceHelpView** / **ItemNotReceivedReportHelpView** when the order shows delivered but the buyer has no item.
    static var helpArticleDeliveredNotReceivedURL: String { "\(publicWebsiteBaseURL)/help/delivered-not-received" }

    /// **VacationModeView** and **UserService.updateProfile(isVacationMode:)**; discover/listings hide vacation sellers (**AIChatView** / product queries use `excludingVacationModeSellers`).
    static var helpArticleVacationModeURL: String { "\(publicWebsiteBaseURL)/help/vacation-mode" }

    /// Discover uses “trusted” vendor copy; there is **no** dedicated native “badge” settings screen-web article should state real eligibility from your business rules.
    static var helpArticleTrustedSellerURL: String { "\(publicWebsiteBaseURL)/help/trusted-seller" }
    
    /// Public profile URL for sharing, QR, and web (`/profile/{username}` on the consumer site).
    static func profileShareWebURL(forUsername username: String) -> URL? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let enc = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
        return URL(string: "\(publicWebsiteBaseURL)/profile/\(enc)")
    }

    /// Invite landing (SMS / contacts share). Consumer domain only.
    static var inviteFriendsLandingURL: String { "\(publicWebsiteBaseURL)/join/" }

    /// Product and lookbook share / copy link base - same host as `publicWebsiteBaseURL` (no API/staging domains in user-facing URLs).
    static var publicWebItemLinkBaseURL: String { publicWebsiteBaseURL }
    
    // API Configuration
    static let apiTimeout: TimeInterval = 60.0

    // MARK: - Seller Gold (App Store)

    /// Auto-renewable **monthly** Gold subscription product id - create this subscription in App Store Connect and attach to the app.
    static let wearhouseGoldMonthlyProductId = "com.prelura.preloved.seller.gold.monthly"

    // MARK: - Lookbook Discover

    /// When **false** (default), Discover keeps **`lookbooks`** order from the server ([prelura-app](https://github.com/VoltisLab/prelura-app) ranker: recency + affinities + light engagement + per-viewer jitter). Set **true** only for local experiments to obscure API order with `shuffled()` per page.
    static let lookbookDiscoverClientSideShufflesPostOrder = false
}
