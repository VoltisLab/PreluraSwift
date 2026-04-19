import CoreImage
import Photos
import SwiftUI
import UIKit

private func shareProfileQRCodeImage(from string: String) -> UIImage? {
    guard !string.isEmpty, let data = string.data(using: .utf8) else { return nil }
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let output = filter.outputImage else { return nil }
    let scale = 12.0
    let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let context = CIContext()
    guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cg)
}

// MARK: - Share profile background (animated; distinct from Retro’s coral / mint / gold)

private enum ShareProfileGradientPalette {
    /// Retro uses ~10s half-period; use a different tempo so motion feels separate.
    private static let halfPeriodSeconds: Double = 14

    private static func phase(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSinceReferenceDate
        let period = halfPeriodSeconds * 2
        return CGFloat(0.5 - 0.5 * cos((2 * Double.pi * elapsed) / period))
    }

    /// Cool violet → indigo → deep blue (not Retro’s warm coral / green / gold).
    static func colors(at date: Date, colorScheme: ColorScheme) -> [Color] {
        let t = phase(at: date)
        switch colorScheme {
        case .light:
            let top = lerp(lightTopA, lightTopB, t)
            let mid = lerp(lightMidA, lightMidB, t)
            let bottom = lerp(lightBottomA, lightBottomB, t)
            return [Color(uiColor: top), Color(uiColor: mid), Color(uiColor: bottom)]
        case .dark:
            fallthrough
        @unknown default:
            let top = lerp(darkTopA, darkTopB, t)
            let mid = lerp(darkMidA, darkMidB, t)
            let bottom = lerp(darkBottomA, darkBottomB, t)
            return [Color(uiColor: top), Color(uiColor: mid), Color(uiColor: bottom)]
        }
    }

    /// Midpoint between animated endpoints — sensible defaults when switching to a custom gradient.
    static func defaultCustomColors(for colorScheme: ColorScheme) -> [Color] {
        colors(at: Date(timeIntervalSinceReferenceDate: 0), colorScheme: colorScheme)
    }

    // Dark: rich purple / indigo / midnight blue
    private static let darkTopA = UIColor(red: 0.38, green: 0.20, blue: 0.58, alpha: 1)
    private static let darkTopB = UIColor(red: 0.22, green: 0.32, blue: 0.62, alpha: 1)
    private static let darkMidA = UIColor(red: 0.26, green: 0.22, blue: 0.52, alpha: 1)
    private static let darkMidB = UIColor(red: 0.18, green: 0.36, blue: 0.55, alpha: 1)
    private static let darkBottomA = UIColor(red: 0.10, green: 0.14, blue: 0.32, alpha: 1)
    private static let darkBottomB = UIColor(red: 0.08, green: 0.22, blue: 0.38, alpha: 1)

    // Light: airy lavender / periwinkle (still readable with dark primary text)
    private static let lightTopA = UIColor(red: 0.93, green: 0.90, blue: 0.99, alpha: 1)
    private static let lightTopB = UIColor(red: 0.88, green: 0.92, blue: 1.0, alpha: 1)
    private static let lightMidA = UIColor(red: 0.86, green: 0.89, blue: 0.99, alpha: 1)
    private static let lightMidB = UIColor(red: 0.82, green: 0.93, blue: 0.98, alpha: 1)
    private static let lightBottomA = UIColor(red: 0.80, green: 0.90, blue: 0.97, alpha: 1)
    private static let lightBottomB = UIColor(red: 0.78, green: 0.88, blue: 0.95, alpha: 1)

    private static func lerp(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        let u = max(0, min(1, t))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * u,
            green: g1 + (g2 - g1) * u,
            blue: b1 + (b2 - b1) * u,
            alpha: 1
        )
    }
}

