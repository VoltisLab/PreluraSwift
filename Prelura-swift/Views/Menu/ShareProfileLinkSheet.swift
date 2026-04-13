import CoreImage
import SwiftUI
import UIKit

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

/// Modal: avatar, username, stats, QR for profile URL, and copyable link field.
struct ShareProfileLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @State private var user: User?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showCopiedFeedback = false

    private let avatarSize: CGFloat = 96
    private let qrDisplaySize: CGFloat = 180

    var body: some View {
        NavigationStack {
            ZStack {
                ShareProfileAnimatedBackground()
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
                        content(for: user)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done")) { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .task { await loadProfile() }
    }

    @ViewBuilder
    private func content(for user: User) -> some View {
        let linkString = Constants.profileShareWebURL(forUsername: user.username)?.absoluteString ?? ""

        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                profileHeader(user: user)

                statsGrid(user: user)

                if let qrImage = Self.qrCodeImage(from: linkString) {
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
            .padding(.bottom, Theme.Spacing.xl)
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
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedFeedback)
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

    private static func qrCodeImage(from string: String) -> UIImage? {
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
}
