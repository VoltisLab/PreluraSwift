import Foundation

@Observable
@MainActor
final class MatchesViewModel {
    private(set) var upcoming: [MatchFixture] = []
    private(set) var recent: [MatchFixture] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let all = try await OpenFootballBarcaService.fetchBarcaMatches()
            let now = Date()
            let withResult = all.filter { $0.homeScore != nil && $0.awayScore != nil }
            let withoutResult = all.filter { $0.homeScore == nil || $0.awayScore == nil }

            upcoming = withoutResult
                .filter { $0.kickoff > now }
                .sorted { $0.kickoff < $1.kickoff }

            recent = Array(
                withResult
                    .sorted { $0.kickoff > $1.kickoff }
                    .prefix(15)
            )
        } catch {
            errorMessage = "Couldn’t load fixtures. Check your connection and try again."
            upcoming = []
            recent = []
        }
        isLoading = false
    }
}