private struct ShareProfileAnimatedBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            LinearGradient(
                colors: ShareProfileGradientPalette.colors(at: context.date, colorScheme: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct ShareProfileCustomGradientBackground: View {
    var top: Color
    var middle: Color
    var bottom: Color
    /// Gradient line passes through the center; start/end are on the unit circle (degrees).
    var startAngleDegrees: Double
    var endAngleDegrees: Double

    var body: some View {
        let rs = startAngleDegrees * .pi / 180
        let re = endAngleDegrees * .pi / 180
        let start = UnitPoint(x: 0.5 + 0.5 * cos(rs), y: 0.5 + 0.5 * sin(rs))
        let end = UnitPoint(x: 0.5 + 0.5 * cos(re), y: 0.5 + 0.5 * sin(re))
        LinearGradient(colors: [top, middle, bottom], startPoint: start, endPoint: end)
    }
}

// MARK: - Gradient settings helpers

/// Manual panel navigation — avoids nesting `NavigationStack` inside a `NavigationLink` destination (which can pop the parent).
private enum ShareProfileGradientPanelStep: Equatable {
    case list
    case topColor
    case midColor
    case bottomColor
    case rotation
    case angle
}

private struct ShareProfileGradientEditorBackBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.primaryColor)
            }
            .buttonStyle(.plain)
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.primaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

private func shareProfileAngleCodeLine(_ degrees: Double) -> String {
    "\(Int(degrees.rounded()))°"
}

private func shareProfileUIColorRGB(_ color: Color) -> (r: Double, g: Double, b: Double) {
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    return (Double(r), Double(g), Double(b))
}

private func shareProfileColor(r: Double, g: Double, b: Double) -> Color {
    Color(red: r, green: g, blue: b)
}

private func shareProfileHexString(r: Double, g: Double, b: Double) -> String {
    let ri = Int(round(r * 255.0))
    let gi = Int(round(g * 255.0))
    let bi = Int(round(b * 255.0))
    return String(format: "#%02X%02X%02X", ri, gi, bi)
}

private func shareProfileHexString(from color: Color) -> String {
    let x = shareProfileUIColorRGB(color)
    return shareProfileHexString(r: x.r, g: x.g, b: x.b)
}

private func shareProfileCommentStyleCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.chatInlineCardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
}

private func shareProfileMasterControlRowLabel(title: String, codeLine: String?, swatch: Color?) -> some View {
    HStack(spacing: Theme.Spacing.sm) {
        if let swatch {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(swatch)
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
        }
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Typography.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.primaryText)
            if let codeLine {
                Text(codeLine)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Colors.tertiaryText)
    }
}

