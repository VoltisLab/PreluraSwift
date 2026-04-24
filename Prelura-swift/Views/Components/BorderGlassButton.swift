import SwiftUI

/// Outline-only (no fill) button: primary-color stroke, corner radius 30.
/// Use for secondary actions that should match the primary glass style as an outline.
struct BorderGlassButton: View {
    @Environment(\.colorScheme) private var colorScheme

    enum ChromeStyle {
        /// Primary-outline styling (e.g. Try Cart, Shop All, Favourites).
        case standard
        /// Outline colors for Retro grid; pair with `layout: .compact` - do not change dimensions by style alone.
        case retroCompactLightOutline
    }

    /// Vertical metrics: **compact** = product-grid “Add to bag”; **bar** = bottom-bar / search-field height (44).
    enum Layout {
        case compact
        case bar
    }

    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var chromeStyle: ChromeStyle = .standard
    var layout: Layout = .bar
    let action: () -> Void

    private let cornerRadius: CGFloat = 30
    private let strokeLineWidth: CGFloat = 1

    init(
        _ title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        chromeStyle: ChromeStyle = .standard,
        layout: Layout = .bar,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.chromeStyle = chromeStyle
        self.layout = layout
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
        switch layout {
        case .compact: return 14
        case .bar: return 16
        }
    }

    private var titleFont: Font { Theme.Typography.subheadline }

    private var horizontalPadding: CGFloat { Theme.Spacing.md }

    private var verticalPadding: CGFloat {
        switch layout {
        case .compact: return Theme.Spacing.sm
        case .bar: return 0
        }
    }

    private var minBarHeight: CGFloat? {
        switch layout {
        case .compact: return nil
        case .bar: return Theme.SearchField.singleLineHeight
        }
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
            .frame(maxWidth: .infinity, minHeight: minBarHeight)
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
