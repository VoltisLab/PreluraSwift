import SwiftUI

/// Text wordmark for the Wearhouse rebrand (replaces `PreluraLogo` / `SplashLogo` in chrome).
struct WearhouseWordmarkView: View {
    enum Style {
        case toolbar
        case login
        case splash
    }

    var style: Style = .toolbar

    var body: some View {
        let metrics = metrics(for: style)
        Text("WEARHOUSE")
            .font(.system(size: metrics.fontSize, weight: .black, design: .rounded))
            .tracking(metrics.tracking)
            .minimumScaleFactor(0.72)
            .lineLimit(1)
            .foregroundStyle(foreground(for: style))
    }

    private func metrics(for style: Style) -> (fontSize: CGFloat, tracking: CGFloat) {
        switch style {
        case .toolbar: return (11, 2.8)
        case .login: return (17.5, 4.2)
        case .splash: return (28, 6.5)
        }
    }

    @ViewBuilder
    private func foreground(for style: Style) -> some ShapeStyle {
        switch style {
        case .splash:
            Theme.primaryColor
        case .toolbar:
            LinearGradient(
                colors: [Theme.Colors.primaryText, Theme.Colors.primaryText.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .login:
            LinearGradient(
                colors: [.white, .white.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
