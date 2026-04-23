import Foundation

/// Product surface areas - roadmap items open from **Fans**; News / Matches / Themes stay as full tabs.
enum FanFeature: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Core
    case liveMatchHub
    case fixturesAndResults
    case teamNewsFeed
    case squadProfiles

    // Fan engagement
    case matchChatRooms
    case fanReactionsFeed
    case pollsAndPredictions
    case fanReputation

    // Smart / AI
    case aiMatchAnalyst
    case personalizedFeed
    case voiceQA

    // Gamification
    case fantasyMode
    case predictionLeagues
    case dailyChallenges

    // Community & social
    case localFanGroups
    case userProfiles
    case clipsAndUploads

    // Monetisation
    case premiumTier
    case marketplaceMerch
    case eventTicketsWatchParties

    // Different level
    case liveAudioCommentary
    case arKitTryOn
    case stadiumMode
    case transferTrackerEngine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liveMatchHub: "Live Match Hub"
        case .fixturesAndResults: "Fixtures & Results"
        case .teamNewsFeed: "Team News Feed"
        case .squadProfiles: "Squad Profiles"
        case .matchChatRooms: "Match Chat Rooms"
        case .fanReactionsFeed: "Fan Reactions Feed"
        case .pollsAndPredictions: "Polls & Predictions"
        case .fanReputation: "Fan Reputation"
        case .aiMatchAnalyst: "AI Match Analyst"
        case .personalizedFeed: "Personalised Feed"
        case .voiceQA: "Voice Q&A"
        case .fantasyMode: "Fantasy Mode"
        case .predictionLeagues: "Prediction Leagues"
        case .dailyChallenges: "Daily Challenges"
        case .localFanGroups: "Local Fan Groups"
        case .userProfiles: "User Profiles"
        case .clipsAndUploads: "Clips & Uploads"
        case .premiumTier: "Premium Tier"
        case .marketplaceMerch: "Marketplace & Kits"
        case .eventTicketsWatchParties: "Events & Watch Parties"
        case .liveAudioCommentary: "Live Audio Commentary"
        case .arKitTryOn: "AR Kit Try-On"
        case .stadiumMode: "Stadium Mode"
        case .transferTrackerEngine: "Transfer Tracker Engine"
        }
    }

    var subtitle: String {
        switch self {
        case .liveMatchHub: "Scores, stats, lineups, timeline, ratings"
        case .fixturesAndResults: "Calendar sync + phone reminders"
        case .teamNewsFeed: "Transfers, injuries, press - trust-scored"
        case .squadProfiles: "Player stats, history, heatmaps"
        case .matchChatRooms: "Per-match live chat + reactions"
        case .fanReactionsFeed: "Post-goal fan takes & short video"
        case .pollsAndPredictions: "MOTM votes + prediction rewards"
        case .fanReputation: "XP, badges, football karma"
        case .aiMatchAnalyst: "“Why did Barça lose?” in plain language"
        case .personalizedFeed: "Youth vs transfers - your algorithm"
        case .voiceQA: "Hands-free fixture & stats answers"
        case .fantasyMode: "Pick a lineup, earn real-performance points"
        case .predictionLeagues: "Friends & global ladders"
        case .dailyChallenges: "Guess lineup / iconic goals"
        case .localFanGroups: "“Culers in Manchester” chapters"
        case .userProfiles: "Favourites, attendance, badges"
        case .clipsAndUploads: "Reactions, edits, chants - moderated"
        case .premiumTier: "Advanced stats, ad-free, exclusives"
        case .marketplaceMerch: "Kits & merch discovery"
        case .eventTicketsWatchParties: "Partner watch parties"
        case .liveAudioCommentary: "Fan-hosted commentary rooms"
        case .arKitTryOn: "Virtual shirt try-on"
        case .stadiumMode: "Camp Nou geofenced UI + seat chat"
        case .transferTrackerEngine: "Rumour timeline → likelihood → done"
        }
    }

    var systemImage: String {
        switch self {
        case .liveMatchHub: "dot.radiowaves.left.and.right"
        case .fixturesAndResults: "calendar"
        case .teamNewsFeed: "newspaper"
        case .squadProfiles: "person.3"
        case .matchChatRooms: "bubble.left.and.bubble.right"
        case .fanReactionsFeed: "play.rectangle.on.rectangle"
        case .pollsAndPredictions: "chart.bar.doc.horizontal"
        case .fanReputation: "rosette"
        case .aiMatchAnalyst: "brain.head.profile"
        case .personalizedFeed: "line.3.horizontal.decrease.circle"
        case .voiceQA: "mic.and.signal.meter"
        case .fantasyMode: "sportscourt"
        case .predictionLeagues: "trophy"
        case .dailyChallenges: "puzzlepiece.extension"
        case .localFanGroups: "mappin.and.ellipse"
        case .userProfiles: "person.crop.circle"
        case .clipsAndUploads: "video.badge.plus"
        case .premiumTier: "crown"
        case .marketplaceMerch: "bag"
        case .eventTicketsWatchParties: "ticket"
        case .liveAudioCommentary: "waveform.and.mic"
        case .arKitTryOn: "arkit"
        case .stadiumMode: "building.columns.fill"
        case .transferTrackerEngine: "arrow.left.arrow.right.circle"
        }
    }

    var tier: FeatureTier { FeatureTier.tier(containing: self) }
}

enum FeatureTier: Int, CaseIterable, Identifiable, Comparable, Sendable {
    case core = 0
    case fanEngagement
    case smartAI
    case gamification
    case community
    case monetisation
    case differentiator

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .core: "Must-have core"
        case .fanEngagement: "Fan engagement"
        case .smartAI: "Smart / AI"
        case .gamification: "Gamification"
        case .community: "Community & social"
        case .monetisation: "Monetisation"
        case .differentiator: "Different level"
        }
    }

    var headline: String {
        switch self {
        case .core: "Foundation - live hub, calendar, news, squad."
        case .fanEngagement: "Where we win vs apps that stop at headlines."
        case .smartAI: "Big differentiator - tactics & personalisation."
        case .gamification: "Make it addictive - lightweight games."
        case .community: "Supporters worldwide - chapters & profiles."
        case .monetisation: "Design revenue in, not bolted on later."
        case .differentiator: "Ideas that can own the fan platform category."
        }
    }

    static func tier(containing feature: FanFeature) -> FeatureTier {
        switch feature {
        case .liveMatchHub, .fixturesAndResults, .teamNewsFeed, .squadProfiles:
            return .core
        case .matchChatRooms, .fanReactionsFeed, .pollsAndPredictions, .fanReputation:
            return .fanEngagement
        case .aiMatchAnalyst, .personalizedFeed, .voiceQA:
            return .smartAI
        case .fantasyMode, .predictionLeagues, .dailyChallenges:
            return .gamification
        case .localFanGroups, .userProfiles, .clipsAndUploads:
            return .community
        case .premiumTier, .marketplaceMerch, .eventTicketsWatchParties:
            return .monetisation
        case .liveAudioCommentary, .arKitTryOn, .stadiumMode, .transferTrackerEngine:
            return .differentiator
        }
    }

    var features: [FanFeature] {
        FanFeature.allCases.filter { $0.tier == self }.sorted { $0.title < $1.title }
    }

    static func < (lhs: FeatureTier, rhs: FeatureTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
