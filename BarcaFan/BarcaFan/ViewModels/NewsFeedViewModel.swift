import Foundation

@Observable
@MainActor
final class NewsFeedViewModel {
    private(set) var stories: [NewsStory] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    func refresh() async {
        isLoading = true
        lastError = nil
        let fetched = await NewsAggregator.fetchStories()
        stories = Array(fetched.prefix(120))
        if stories.isEmpty {
            lastError = "Couldn’t load news right now. Pull down to try again."
        }
        isLoading = false
    }
}
