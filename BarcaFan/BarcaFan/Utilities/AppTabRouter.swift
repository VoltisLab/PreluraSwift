import Foundation
import Observation

@Observable
@MainActor
final class AppTabRouter {
    /// Tab order: News (0), Fans (1), Matches (2), Themes (3).
    var selectedTab: Int = 0
}
