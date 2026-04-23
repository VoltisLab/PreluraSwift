import SwiftUI

struct TrustBadgeView: View {
    let presentation: TrustPresentation
    @Environment(KitThemeStore.self) private var themeStore

    var body: some View {
        let palette = themeStore.current.palette
        HStack(spacing: 6) {
            Image(systemName: presentation.systemImage)
                .font(.caption.weight(.semibold))
            Text(presentation.label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor(palette: palette).opacity(0.22))
        .foregroundStyle(foregroundColor(palette: palette))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(foregroundColor(palette: palette).opacity(0.35), lineWidth: 1)
        )
    }

    private func foregroundColor(palette: ThemePalette) -> Color {
        switch presentation {
        case .officialCheck:
            return Color(red: 0.35, green: 0.62, blue: 0.98)
        case .confirmedCrossRef:
            return palette.accent
        case .verifiedPress:
            return Color(red: 0.35, green: 0.62, blue: 0.98)
        case .communityWarning:
            return Color(red: 0.98, green: 0.78, blue: 0.22)
        }
    }

    private func backgroundColor(palette: ThemePalette) -> Color {
        switch presentation {
        case .officialCheck:
            return Color(red: 0.08, green: 0.20, blue: 0.42)
        case .confirmedCrossRef:
            return palette.primary
        case .verifiedPress:
            return Color(red: 0.08, green: 0.20, blue: 0.42)
        case .communityWarning:
            return Color(red: 0.42, green: 0.28, blue: 0.05)
        }
    }
}
