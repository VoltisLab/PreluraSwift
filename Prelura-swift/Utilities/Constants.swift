import Foundation

struct Constants {
    // GraphQL Endpoints
    static let graphQLBaseURL = "https://prelura.voltislabs.uk/graphql/"
    static let graphQLUploadURL = "https://prelura.voltislabs.uk/graphql/uploads/"
    
    // Legal & info URLs (same domain as API)
    static let termsAndConditionsURL = "https://prelura.voltislabs.uk/terms/"
    static let privacyPolicyURL = "https://prelura.voltislabs.uk/privacy/"
    static let acknowledgementsURL = "https://prelura.voltislabs.uk/acknowledgements/"
    static let hmrcReportingURL = "https://www.gov.uk/government/organisations/hm-revenue-customs/contact/report-fraud-or-an-untrustworthy-website"
    
    // API Configuration
    static let apiTimeout: TimeInterval = 60.0
}
