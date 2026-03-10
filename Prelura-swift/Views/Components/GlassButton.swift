import SwiftUI

struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: GlassButtonStyle

    enum GlassButtonStyle {
        case primary
        case secondary
        case outline
    }

    init(
        _ title: String,
        icon: String? = nil,
        style: GlassButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Group {
            if style == .primary {
                Button(action: action) {
                    labelContent
                }
                .foregroundStyle(foregroundColor)
                .buttonStyle(.borderedProminent)
                .tint(Theme.primaryColor)
            } else {
                Button(action: action) {
                    labelContent
                        .background(backgroundView)
                        .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
                }
                .foregroundStyle(foregroundColor)
                .buttonStyle(.plain)
            }
        }
    }
    
    private var labelContent: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            Text(title)
                .font(Theme.Typography.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.lg)
        .contentShape(Rectangle())
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .outline:
            return Theme.primaryColor
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Color.clear
        case .secondary:
            Color.clear
        case .outline:
            Color.clear
        }
    }
}

// MARK: - Toolbar/nav icons: system material only (same as tab bar), no custom glass.
private let toolbarIconShape = Circle()

/// System bar material only — same material as the tab bar. No custom opacity, border, or shadow.
private struct GlassIconCircleStyle: ViewModifier {
    let size: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .background(toolbarIconShape.fill(.bar))
    }
}

/// Icon-only glassy circle button for toolbars (bell, heart, gear, xmark). One component = consistent look.
struct GlassIconButton: View {
    let icon: String
    let action: () -> Void
    let size: CGFloat
    var iconColor: Color = Theme.primaryColor
    var iconSize: CGFloat = 18

    init(
        icon: String,
        size: CGFloat = 44,
        iconColor: Color = Theme.primaryColor,
        iconSize: CGFloat = 18,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.iconColor = iconColor
        self.iconSize = iconSize
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(iconColor)
                .modifier(GlassIconCircleStyle(size: size))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Same glassy circle + icon, no button (e.g. for NavigationLink label in toolbar).
struct GlassIconView: View {
    let icon: String
    var size: CGFloat = 44
    var iconColor: Color = Theme.primaryColor
    var iconSize: CGFloat = 18

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundColor(iconColor)
            .modifier(GlassIconCircleStyle(size: size))
    }
}
