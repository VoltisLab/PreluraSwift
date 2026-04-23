import SwiftUI

/// Shared tab backdrop: gradient + optional per-kit pattern layer.
struct ThemedBackgroundView: View {
    @Environment(KitThemeStore.self) private var themeStore

    var body: some View {
        let kit = themeStore.current
        let palette = kit.palette
        ZStack {
            LinearGradient(
                colors: [palette.background, palette.primary.opacity(0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if themeStore.showBackgroundPatterns {
                KitThemePatternLayer(kit: kit, palette: palette)
                    .blendMode(.softLight)
                    .opacity(0.42)
            }
        }
        .ignoresSafeArea()
    }
}
