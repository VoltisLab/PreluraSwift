import SwiftUI

/// Editorial trust tier for aggregated news (mirrors your backend scoring).
enum SourceTier: Int, CaseIterable, Identifiable, Sendable {
    case official = 1
    case licensedData = 2
    case journalism = 3
    case community = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .official: "Official"
        case .licensedData: "Licensed data"
        case .journalism: "Journalism"
        case .community: "Community"
        }
    }

    /// Base trust contribution used before cross-reference / moderation boosts.
    var baseTrustScore: Int {
        switch self {
        case .official: 95
        case .licensedData: 88
        case .journalism: 72
        case .community: 38
        }
    }
}

enum TrustPresentation: Sendable {
    case officialCheck
    case verifiedPress
    case communityWarning
    case confirmedCrossRef

    var label: String {
        switch self {
        case .officialCheck: "Official"
        case .verifiedPress: "Verified press"
        case .communityWarning: "Unverified"
        case .confirmedCrossRef: "Confirmed"
        }
    }

    var systemImage: String {
        switch self {
        case .officialCheck: "checkmark.seal.fill"
        case .verifiedPress: "checkmark.circle.fill"
        case .communityWarning: "exclamationmark.triangle.fill"
        case .confirmedCrossRef: "link.circle.fill"
        }
    }
}

struct NewsStory: Identifiable, Hashable, Sendable {
    /// Stable id from RSS `guid` or normalized link.
    let id: String
    let title: String
    /// Short plain text for list rows (truncated).
    let summary: String
    /// Full RSS description / content as plain text for the story screen.
    let fullPlainText: String
    let sourceName: String
    let tier: SourceTier
    let publishedAt: Date
    /// Optional: set when backend cross-reference finds ≥2 tier-2/3 hits in 24h.
    let crossReferenceConfirmed: Bool
    let imageURL: URL?
    let linkURL: URL

    var trustScore: Int {
        var score = tier.baseTrustScore
        if crossReferenceConfirmed { score = min(100, score + 12) }
        return score
    }

    var presentation: TrustPresentation {
        if crossReferenceConfirmed { return .confirmedCrossRef }
        switch tier {
        case .official, .licensedData:
            return .officialCheck
        case .journalism:
            return .verifiedPress
        case .community:
            return .communityWarning
        }
    }
}
