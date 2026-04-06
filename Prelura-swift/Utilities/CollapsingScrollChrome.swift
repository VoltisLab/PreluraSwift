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

/// Toggles chrome visibility from scroll direction; near-top always shows chrome.
enum CollapsingScrollChrome {
    /// Call from `onPreferenceChange` for the scroll minY value.
    static func updateVisibility(
        scrollMinY: CGFloat,
        lastY: inout CGFloat,
        isVisible: Binding<Bool>,
        threshold: CGFloat = 10,
        topSnap: CGFloat = 12
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
        if delta < -threshold, isVisible.wrappedValue {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.12)) {
                isVisible.wrappedValue = false
            }
        } else if delta > threshold, !isVisible.wrappedValue {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.12)) {
                isVisible.wrappedValue = true
            }
        }
    }
}
