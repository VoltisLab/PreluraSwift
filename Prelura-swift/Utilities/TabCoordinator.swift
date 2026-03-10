import SwiftUI
import Combine

/// Coordinates tab bar taps with scroll-to-top and refresh. When user taps the same tab:
/// - First tap: scroll to top (or no-op if already at top)
/// - Second tap: refresh
final class TabCoordinator: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var readyForRefresh: Set<Int> = []
    /// Per-tab: true when scroll view is at top. Used to decide: at top → refresh on tap; not at top → scroll first, refresh on second tap.
    private var atTop: [Int: Bool] = [:]

    private var scrollToTopActions: [Int: () -> Void] = [:]
    private var refreshActions: [Int: () -> Void] = [:]

    func registerScrollToTop(tab: Int, action: @escaping () -> Void) {
        scrollToTopActions[tab] = action
    }

    func registerRefresh(tab: Int, action: @escaping () -> Void) {
        refreshActions[tab] = action
    }

    func reportAtTop(tab: Int, isAtTop: Bool) {
        atTop[tab] = isAtTop
    }

    func handleTabTap(_ tab: Int) {
        if tab != selectedTab {
            selectedTab = tab
            readyForRefresh.removeAll()
            HapticManager.tabTap()
            return
        }

        // Same tab tapped
        if readyForRefresh.contains(tab) {
            readyForRefresh.remove(tab)
            refreshActions[tab]?()
            HapticManager.refresh()
            return
        }

        if atTop[tab] == true {
            refreshActions[tab]?()
            HapticManager.refresh()
            return
        }

        scrollToTopActions[tab]?()
        readyForRefresh.insert(tab)
        HapticManager.tabTap()
    }

    func selectTab(_ tab: Int) {
        selectedTab = tab
    }
}
