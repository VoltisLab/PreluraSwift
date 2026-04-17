import SwiftUI

/// Reviews list for a user (matches Flutter ReviewScreen / review_tab.dart).
struct ReviewsView: View {
    let username: String
    let rating: Double
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    private let userService = UserService()

    @State private var reviews: [UserReview] = []
    @State private var totalNumber: Int = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: ReviewFilter = .all

    /// Shown for platform automatic reviews (replaces backend reviewer username in the row).
    private static let platformReviewerDisplayName = "Wearhouse"

    /// Summary hero score (large).
    private static let summaryScorePointSize: CGFloat = 52
    /// Main summary stars.
    private static let summaryStarSize: CGFloat = 26
    /// Breakdown row stars.
    private static let breakdownStarSize: CGFloat = 20
    /// Per-review row stars.
    private static let rowStarSize: CGFloat = 22

    private var memberReviews: [UserReview] {
        reviews.filter { !$0.isPlatformAutomaticReview }
    }

    private var automaticReviews: [UserReview] {
        reviews.filter { $0.isPlatformAutomaticReview }
    }

    private var displayedReviews: [UserReview] {
        switch selectedFilter {
        case .all: return reviews
        case .fromMembers: return memberReviews
        case .automatic: return automaticReviews
        }
    }

    private func averageRating(for list: [UserReview]) -> Double {
        guard !list.isEmpty else { return 0 }
        return Double(list.map(\.rating).reduce(0, +)) / Double(list.count)
    }

    enum ReviewFilter: String, Equatable {
        case all = "All"
        case fromMembers = "Members"
        case automatic = "Automatic"
    }

    private static let primaryReviewFilters: [ReviewFilter] = [.all, .fromMembers, .automatic]

    private func reviewFilterTitle(_ filter: ReviewFilter) -> String {
        switch filter {
        case .all: return L10n.string("All")
        case .fromMembers: return L10n.string("Members")
        case .automatic: return L10n.string("Automatic")
        }
    }

    var body: some View {
        Group {
            if isLoading && reviews.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        filterSection
                        ContentDivider()
                        if reviews.isEmpty {
                            Text(L10n.string("No reviews yet"))
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.xl)
                                .padding(.horizontal, Theme.Spacing.md)
                        } else if displayedReviews.isEmpty {
                            Text(L10n.string("No reviews in this category"))
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.xl)
                                .padding(.horizontal, Theme.Spacing.md)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(displayedReviews.enumerated()), id: \.element.id) { index, review in
                                    reviewBlock(review)
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, Theme.Spacing.lg)
                                    if index < displayedReviews.count - 1 {
                                        ContentDivider()
                                    }
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    await loadReviews()
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Reviews"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if let token = authService.authToken {
                userService.updateAuthToken(token)
            }
            Task { await loadReviews() }
        }
        .onChange(of: authService.authToken) { _, new in
            userService.updateAuthToken(new)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.md) {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: Self.summaryScorePointSize, weight: .bold, design: .default))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                HStack(spacing: Theme.Spacing.sm) {
                    FractionalStarRatingDisplay(rating: rating, starSize: Self.summaryStarSize, spacing: 3)
                    Text("(\(totalNumber))")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    reviewBreakdownRow(
                        title: L10n.string("Members"),
                        count: memberReviews.count,
                        avg: averageRating(for: memberReviews)
                    )
                    reviewBreakdownRow(
                        title: L10n.string("Automatic"),
                        count: automaticReviews.count,
                        avg: averageRating(for: automaticReviews)
                    )
                }
                .padding(.top, Theme.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
            ContentDivider()
        }
    }

    private func reviewBreakdownRow(title: String, count: Int, avg: Double) -> some View {
        HStack {
            Text("\(title) (\(count))")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            Text(String(format: "%.1f", avg))
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.secondaryText)
            FractionalStarRatingDisplay(rating: avg, starSize: Self.breakdownStarSize, spacing: 2)
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Self.primaryReviewFilters, id: \.self) { filter in
                    PillTag(
                        title: reviewFilterTitle(filter),
                        isSelected: selectedFilter == filter,
                        accentWhenUnselected: true,
                        action: { selectedFilter = filter }
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    /// Review body, then highlight lines (grey label + icon; divider separates rows).
    private func reviewBlock(_ review: UserReview) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            reviewCardContent(review)
            if !review.highlights.isEmpty {
                reviewHighlightsView(highlights: review.highlights)
            }
        }
    }

    private func reviewHighlightsView(highlights: [String]) -> some View {
        HorizontalFlowLayout(
            horizontalSpacing: Theme.Spacing.lg,
            verticalSpacing: Theme.Spacing.sm
        ) {
            ForEach(highlights, id: \.self) { tag in
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: ReviewHighlightGlyph.sfSymbol(forStoredTag: tag))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text(L10n.string(tag))
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func reviewCardContent(_ review: UserReview) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            avatarView(review)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(review.isPlatformAutomaticReview ? Self.platformReviewerDisplayName : (review.reviewerUsername.isEmpty ? "User" : review.reviewerUsername))
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                    Text(timeAgo(from: review.dateCreated))
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                FractionalStarRatingDisplay(rating: review.rating, starSize: Self.rowStarSize, spacing: 3)
                if !review.comment.isEmpty {
                    Text(review.comment)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.primaryText)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func avatarView(_ review: UserReview) -> some View {
        Group {
            if review.isPlatformAutomaticReview {
                WearhouseSupportBranding.supportAvatar(size: 35)
            } else if let urlString = review.reviewerProfilePictureUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Circle()
                            .fill(Theme.primaryColor.opacity(0.3))
                            .overlay(
                                Text(String(review.reviewerUsername.prefix(1)).uppercased())
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 35, height: 35)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.primaryColor.opacity(0.3))
                    .frame(width: 35, height: 35)
                    .overlay(
                        Text(String(review.reviewerUsername.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
        }
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "1s" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 604800))w"
    }

    private func loadReviews() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { @MainActor in isLoading = false } }
        do {
            let result = try await userService.getUserReviews(username: username)
            await MainActor.run {
                reviews = result.reviews
                totalNumber = result.totalNumber
            }
        } catch {
            await MainActor.run {
                errorMessage = L10n.userFacingError(error)
                reviews = []
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReviewsView(username: "seller1", rating: 4.8)
            .environmentObject(AuthService())
    }
}
