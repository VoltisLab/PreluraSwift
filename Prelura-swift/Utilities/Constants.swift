import Foundation

/// App-wide constants. **Wearhouse** client; API hostnames below are the shared production backend (unchanged).
///
/// **Backend repository (do not modify from this app):**
/// https://github.com/VoltisLab/prelura-app
///
/// This app uses the backend's GraphQL API at the URLs below; schema and endpoints are shared with the Flutter app and other clients.
struct Constants {
    // GraphQL Endpoints (backend: https://github.com/VoltisLab/prelura-app)
    static let graphQLBaseURL = "https://prelura.voltislabs.uk/graphql/"
    static let graphQLUploadURL = "https://prelura.voltislabs.uk/graphql/uploads/"
    /// WebSocket for chat (same host as GraphQL so messages send/save to the same backend).
    static let chatWebSocketBaseURL = "wss://prelura.voltislabs.uk/ws/chat/"
    /// Django `ConversationsConsumer`: inbox list sync + typing for threads the user is in (not per-room chat).
    static let conversationsWebSocketURL = "wss://prelura.voltislabs.uk/ws/conversations/"
    
    /// Consumer marketing site: legal HTML, help articles. Host these paths on **mywearhouse.co.uk** (or adjust here if routes differ).
    static let publicWebsiteBaseURL = "https://mywearhouse.co.uk"

    // Legal (in-app **Legal Information** → WebView)
    static var termsAndConditionsURL: String { "\(publicWebsiteBaseURL)/terms/" }
    static var privacyPolicyURL: String { "\(publicWebsiteBaseURL)/privacy/" }
    static var acknowledgementsURL: String { "\(publicWebsiteBaseURL)/acknowledgements/" }
    /// Official HMRC fraud reporting (unchanged).
    static let hmrcReportingURL = "https://www.gov.uk/government/organisations/hm-revenue-customs/contact/report-fraud-or-an-untrustworthy-website"

    // MARK: - Help Centre (paths must exist on `publicWebsiteBaseURL`; each comment ties the article to native app behaviour)

    /// **About → How to use Wearhouse** (replaces placeholder scroll copy).
    static var helpHowToUseWearhouseURL: String { "\(publicWebsiteBaseURL)/help/how-to-use" }

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

    /// Discover uses “trusted” vendor copy; there is **no** dedicated native “badge” settings screen—web article should state real eligibility from your business rules.
    static var helpArticleTrustedSellerURL: String { "\(publicWebsiteBaseURL)/help/trusted-seller" }
    
    /// Backend API: GraphQL plus public HTML landings for `/item/*`, `/lookbook/*`, `/join/`, `/app/u/*` (Django `web_public`). Universal links / AASA are served here.
    static let universalLinksAPIBaseURL = "https://prelura.voltislabs.uk"

    /// Public profile URL for sharing, QR, and web (`/profile/{username}` on the consumer site).
    static func profileShareWebURL(forUsername username: String) -> URL? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let enc = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
        return URL(string: "\(publicWebsiteBaseURL)/profile/\(enc)")
    }

    /// Invite landing (SMS / contacts share). Consumer domain only.
    static var inviteFriendsLandingURL: String { "\(publicWebsiteBaseURL)/join/" }

    /// Product and lookbook share links (`/item/…`, `/lookbook/…`). These paths are implemented on `universalLinksAPIBaseURL` only; `mywearhouse.co.uk` does not serve them (Safari would 404).
    static var publicWebItemLinkBaseURL: String { universalLinksAPIBaseURL }
    
    // API Configuration
    static let apiTimeout: TimeInterval = 60.0
}