/// Gradient settings list — uses `Button` + `panelStep` instead of `NavigationLink` so the parent `NavigationLink` (Profile → Share) is not popped.
private struct ShareProfileGradientSettingsList: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var panelStep: ShareProfileGradientPanelStep
    @Binding var useAnimatedBackground: Bool
    @Binding var topGradientColor: Color
    @Binding var midGradientColor: Color
    @Binding var bottomGradientColor: Color
    @Binding var gradientStartAngleDegrees: Double
    @Binding var gradientEndAngleDegrees: Double

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                shareProfileCommentStyleCard {
                    Toggle(L10n.string("Animate gradient"), isOn: $useAnimatedBackground)
                        .tint(Theme.primaryColor)
                        .onChange(of: useAnimatedBackground) { _, isAnimated in
                            if !isAnimated {
                                let snap = ShareProfileGradientPalette.colors(at: Date(), colorScheme: colorScheme)
                                if snap.count == 3 {
                                    topGradientColor = snap[0]
                                    midGradientColor = snap[1]
                                    bottomGradientColor = snap[2]
                                }
                            }
                        }
                }

                if !useAnimatedBackground {
                    shareProfileCommentStyleCard {
                        Button {
                            panelStep = .topColor
                        } label: {
                            shareProfileMasterControlRowLabel(
                                title: L10n.string("Top colour"),
                                codeLine: shareProfileHexString(from: topGradientColor),
                                swatch: topGradientColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    shareProfileCommentStyleCard {
                        Button {
                            panelStep = .midColor
                        } label: {
                            shareProfileMasterControlRowLabel(
                                title: L10n.string("Middle colour"),
                                codeLine: shareProfileHexString(from: midGradientColor),
                                swatch: midGradientColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    shareProfileCommentStyleCard {
                        Button {
                            panelStep = .bottomColor
                        } label: {
                            shareProfileMasterControlRowLabel(
                                title: L10n.string("Bottom colour"),
                                codeLine: shareProfileHexString(from: bottomGradientColor),
                                swatch: bottomGradientColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    shareProfileCommentStyleCard {
                        Button {
                            panelStep = .rotation
                        } label: {
                            shareProfileMasterControlRowLabel(
                                title: L10n.string("Rotation"),
                                codeLine: shareProfileAngleCodeLine(gradientStartAngleDegrees),
                                swatch: nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    shareProfileCommentStyleCard {
                        Button {
                            panelStep = .angle
                        } label: {
                            shareProfileMasterControlRowLabel(
                                title: L10n.string("Angle"),
                                codeLine: shareProfileAngleCodeLine(gradientEndAngleDegrees),
                                swatch: nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .scrollContentBackground(.hidden)
    }
}

private struct ShareProfileGradientOverlayPanelContent: View {
    @Binding var panelStep: ShareProfileGradientPanelStep
    @Binding var useAnimatedBackground: Bool
    @Binding var topGradientColor: Color
    @Binding var midGradientColor: Color
    @Binding var bottomGradientColor: Color
    @Binding var gradientStartAngleDegrees: Double
    @Binding var gradientEndAngleDegrees: Double

    var body: some View {
        Group {
            switch panelStep {
            case .list:
                ShareProfileGradientSettingsList(
                    panelStep: $panelStep,
                    useAnimatedBackground: $useAnimatedBackground,
                    topGradientColor: $topGradientColor,
                    midGradientColor: $midGradientColor,
                    bottomGradientColor: $bottomGradientColor,
                    gradientStartAngleDegrees: $gradientStartAngleDegrees,
                    gradientEndAngleDegrees: $gradientEndAngleDegrees
                )
            case .topColor:
                ShareProfileRGBEditorPage(
                    title: L10n.string("Top colour"),
                    color: $topGradientColor,
                    onBack: { panelStep = .list }
                )
            case .midColor:
                ShareProfileRGBEditorPage(
                    title: L10n.string("Middle colour"),
                    color: $midGradientColor,
                    onBack: { panelStep = .list }
                )
            case .bottomColor:
                ShareProfileRGBEditorPage(
                    title: L10n.string("Bottom colour"),
                    color: $bottomGradientColor,
                    onBack: { panelStep = .list }
                )
            case .rotation:
                ShareProfileAngleEditorPage(
                    title: L10n.string("Rotation"),
                    subtitle: L10n.string("Gradient start on colour wheel"),
                    degrees: $gradientStartAngleDegrees,
                    onBack: { panelStep = .list }
                )
            case .angle:
                ShareProfileAngleEditorPage(
                    title: L10n.string("Angle"),
                    subtitle: L10n.string("Gradient end on colour wheel"),
                    degrees: $gradientEndAngleDegrees,
                    onBack: { panelStep = .list }
                )
            }
        }
    }
}

/// System sheet with clear glass-style chrome: transparent sheet background + liquid-glass close in toolbar (no nested `NavigationLink` rows).
private struct ShareProfileGradientSettingsSheetHost: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var panelStep: ShareProfileGradientPanelStep
    @Binding var useAnimatedBackground: Bool
    @Binding var topGradientColor: Color
    @Binding var midGradientColor: Color
    @Binding var bottomGradientColor: Color
    @Binding var gradientStartAngleDegrees: Double
    @Binding var gradientEndAngleDegrees: Double

    var body: some View {
        NavigationStack {
            ShareProfileGradientOverlayPanelContent(
                panelStep: $panelStep,
                useAnimatedBackground: $useAnimatedBackground,
                topGradientColor: $topGradientColor,
                midGradientColor: $midGradientColor,
                bottomGradientColor: $bottomGradientColor,
                gradientStartAngleDegrees: $gradientStartAngleDegrees,
                gradientEndAngleDegrees: $gradientEndAngleDegrees
            )
            .navigationTitle(panelStep == .list ? L10n.string("Background") : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.selection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Colors.primaryText)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.interactive(false), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("Close"))
                }
            }
        }
        .onDisappear {
            panelStep = .list
        }
    }
}

private struct ShareProfileVerticalRGBSliders: View {
    @Binding var r: Double
    @Binding var g: Double
    @Binding var b: Double

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            verticalChannel(label: "R", value: $r, tint: Color.red)
            verticalChannel(label: "G", value: $g, tint: Color.green)
            verticalChannel(label: "B", value: $b, tint: Color.blue)
        }
        .frame(maxWidth: .infinity)
    }

    private func verticalChannel(label: String, value: Binding<Double>, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.Colors.secondaryText)
            ZStack {
                Slider(value: value, in: 0 ... 1)
                    .tint(tint)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 168, height: 28)
            }
            .frame(width: 36, height: 168)
            Text("\(Int(round(value.wrappedValue * 255)))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
    }
}

// MARK: - Pushed page: avatar, stats, QR, copyable link, gradient controls, image export

/// Full-screen share profile (push from settings or invite). Not presented as a modal sheet.
struct ShareProfileLinkView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authService: AuthService

    @State private var user: User?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showCopiedFeedback = false

    @State private var useAnimatedBackground = true
    @State private var topGradientColor = Color.purple
    @State private var midGradientColor = Color.indigo
    @State private var bottomGradientColor = Color(red: 0.1, green: 0.14, blue: 0.32)
    /// Gradient stops on unit circle (degrees). Default matches previous single-angle 45° (end) / 225° (start).
    @State private var gradientStartAngleDegrees: Double = 225
    @State private var gradientEndAngleDegrees: Double = 45

    @State private var showGradientSettingsSheet = false
    @State private var gradientSettingsPanelStep: ShareProfileGradientPanelStep = .list
    @State private var isExporting = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var exportErrorMessage: String?
    @State private var showExportSuccessToast = false
    @State private var didApplyInitialGradientColors = false

    private let avatarSize: CGFloat = 96
    private let qrDisplaySize: CGFloat = 180
    private let exportWidth: CGFloat = 390

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            Group {
                if isLoading {
                    ProgressView()
                        .tint(Theme.primaryColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    Text(loadError)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(Theme.Spacing.lg)
                } else if let user {
                    loadedContent(user: user)
                } else {
                    Text(L10n.string("Couldn't load profile"))
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(L10n.string("Share profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await exportAndShare() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .disabled(isLoading || user == nil || isExporting)
                .accessibilityLabel(L10n.string("Share image…"))

                Button {
                    Task { await exportShareImage() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .disabled(isLoading || user == nil || isExporting)
                .accessibilityLabel(L10n.string("Save share image"))
            }
        }
        .wearhouseSheetContentColumnIfWide()
        .task { await loadProfile() }
        .onAppear {
            guard !didApplyInitialGradientColors else { return }
            didApplyInitialGradientColors = true
            let defaults = ShareProfileGradientPalette.defaultCustomColors(for: colorScheme)
            if defaults.count == 3 {
                topGradientColor = defaults[0]
                midGradientColor = defaults[1]
                bottomGradientColor = defaults[2]
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareProfileActivityView(activityItems: shareItems)
                .wearhouseSheetContentColumnIfWide()
        }
        .sheet(isPresented: $showGradientSettingsSheet) {
            ShareProfileGradientSettingsSheetHost(
                panelStep: $gradientSettingsPanelStep,
                useAnimatedBackground: $useAnimatedBackground,
                topGradientColor: $topGradientColor,
                midGradientColor: $midGradientColor,
                bottomGradientColor: $bottomGradientColor,
                gradientStartAngleDegrees: $gradientStartAngleDegrees,
                gradientEndAngleDegrees: $gradientEndAngleDegrees
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
            .wearhouseSheetContentColumnIfWide()
        }
        .alert(L10n.string("Couldn't save image"), isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: {
            if let exportErrorMessage {
                Text(exportErrorMessage)
            }
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if useAnimatedBackground {
            ShareProfileAnimatedBackground()
        } else {
            ShareProfileCustomGradientBackground(
                top: topGradientColor,
                middle: midGradientColor,
                bottom: bottomGradientColor,
                startAngleDegrees: gradientStartAngleDegrees,
                endAngleDegrees: gradientEndAngleDegrees
            )
        }
    }

    private func loadedContent(user: User) -> some View {
        let linkString = Constants.profileShareWebURL(forUsername: user.username)?.absoluteString ?? ""

        return ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    profileHeader(user: user)

                    statsGrid(user: user)

                    if let qrImage = shareProfileQRCodeImage(from: linkString) {
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: qrDisplaySize, height: qrDisplaySize)
                            .padding(Theme.Spacing.sm)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    linkField(urlString: linkString)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 96)
            }

            shareProfileGradientSettingsFAB
                .padding(.trailing, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
        }
        .overlay(alignment: .top) {
            if showCopiedFeedback {
                Text(L10n.string("Link copied"))
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.primaryColor)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if showExportSuccessToast {
                Text(L10n.string("Image saved to Photos"))
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.top, showCopiedFeedback ? 48 : 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedFeedback)
        .animation(.easeInOut(duration: 0.2), value: showExportSuccessToast)
    }

    private var shareProfileGradientSettingsFAB: some View {
        Button {
            HapticManager.selection()
            gradientSettingsPanelStep = .list
            showGradientSettingsSheet = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(width: 54, height: 54)
                .glassEffect(.regular.interactive(false), in: .ellipse)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(L10n.string("Background settings"))
    }

    private func profileHeader(user: User) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Group {
                if let urlString = user.avatarURL, !urlString.isEmpty, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: avatarSize, height: avatarSize)
                                .overlay { ProgressView() }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            avatarPlaceholder
                        @unknown default:
                            avatarPlaceholder
                        }
                    }
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }
            }
            .overlay(
                Circle()
                    .stroke(Theme.Colors.profileRingBorder, lineWidth: 2)
                    .frame(width: avatarSize, height: avatarSize)
            )

            Text("@\(user.username)")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.sm)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Theme.Colors.secondaryBackground)
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Colors.tertiaryText)
            )
    }

    private func statsGrid(user: User) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
            ],
            spacing: Theme.Spacing.sm
        ) {
            statCell(value: user.reviewCount, label: L10n.string("Reviews"))
            statCell(value: user.listingsCount, label: L10n.string("Listings"))
            statCell(value: user.followingsCount, label: L10n.string("Following"))
            statCell(value: user.followersCount, label: user.followersCount == 1 ? L10n.string("Follower") : L10n.string("Followers"))
        }
    }

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.primaryText)
            Text(label)
                .font(Theme.Typography.footnote)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous))
    }

    private func linkField(urlString: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(L10n.string("Profile link"))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)

            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                TextField("", text: .constant(urlString), axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(3 ... 5)
                    .disabled(true)
                    .textSelection(.enabled)

                Button {
                    copyLink(urlString)
                } label: {
                    Label(L10n.string("Copy link"), systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Theme.primaryColor)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("Copy link"))
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous))
        }
    }

    private func copyLink(_ string: String) {
        guard !string.isEmpty else { return }
        UIPasteboard.general.string = string
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showCopiedFeedback = true
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run { showCopiedFeedback = false }
        }
    }

    // MARK: - Export

    private func gradientForExport() -> (colors: [Color], start: UnitPoint, end: UnitPoint) {
        if useAnimatedBackground {
            let colors = ShareProfileGradientPalette.colors(at: Date(), colorScheme: colorScheme)
            return (colors, .topLeading, .bottomTrailing)
        }
        let rs = gradientStartAngleDegrees * .pi / 180
        let re = gradientEndAngleDegrees * .pi / 180
        let start = UnitPoint(x: 0.5 + 0.5 * cos(rs), y: 0.5 + 0.5 * sin(rs))
        let end = UnitPoint(x: 0.5 + 0.5 * cos(re), y: 0.5 + 0.5 * sin(re))
        return ([topGradientColor, midGradientColor, bottomGradientColor], start, end)
    }

    @MainActor
    private func renderExportUIImage(for exportUser: User, linkString: String) -> UIImage? {
        let spec = gradientForExport()
        let exportBody = ShareProfileExportCard(
            user: exportUser,
            linkString: linkString,
            gradientColors: spec.colors,
            startPoint: spec.start,
            endPoint: spec.end,
            avatarSize: avatarSize,
            qrDisplaySize: qrDisplaySize
        )
        .environment(\.colorScheme, colorScheme)
        .frame(width: exportWidth)

        let renderer = ImageRenderer(content: exportBody)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    @MainActor
    private func exportShareImage() async {
        guard let user else { return }
        let linkString = Constants.profileShareWebURL(forUsername: user.username)?.absoluteString ?? ""
        isExporting = true
        defer { isExporting = false }
        guard let image = renderExportUIImage(for: user, linkString: linkString) else {
            exportErrorMessage = L10n.string("Couldn't create image.")
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            exportErrorMessage = L10n.string("Photos access is required to save the image.")
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showExportSuccessToast = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showExportSuccessToast = false
        } catch {
            exportErrorMessage = L10n.userFacingError(error)
        }
    }

    @MainActor
    private func exportAndShare() async {
        guard let user else { return }
        let linkString = Constants.profileShareWebURL(forUsername: user.username)?.absoluteString ?? ""
        isExporting = true
        defer { isExporting = false }
        guard let image = renderExportUIImage(for: user, linkString: linkString) else {
            exportErrorMessage = L10n.string("Couldn't create image.")
            return
        }
        shareItems = [image]
        showShareSheet = true
    }

    @MainActor
    private func loadProfile() async {
        guard let token = authService.authToken, !token.isEmpty else {
            isLoading = false
            loadError = L10n.string("Sign in to share your profile.")
            return
        }
        let client = GraphQLClient()
        client.setAuthToken(token)
        let service = UserService(client: client)
        do {
            let fetched = try await service.getUser()
            user = fetched
            isLoading = false
            loadError = nil
        } catch {
            isLoading = false
            loadError = L10n.userFacingError(error)
        }
    }

}

