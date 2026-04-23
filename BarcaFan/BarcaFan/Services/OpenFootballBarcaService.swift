import Foundation

/// La Liga schedule + results from the [openfootball/football.json](https://github.com/openfootball/football.json) public dataset (no API key).
enum OpenFootballBarcaService {
    private static let dataURL = URL(string: "https://raw.githubusercontent.com/openfootball/football.json/master/2025-26/es.1.json")!
    private static let barcaName = "FC Barcelona"

    static func fetchBarcaMatches() async throws -> [MatchFixture] {
        let (data, response) = try await URLSession.shared.data(from: dataURL)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let file = try JSONDecoder().decode(OpenFootballLaLigaFile.self, from: data)
        let filtered = file.matches.filter { $0.team1 == barcaName || $0.team2 == barcaName }
        return filtered.compactMap { mapMatch($0) }
            .sorted { $0.kickoff < $1.kickoff }
    }
}

// MARK: - JSON types

private struct OpenFootballLaLigaFile: Decodable {
    let name: String
    let matches: [OpenFootballMatch]
}

private struct OpenFootballMatch: Decodable {
    let round: String
    let date: String
    let time: String?
    let team1: String
    let team2: String
    let score: OpenFootballScore?
}

private struct OpenFootballScore: Decodable {
    let ft: [Int]?
}

private extension OpenFootballBarcaService {
    static let spainTZ = TimeZone(identifier: "Europe/Madrid") ?? .current
    static let kickoffParser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = spainTZ
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    static func mapMatch(_ m: OpenFootballMatch) -> MatchFixture? {
        let timePart = (m.time?.isEmpty == false) ? m.time! : "13:00"
        let trimmedTime = String(timePart.prefix(5))
        guard let kickoff = kickoffParser.date(from: "\(m.date) \(trimmedTime)") else {
            return nil
        }
        let ft = m.score?.ft
        let hs: Int? = (ft?.count ?? 0) >= 2 ? ft![0] : nil
        let ascore: Int? = (ft?.count ?? 0) >= 2 ? ft![1] : nil
        let id = "\(m.date)|\(m.team1)|\(m.team2)"
        return MatchFixture(
            id: id,
            roundName: m.round,
            homeTeam: m.team1,
            awayTeam: m.team2,
            kickoff: kickoff,
            homeScore: hs,
            awayScore: ascore,
            isBarcelonaHome: m.team1 == barcaName
        )
    }
}
