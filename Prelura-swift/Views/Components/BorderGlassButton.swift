import SwiftUI

/// Outline-only (no fill) button: primary-color stroke, corner radius 30.
/// Use for secondary actions that should match the primary glass style as an outline.
struct BorderGlassButton: View {
    @Environment(\.colorScheme) private var colorScheme

    enum ChromeStyle {
        case standard
        /// Tighter vertical size (aligned with filter row); white stroke on dark Retro gradient, adaptive in light mode.
        case retroCompactLightOutline
    }

    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var chromeStyle: ChromeStyle = .standard
    let action: () -> Void

    private let cornerRadius: CGFloat = 30
    private let strokeLineWidth: CGFloat = 1

    init(
        _ title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        chromeStyle: ChromeStyle = .standard,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.chromeStyle = chromeStyle
        self.action = action
    }

    private var outlineColor: Color {
        switch chromeStyle {
        case .standard:
            return Theme.primaryColor
        case .retroCompactLightOutline:
            return colorScheme == .light ? Color.black.opacity(0.35) : Color.white
        }
    }

    private var labelColor: Color {
        switch chromeStyle {
        case .standard:
            return Theme.primaryColor
        case .retroCompactLightOutline:
            return colorScheme == .light ? Theme.Colors.primaryText : Color.white
        }
    }

    private var iconPointSize: CGFloat {
        chromeStyle == .retroCompactLightOutline ? 14 : 16
    }

    private var titleFont: Font {
        chromeStyle == .retroCompactLightOutline ? Theme.Typography.subheadline : Theme.Typography.headline
    }

    private var horizontalPadding: CGFloat {
        chromeStyle == .retroCompactLightOutline ? Theme.Spacing.md : Theme.Spacing.lg
    }

    private var verticalPadding: CGFloat {
        chromeStyle == .retroCompactLightOutline ? Theme.Spacing.sm : Theme.Spacing.md
    }

    var body: some View {
        Button(action: {
            HapticManager.secondaryAction()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconPointSize, weight: .semibold))
                }
                Text(title)
                    .font(titleFont)
            }
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(PlainTappableButtonStyle())
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(outlineColor, lineWidth: strokeLineWidth)
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .opacity(isEnabled ? 1 : 0.6)
        .disabled(!isEnabled)
    }
}