// MARK: - Modal sheets (RGB + angle)

/// RGB editor with inline back bar (no nested `NavigationStack`).
private struct ShareProfileRGBEditorPage: View {
    let title: String
    @Binding var color: Color
    let onBack: () -> Void

    @State private var r = 0.0
    @State private var g = 0.0
    @State private var b = 0.0
    @State private var hexText = ""

    var body: some View {
        VStack(spacing: 0) {
            ShareProfileGradientEditorBackBar(title: title, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    ShareProfileVerticalRGBSliders(r: $r, g: $g, b: $b)
                        .padding(.top, Theme.Spacing.sm)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("Colour code"))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        TextField("#RRGGBB", text: $hexText)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous)
                                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                            )
                            .onSubmit { applyHexFromField() }
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
        .onAppear {
            syncFromColor()
        }
        .onChange(of: r) { _, _ in syncToColorFromSliders() }
        .onChange(of: g) { _, _ in syncToColorFromSliders() }
        .onChange(of: b) { _, _ in syncToColorFromSliders() }
    }

    private func syncFromColor() {
        let x = shareProfileUIColorRGB(color)
        r = x.r
        g = x.g
        b = x.b
        hexText = shareProfileHexString(r: r, g: g, b: b)
    }

    private func syncToColorFromSliders() {
        color = shareProfileColor(r: r, g: g, b: b)
        hexText = shareProfileHexString(r: r, g: g, b: b)
    }

    private func applyHexFromField() {
        guard let parsed = shareProfileParseHexRGB(hexText) else { return }
        r = parsed.r
        g = parsed.g
        b = parsed.b
        color = shareProfileColor(r: r, g: g, b: b)
        hexText = shareProfileHexString(r: r, g: g, b: b)
    }
}

