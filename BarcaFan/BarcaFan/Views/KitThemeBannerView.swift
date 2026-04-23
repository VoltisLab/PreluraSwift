import SwiftUI

/// Wide header art: gradient + subtle pattern + scaled jersey glyph for a given kit.
struct KitThemeBannerView: View {
    let kit: KitTheme

    var body: some View {
        let palette = kit.palette
        ZStack {
            LinearGradient(
                colors: [palette.background, palette.primary.opacity(0.55), palette.secondary.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            KitThemePatternLayer(kit: kit, palette: palette)
                .opacity(0.22)
                .blendMode(.overlay)
                .allowsHitTesting(false)
            KitJerseyIconView(kit: kit)
                .scaleEffect(2.35)
                .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 10)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
