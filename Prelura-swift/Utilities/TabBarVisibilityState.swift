import SwiftUI
import Combine

/// Shared state for showing/hiding the tab bar with optional entrance animation.
/// Root views set `isVisible = true`; pushed views (e.g. Menu flow) set `isVisible = false`.
final class TabBarVisibilityState: ObservableObject {
    @Published var isVisible: Bool = true
}
