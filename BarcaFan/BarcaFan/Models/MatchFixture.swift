import Foundation

struct MatchFixture: Identifiable, Hashable, Sendable {
    let id: String
    let roundName: String
    let homeTeam: String
    let awayTeam: String
    let kickoff: Date
    let homeScore: Int?
    let awayScore: Int?
    let isBarcelonaHome: Bool

    var status: MatchStatus {
        if homeScore != nil, awayScore != nil { return .finished }
        return .scheduled
    }

    var scoreLine: String? {
        guard let h = homeScore, let a = awayScore else { return nil }
        return "\(h) - \(a)"
    }
}

enum MatchStatus: Sendable {
    case scheduled
    case finished
}