private func shareProfileParseHexRGB(_ raw: String) -> (r: Double, g: Double, b: Double)? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    let r = Double((v >> 16) & 0xFF) / 255.0
    let g = Double((v >> 8) & 0xFF) / 255.0
    let b = Double(v & 0xFF) / 255.0
    return (r, g, b)
}

private struct ShareProfileAngleEditorPage: View {
    let title: String
    let subtitle: String
    @Binding var degrees: Double
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ShareProfileGradientEditorBackBar(title: title, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    HStack {
                        Spacer()
                        ZStack {
                            Slider(value: $degrees, in: 0 ... 360, step: 1)
                                .tint(Theme.primaryColor)
                                .rotationEffect(.degrees(-90))
                                .frame(width: 200, height: 28)
                        }
                        .frame(width: 36, height: 200)
                        Spacer()
                    }
                    .padding(.vertical, Theme.Spacing.sm)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("Code"))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Text("\(Int(degrees.rounded()))°")
                            .font(.system(.title2, design: .monospaced))
                            .foregroundStyle(Theme.Colors.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous)
                                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                            )
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
    }
}

// MARK: - Export card (matches on-screen layout; rendered off-screen for ImageRenderer)

private struct ShareProfileExportCard: View {
    let user: User
    let linkString: String
    let gradientColors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    let avatarSize: CGFloat
    let qrDisplaySize: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: startPoint, endPoint: endPoint)
            VStack(spacing: Theme.Spacing.lg) {
                exportProfileHeader
                exportStatsGrid
                if let qrImage = shareProfileQRCodeImage(from: linkString) {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: qrDisplaySize, height: qrDisplaySize)
                        .padding(Theme.Spacing.sm)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                exportLinkBlock
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xl)
        }
        .frame(minHeight: 720)
    }

    private var exportProfileHeader: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Group {
                if let urlString = user.avatarURL, !urlString.isEmpty, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: avatarSize, height: avatarSize)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            exportAvatarPlaceholder
                        @unknown default:
                            exportAvatarPlaceholder
                        }
                    }
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                } else {
                    exportAvatarPlaceholder
                }
            }
            .overlay(
                Circle()
                    .stroke(Theme.Colors.profileRingBorder, lineWidth: 2)
                    .frame(width: avatarSize, height: avatarSize)
            )

            Text("@\(user.username)")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.sm)
    }

    private var exportAvatarPlaceholder: some View {
        Circle()
            .fill(Theme.Colors.secondaryBackground)
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Colors.tertiaryText)
            )
    }

    private var exportStatsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
            ],
            spacing: Theme.Spacing.sm
        ) {
            exportStatCell(value: user.reviewCount, label: L10n.string("Reviews"))
            exportStatCell(value: user.listingsCount, label: L10n.string("Listings"))
            exportStatCell(value: user.followingsCount, label: L10n.string("Following"))
            exportStatCell(value: user.followersCount, label: user.followersCount == 1 ? L10n.string("Follower") : L10n.string("Followers"))
        }
    }

    private func exportStatCell(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.primaryText)
            Text(label)
                .font(Theme.Typography.footnote)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous))
    }

    private var exportLinkBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(L10n.string("Profile link"))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
            Text(linkString)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.primaryText)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous))
    }
}

// MARK: - Share sheet

private struct ShareProfileActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Legacy sheet type name — use ``ShareProfileLinkView`` pushed from navigation.
typealias ShareProfileLinkSheet = ShareProfileLinkView
