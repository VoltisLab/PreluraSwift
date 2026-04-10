import SwiftUI
import UIKit

// MARK: - Animated gradient (Frame 55 / 56 top stops; shared bottom #C9A734)

enum VintageShopBannerGradient {
    /// Seconds for A→B or B→A (full loop = 2× this).
    static let halfPeriodSeconds: Double = 10

    private static let topFrameA = UIColor(red: 218 / 255, green: 128 / 255, blue: 129 / 255, alpha: 1)
    private static let topFrameB = UIColor(red: 118 / 255, green: 218 / 255, blue: 82 / 255, alpha: 1)
    private static let bottomShared = UIColor(red: 201 / 255, green: 167 / 255, blue: 52 / 255, alpha: 1)

    static func colors(at date: Date) -> [Color] {
        let elapsed = date.timeIntervalSinceReferenceDate
        let period = halfPeriodSeconds * 2
        let linearT = 0.5 - 0.5 * cos((2 * Double.pi * elapsed) / period)
        let top = lerp(topFrameA, topFrameB, CGFloat(linearT))
        return [Color(uiColor: top), Color(uiColor: bottomShared)]
    }

    private static func lerp(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: 1
        )
    }
}

// MARK: - Reusable layers

struct VintageShopAnimatedBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            LinearGradient(
                colors: VintageShopBannerGradient.colors(at: context.date),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Full-bleed strip for Discover. Height follows SVG aspect (1054×582) so “RETRO” is not cropped.
struct VintageShopDiscoverBannerStrip: View {
    /// Matches `DiscoverVintageBannerForeground` viewBox (width / height).
    private static let bannerAspect: CGFloat = 1054 / 582

    var body: some View {
        Color.clear
            .aspectRatio(Self.bannerAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                ZStack {
                    VintageShopAnimatedBackground()
                    Image("DiscoverVintageBannerForeground")
                        .resizable()
                        .scaledToFit()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                }
            }
            .clipped()
    }
}

// MARK: - Full-screen promo → Shop All (Vintage locked)

private enum VintageShopPromoRoute: Hashable {
    case shop
}

struct VintageShopPromoFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VintageShopPromoLandingPage(onContinue: { path.append(VintageShopPromoRoute.shop) })
                .navigationDestination(for: VintageShopPromoRoute.self) { _ in
                    FilteredProductsView(
                        title: L10n.string("Shop All"),
                        filterType: .shopAllVintageLocked,
                        authService: authService,
                        offersAllowed: false
                    )
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        GlassIconButton(
                            icon: "xmark",
                            size: 40,
                            iconColor: .white,
                            iconSize: 15,
                            iconWeight: .semibold,
                            action: { dismiss() }
                        )
                        .accessibilityLabel(L10n.string("Close"))
                    }
                }
        }
    }
}

private struct VintageShopPromoLandingPage: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            VintageShopAnimatedBackground()
                .ignoresSafeArea()
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Image("DiscoverVintageBannerForeground")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width - Theme.Spacing.lg * 2)
                        .frame(maxHeight: geo.size.height * 0.46)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                    Spacer(minLength: Theme.Spacing.lg)
                    GlassEffectContainer(spacing: 0) {
                        Button(action: {
                            HapticManager.primaryAction()
                            onContinue()
                        }) {
                            Text(L10n.string("Continue"))
                                .font(Theme.Typography.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.md)
                                .contentShape(RoundedRectangle(cornerRadius: 30))
                        }
                        .buttonStyle(PlainTappableButtonStyle())
                        .glassEffect(.clear, in: .rect(cornerRadius: 30))
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
