import SwiftUI

/// Single component for all filter/category/brand pills. Inactive state uses fill + hairline border; optional drop shadow in dark mode (`showShadow`).
struct PillTag: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Standard pills (filters, forms). `compactOutline` is border-only, smaller type—e.g. read-only review highlight tags.
    enum VisualStyle {
        case standard
        case compactOutline
    }

    let title: String
    let isSelected: Bool
    /// When true, unselected state shows icon (e.g. for brand row). Text colour: unselected = grey, selected = white.
    var accentWhenUnselected: Bool = false
    /// Optional leading icon (e.g. "message.fill" for brand row).
    var icon: String? = nil
    /// Inactive chip drop shadow (dark mode). Set false for dense forms where shadows are omitted.
    var showShadow: Bool = true
    /// When true, title stays on one line (wider pills instead of wrapping).
    var singleLineTitle: Bool = false
    var visualStyle: VisualStyle = .standard
    /// Set false for display-only tags (e.g. review highlights) to avoid haptics on tap.
    var playsSelectionHaptic: Bool = true
    let action: () -> Void

    private var tagCornerRadius: CGFloat {
        visualStyle == .compactOutline ? 6 : Theme.Glass.tagCornerRadius
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: tagCornerRadius, style: .continuous)
    }

    /// In light mode, skip shadow to avoid muddy low-contrast look on white; in dark mode use elevation shadow.
    private var inactiveShadowColor: Color {
        colorScheme == .light ? .clear : Color.black.opacity(0.22)
    }
    private let inactiveShadowRadius: CGFloat = 6
    private let inactiveShadowY: CGFloat = 3

    var body: some View {
        Button(action: {
            if playsSelectionHaptic { HapticManager.selection() }
            action()
        }) {
            HStack(spacing: visualStyle == .compactOutline ? 4 : Theme.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: visualStyle == .compactOutline ? 11 : 14, weight: .semibold))
                        .foregroundColor(foregroundColor)
                }
                Text(title)
                    .font(visualStyle == .compactOutline ? Theme.Typography.caption : Theme.Typography.subheadline)
                    .foregroundColor(foregroundColor)
                    .lineLimit(singleLineTitle ? 1 : nil)
                    .fixedSize(horizontal: singleLineTitle, vertical: false)
            }
            .padding(.horizontal, visualStyle == .compactOutline ? 8 : Theme.Spacing.md)
            .padding(.vertical, visualStyle == .compactOutline ? 4 : Theme.Spacing.sm)
            .background(backgroundView)
            .clipShape(shape)
            .overlay(overlayView)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
        }
        .buttonStyle(PlainTappableButtonStyle())
    }

    private var shadowColor: Color {
        if visualStyle == .compactOutline { return .clear }
        return (!showShadow || isSelected) ? .clear : inactiveShadowColor
    }

    private var shadowRadius: CGFloat {
        if visualStyle == .compactOutline { return 0 }
        return (!showShadow || isSelected) ? 0 : inactiveShadowRadius
    }

    private var shadowY: CGFloat {
        if visualStyle == .compactOutline { return 0 }
        return (!showShadow || isSelected) ? 0 : inactiveShadowY
    }

    private var foregroundColor: Color {
        if visualStyle == .compactOutline {
            return Theme.Colors.primaryText
        }
        if isSelected { return .white }
        return colorScheme == .light ? Theme.Colors.primaryText : Theme.Colors.secondaryText
    }

    @ViewBuilder
    private var backgroundView: some View {
        if visualStyle == .compactOutline {
            shape.fill(Color.clear)
        } else if isSelected {
            shape.fill(Theme.primaryColor)
        } else if colorScheme == .light {
            shape.fill(Theme.Colors.background)
        } else {
            shape.fill(Theme.Colors.secondaryBackground)
        }
    }

    /// Inactive: subtle stroke for card edge. Selected: no border. Compact outline: stronger hairline only.
    @ViewBuilder
    private var overlayView: some View {
        if visualStyle == .compactOutline {
            shape.strokeBorder(outlineTagBorderColor, lineWidth: 1)
        } else if isSelected {
            EmptyView()
        } else {
            shape
                .strokeBorder(inactiveBorderColor, lineWidth: 0.5)
        }
    }

    private var outlineTagBorderColor: Color {
        colorScheme == .light
            ? Color.black.opacity(0.22)
            : Theme.Colors.glassBorder.opacity(0.9)
    }

    private var inactiveBorderColor: Color {
        colorScheme == .light
            ? Color.black.opacity(0.18)
            : Theme.Colors.glassBorder.opacity(0.5)
    }
}
