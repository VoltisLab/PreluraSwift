import SwiftUI

/// Reports the top content’s `minY` in a named scroll coordinate space (0 at rest, negative when scrolled down).
enum ScrollMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Measured height of the fixed header above the product grid (search, pills, filter row).
enum FilteredProductsHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Measured height of the Home feed’s pinned header (search + category chips).
enum HomePinnedHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Toggles chrome visibility from scroll direction; near-top always shows chrome.
enum CollapsingScrollChrome {
    /// Call from `onPreferenceChange` for the scroll minY value.
    /// Uses a **lower** `revealThreshold` than `hideThreshold` so a small upward scroll brings search/filters back.
    /// `hideThreshold` is intentionally moderate; slow drags rarely exceed ~6pt/frame, so we also hide once
    /// the content has moved up by `depthHideThreshold` and the user keeps scrolling down slightly.
    static func updateVisibility(
        scrollMinY: CGFloat,
        lastY: inout CGFloat,
        isVisible: Binding<Bool>,
        hideThreshold: CGFloat = 6,
        revealThreshold: CGFloat = 2,
        topSnap: CGFloat = 12,
        depthHideThreshold: CGFloat = 18
    ) {
        defer { lastY = scrollMinY }

        if scrollMinY > -topSnap {
            if !isVisible.wrappedValue {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.12)) {
                    isVisible.wrappedValue = true
                }
            }
            return
        }

        let delta = scrollMinY - lastY
        let hideFromFlick = delta < -hideThreshold
        let hideFromSlowDrag = scrollMinY < -depthHideThreshold && delta < -0.25

        if isVisible.wrappedValue, hideFromFlick || hideFromSlowDrag {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.12)) {
                isVisible.wrappedValue = false
            }
        } else if delta > revealThreshold, !isVisible.wrappedValue {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.12)) {
                isVisible.wrappedValue = true
            }
        }
    }
}
