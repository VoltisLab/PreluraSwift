import SwiftUI
import UIKit

/// Layout for **iPad** and **Mac** (Designed for iPad / Catalyst / iOS app on Mac): keeps a readable column instead of stretching phone layouts edge-to-edge.
/// Broader UI guidance: `pp/README.md`.
enum WearhouseLayoutMetrics {
    /// Extra horizontal inset inside the centered column (tabs, lists) on wide surfaces.
    static let wideRootHorizontalInset: CGFloat = 8

    /// True for iPad or iOS app on Mac (used for grids and sheets where `horizontalSizeClass` is often `.compact` inside sheets).
    static var isPadOrIOSOnMac: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || ProcessInfo.processInfo.isiOSAppOnMac
    }

    /// iPhone always full width; iPad in compact split uses full width.
    static func shouldApplyCenteredRootColumn(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        guard horizontalSizeClass == .regular else { return false }
        return isPadOrIOSOnMac
    }

    /// Returns `nil` when the UI should stay full-bleed (iPhone, iPad compact split).
    static func rootMaxContentWidth(horizontalSizeClass: UserInterfaceSizeClass?, boundsWidth: CGFloat) -> CGFloat? {
        guard shouldApplyCenteredRootColumn(horizontalSizeClass: horizontalSizeClass) else { return nil }

        let isOnMac = ProcessInfo.processInfo.isiOSAppOnMac
        let sideMargin: CGFloat = isOnMac ? 32 : 24
        let cap: CGFloat = isOnMac ? 1180 : 1024
        let usable = max(320, boundsWidth - sideMargin * 2)
        return min(cap, usable)
    }

    // MARK: - Product / listing grids

    /// Product-style grids: 2 on iPhone; 3 on iPad; 4 on Mac. Uses **idiom**, not `horizontalSizeClass`, so grids stay correct inside sheets (compact size class).
    static func productGridColumnCount(horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        _ = horizontalSizeClass
        if ProcessInfo.processInfo.isiOSAppOnMac { return 4 }
        if UIDevice.current.userInterfaceIdiom == .pad { return 3 }
        return 2
    }

    static func productGridColumns(horizontalSizeClass: UserInterfaceSizeClass?, spacing: CGFloat) -> [GridItem] {
        let n = productGridColumnCount(horizontalSizeClass: horizontalSizeClass)
        return (0..<n).map { _ in GridItem(.flexible(), spacing: spacing) }
    }

    // MARK: - Lookbook square grids (feed / my items / folder saves)

    static let lookbookFeedGridGutter: CGFloat = 2

    /// Square lookbook thumbnails: 3 on iPhone; 4 on iPad; 5 on Mac (idiom-based; see `productGridColumnCount`).
    static func lookbookFeedGridColumnCount(horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        _ = horizontalSizeClass
        if ProcessInfo.processInfo.isiOSAppOnMac { return 5 }
        if UIDevice.current.userInterfaceIdiom == .pad { return 4 }
        return 3
    }

    static func lookbookFeedGridColumns(horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let g = lookbookFeedGridGutter
        let n = lookbookFeedGridColumnCount(horizontalSizeClass: horizontalSizeClass)
        return (0..<n).map { _ in GridItem(.flexible(), spacing: g) }
    }

    // MARK: - Sheets (forms / pickers on iPad & Mac)

    /// Max width for modal sheet *content* so lists and buttons don’t span the full display.
    static let sheetContentMaxWidth: CGFloat = 560

    /// iPad/Mac sheets often report **compact** horizontal size class; still constrain width for readable forms.
    static var shouldConstrainSheetBodyToReadableWidth: Bool { isPadOrIOSOnMac }

    // MARK: - Chat thread (iPad / Mac)

    /// Keeps message bubbles from stretching uncomfortably on wide windows.
    static let chatThreadMaxReadableWidth: CGFloat = 720
}

/// Centers root content and caps width on iPad / Mac so feeds and forms match a “desktop” column, not ultra-wide stretched mobile UI.
struct WearhouseCenteredRootColumnModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if !WearhouseLayoutMetrics.shouldApplyCenteredRootColumn(horizontalSizeClass: horizontalSizeClass) {
            content
        } else {
            GeometryReader { geo in
                let cap = WearhouseLayoutMetrics.rootMaxContentWidth(
                    horizontalSizeClass: horizontalSizeClass,
                    boundsWidth: geo.size.width
                )
                content
                    .frame(maxWidth: cap ?? .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, WearhouseLayoutMetrics.wideRootHorizontalInset)
            }
        }
    }
}

/// Constrains sheet body content to a readable width on iPad / Mac while staying centered.
struct WearhouseSheetContentColumnModifier: ViewModifier {
    func body(content: Content) -> some View {
        if WearhouseLayoutMetrics.shouldConstrainSheetBodyToReadableWidth {
            content
                .frame(maxWidth: WearhouseLayoutMetrics.sheetContentMaxWidth, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            content
        }
    }
}

/// Constrains the main chat column (thread + composer) on iPad / Mac.
struct WearhouseChatThreadReadableWidthModifier: ViewModifier {
    func body(content: Content) -> some View {
        if WearhouseLayoutMetrics.isPadOrIOSOnMac {
            content
                .frame(maxWidth: WearhouseLayoutMetrics.chatThreadMaxReadableWidth, alignment: .center)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// Use on `MainTabView`, `LoginView`, and other full-screen roots (not on sheets that should stay full width).
    func wearhouseCenteredRootColumnIfWide() -> some View {
        modifier(WearhouseCenteredRootColumnModifier())
    }

    /// Use on sheet *content* (e.g. inside `OptionsSheet`) so forms and grids don’t stretch edge-to-edge on iPad / Mac.
    func wearhouseSheetContentColumnIfWide() -> some View {
        modifier(WearhouseSheetContentColumnModifier())
    }

    /// Chat thread + input: readable width on iPad / Mac.
    func wearhouseChatThreadReadableWidthIfPadMac() -> some View {
        modifier(WearhouseChatThreadReadableWidthModifier())
    }
}
