import SwiftUI

/// Primary CTA button using Liquid Glass: clear + primary tint, corner radius 30.
/// Use this for all primary actions across the app.
struct PrimaryGlassButton: View {
    /// **standard** = larger padding + headline (forms, sheets). **bar** = `Theme.SearchField.singleLineHeight` for bottom dual-CTA rows.
    enum Layout {
        case standard
        case bar
    }

    let title: String
    var icon: String? = nil
    /// Asset catalog name; when set, shown instead of SF Symbol `icon`.
    var assetIcon: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var layout: Layout = .standard
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        assetIcon: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        layout: Layout = .standard,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.assetIcon = assetIcon
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.layout = layout
        self.action = action
    }

    private var titleFont: Font {
        switch layout {
        case .standard: return Theme.Typography.headline
        case .bar: return Theme.Typography.subheadline.weight(.semibold)
        }
    }

    private var verticalPadding: CGFloat {
        switch layout {
        case .standard: return Theme.Spacing.md
        case .bar: return 0
        }
    }

    private var minBarHeight: CGFloat? {
        switch layout {
        case .standard: return nil
        case .bar: return Theme.SearchField.singleLineHeight
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.primaryAction()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    if let assetIcon {
                        Image(assetIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    } else if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(titleFont)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: minBarHeight)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, verticalPadding)
            // Full control bounds tappable (not only glyph bounds of Text/Image).
            .contentShape(RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(PlainTappableButtonStyle())
        .glassEffect(.clear.tint(Theme.primaryColor), in: .rect(cornerRadius: 30))
        .contentShape(RoundedRectangle(cornerRadius: 30))
        .opacity(isEnabled && !isLoading ? 1 : 0.6)
        .disabled(!isEnabled || isLoading)
    }
}
