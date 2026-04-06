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
    
    // Legal & info URLs (same domain as API)
    static let termsAndConditionsURL = "https://prelura.voltislabs.uk/terms/"
    static let privacyPolicyURL = "https://prelura.voltislabs.uk/privacy/"
    static let acknowledgementsURL = "https://prelura.voltislabs.uk/acknowledgements/"
    static let hmrcReportingURL = "https://www.gov.uk/government/organisations/hm-revenue-customs/contact/report-fraud-or-an-untrustworthy-website"
    
    /// Used when inviting contacts (share sheet / SMS). Same landing URL as before rebrand.
    static let inviteFriendsLandingURL = "https://prelura.voltislabs.uk"
    /// Public web URLs for sharing listings and universal links (`/item/{slug}`: listing code or legacy numeric id). Must match **Associated Domains** / `apple-app-site-association` on this host (production: prelura.uk).
    static let publicWebItemLinkBaseURL = "https://prelura.uk"
    
    // API Configuration
    static let apiTimeout: TimeInterval = 60.0
}
