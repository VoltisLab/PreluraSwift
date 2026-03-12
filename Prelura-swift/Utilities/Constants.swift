import Foundation

/// App-wide constants. API base URLs point to the Prelura backend.
///
/// **Backend repository (do not modify from this app):**
/// https://github.com/VoltisLab/prelura-app
///
/// This app uses the backend's GraphQL API at the URLs below; schema and endpoints are shared with the Flutter app and other clients.
struct Constants {
    // GraphQL Endpoints (backend: https://github.com/VoltisLab/prelura-app)
    static let graphQLBaseURL = "https://prelura.voltislabs.uk/graphql/"
    static let graphQLUploadURL = "https://prelura.voltislabs.uk/graphql/uploads/"
    
    // Legal & info URLs (same domain as API)
    static let termsAndConditionsURL = "https://prelura.voltislabs.uk/terms/"
    static let privacyPolicyURL = "https://prelura.voltislabs.uk/privacy/"
    static let acknowledgementsURL = "https://prelura.voltislabs.uk/acknowledgements/"
    static let hmrcReportingURL = "https://www.gov.uk/government/organisations/hm-revenue-customs/contact/report-fraud-or-an-untrustworthy-website"
    
    /// Used when inviting contacts (share sheet / SMS).
    static let inviteToPreluraURL = "https://prelura.voltislabs.uk"
    
    // API Configuration
    static let apiTimeout: TimeInterval = 60.0
}
