import SwiftUI
import Shimmer

/// Other user's profile – same layout as ProfileView (read-only: no menu, no photo edit).
struct UserProfileView: View {
    let seller: User
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel: UserProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBrand: String? = nil
    @State private var expandedCategories: Bool = false
    @State private var selectedCategory: String? = nil
    @State private var profileSort: ProfileSortOption = .newestFirst
    @State private var filterCondition: String? = nil
    @State private var filterMinPrice: String = ""
    @State private var filterMaxPrice: String = ""
    @State private var showSortSheet: Bool = false
    @State private var showFilterSheet: Bool = false
    @State private var topBrandsScrollId: String? = nil
    @State private var showProfilePhotoFullScreen: Bool = false
    @State private var showFullBioSheet: Bool = false
    @State private var filterMultiBuyOnly: Bool = false

    init(seller: User, authService: AuthService?) {
        self.seller = seller
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(seller: seller, authService: authService))
    }

    var body: some View {
        ScrollView {
                if viewModel.isLoading && viewModel.items.isEmpty && viewModel.errorMessage == nil {
                    ProfileShimmerView()
                } else {
                    VStack(spacing: 0) {
                        profileHeaderSection
                        if let bio = viewModel.user.bio, !bio.isEmpty {
                            bioSection(bio)
                        }
                        if let location = viewModel.user.location, !location.isEmpty {
                            profileLocationRow(location)
                        }
                        if viewModel.user.isVacationMode {
                            vacationModeSection(isLoggedInUser: false)
                        } else {
                            followRow
                            filtersSection
                            itemsGridSection
                        }
                    }
                }
                if let message = viewModel.errorMessage, !viewModel.items.isEmpty {
                    Text(message)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .navigationTitle(viewModel.user.username)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ReportUserView(username: viewModel.user.username)) {
                    Image(systemName: "flag")
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await viewModel.refreshAsync() }
        .onAppear {
            viewModel.load()
        }
        .fullScreenCover(isPresented: $showProfilePhotoFullScreen) {
            if let urlString = viewModel.user.avatarURL, !urlString.isEmpty {
                FullScreenImageViewer(
                    imageURLs: [urlString],
                    selectedIndex: .constant(0),
                    onDismiss: { showProfilePhotoFullScreen = false }
                )
            }
        }
    }

    private static let profilePhotoSize: CGFloat = 88

    private var profileHeaderSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .center, spacing: 0) {
                Group {
                    if let urlString = viewModel.user.avatarURL, !urlString.isEmpty, let url = URL(string: urlString) {
                        Button(action: { showProfilePhotoFullScreen = true }) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Circle()
                                        .fill(Theme.Colors.secondaryBackground)
                                        .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
                                        .shimmering()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
                                        .clipShape(Circle())
                                case .failure:
                                    profilePhotoPlaceholder
                                @unknown default:
                                    profilePhotoPlaceholder
                                }
                            }
                            .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
                        }
                        .buttonStyle(.plain)
                    } else {
                        profilePhotoPlaceholder
                    }
                }

                Spacer(minLength: Theme.Spacing.xl)

                HStack(spacing: Theme.Spacing.md) {
                    StatColumn(value: "\(viewModel.items.count)", label: viewModel.items.count == 1 ? L10n.string("Listing") : L10n.string("Listings"), compact: true)
                    NavigationLink(destination: FollowingListView(username: viewModel.user.username)) {
                        StatColumn(value: "\(viewModel.user.followingsCount)", label: L10n.string("Following"), compact: true)
                    }
                    .buttonStyle(.plain)
                    NavigationLink(destination: FollowersListView(username: viewModel.user.username)) {
                        StatColumn(value: "\(viewModel.displayedFollowersCount)", label: viewModel.displayedFollowersCount == 1 ? L10n.string("Follower") : L10n.string("Followers"), compact: true)
                    }
                    .buttonStyle(.plain)
                }
                .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: Theme.Spacing.xl)
            }

            VStack(alignment: .leading, spacing: 2) {
                let hasSaleItems = viewModel.items.contains { $0.discountPercentage != nil }
                NavigationLink(value: AppRoute.reviews(username: viewModel.user.username, rating: viewModel.user.rating)) {
                    HStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text("(\(viewModel.user.reviewCount))")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: true)
                        if hasSaleItems {
                            Spacer(minLength: 4)
                            Image("SaleIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 16)
                        }
                    }
                }
                .buttonStyle(HapticTapButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    /// Placeholder when no photo or load failed (matches profile placeholder: circle + initial).
    private var profilePhotoPlaceholder: some View {
        Circle()
            .fill(Theme.primaryColor)
            .frame(width: Self.profilePhotoSize, height: Self.profilePhotoSize)
            .overlay(
                Text(String(viewModel.user.username.prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    /// Location row: grey location icon + text, shown below bio.
    private func profileLocationRow(_ location: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "location.fill")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.secondaryText)
            Text(location)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func bioSection(_ bio: String) -> some View {
        let limit = 100
        let truncated = bio.count > limit
        let displayText = truncated ? String(bio.prefix(limit)) + "..." : bio
        return Group {
            if truncated {
                Button(action: { showFullBioSheet = true }) {
                    Text(displayText)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.xs)
                        .padding(.bottom, Theme.Spacing.sm)
                }
                .buttonStyle(.plain)
            } else {
                Text(displayText)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
                    .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .sheet(isPresented: $showFullBioSheet) {
            NavigationStack {
                ScrollView {
                    Text(bio)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                }
                .navigationTitle(L10n.string("Bio"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.string("Done")) { showFullBioSheet = false }
                            .foregroundColor(Theme.primaryColor)
                    }
                }
            }
        }
    }

    /// Placeholder when no photo or load failed (matches profile placeholder: circle + initial).
    private func vacationModeSection(isLoggedInUser: Bool) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: 40)
            Image(systemName: "umbrella.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.secondaryText)
            Text(isLoggedInUser ? L10n.string("Vacation mode turned on") : L10n.string("This member is on vacation"))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    /// Follow / Following row with switch, above Categories. Only meaningful when viewing another user (we have userId).
    private var followRow: some View {
        HStack {
            Text(viewModel.isFollowing ? L10n.string("Following") : L10n.string("Follow"))
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
            Spacer()
            if viewModel.user.userId != nil {
                if viewModel.isTogglingFollow {
                    ProgressView()
                        .scaleEffect(0.9)
                } else {
                    Toggle("", isOn: Binding(
                        get: { viewModel.isFollowing },
                        set: { _ in
                            Task {
                                await viewModel.toggleFollow(authToken: authService.authToken)
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(Theme.primaryColor)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .overlay(ContentDivider(), alignment: .bottom)
    }

    // MARK: - Filters Section (Categories, Multi-buy read-only, Top brands, Filter/Sort)
    private var filtersSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        expandedCategories.toggle()
                    }
                }) {
                    HStack {
                        Text(L10n.string("Categories"))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        Spacer()
                        Image(systemName: expandedCategories ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(PlainButtonStyle())

                if expandedCategories {
                    VStack(spacing: 0) {
                        ForEach(viewModel.categoriesWithCounts, id: \.name) { category in
                            Button(action: {
                                selectedCategory = selectedCategory == category.name ? nil : category.name
                            }) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.Colors.secondaryText)
                                    Text(category.name)
                                        .font(Theme.Typography.subheadline)
                                        .foregroundColor(Theme.Colors.primaryText)
                                    Text("(\(category.count) \(category.count == 1 ? L10n.string("item") : L10n.string("items"))")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                    Spacer(minLength: Theme.Spacing.md)
                                    Image(systemName: selectedCategory == category.name ? "checkmark.square" : "square")
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedCategory == category.name ? Theme.primaryColor : Theme.Colors.secondaryText)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md)
                            }
                            .buttonStyle(PlainButtonStyle())
                            if category.name != viewModel.categoriesWithCounts.last?.name {
                                ContentDivider()
                                    .padding(.leading, Theme.Spacing.md)
                            }
                        }
                    }
                }
            }
            .overlay(ContentDivider(), alignment: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    Text(L10n.string("Top brands"))
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Spacer()
                    if viewModel.user.isMultibuyEnabled {
                        Button(action: {
                            HapticManager.selection()
                            filterMultiBuyOnly.toggle()
                        }) {
                            Text(L10n.string("Multi-buy"))
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(filterMultiBuyOnly ? .white : Theme.primaryColor)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Glass.tagCornerRadius)
                                        .fill(filterMultiBuyOnly ? Theme.primaryColor : Theme.primaryColor.opacity(0.2))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.topBrands, id: \.self) { brand in
                            BrandFilterPill(
                                brand: brand,
                                isSelected: selectedBrand == brand,
                                action: { selectedBrand = selectedBrand == brand ? nil : brand }
                            )
                            .id(brand)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .scrollPosition(id: $topBrandsScrollId, anchor: .leading)
                .id("user_profile_top_brands_pills")
                .padding(.vertical, Theme.Spacing.sm)
            }

            // Filter and Sort (grey pills, no shadow)
            HStack {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14))
                        Text(L10n.string("Filter"))
                            .font(Theme.Typography.subheadline)
                    }
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                            .fill(Theme.Colors.secondaryBackground)
                    )
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
                Spacer()
                Button(action: { showSortSheet = true }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(L10n.string(profileSort.rawValue))
                            .font(Theme.Typography.subheadline)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                            .fill(Theme.Colors.secondaryBackground)
                    )
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .sheet(isPresented: $showSortSheet) { userProfileSortSheet }
        .sheet(isPresented: $showFilterSheet) { userProfileFilterSheet }
    }

    private var optionDivider: some View {
        Rectangle()
            .fill(Theme.Colors.glassBorder)
            .frame(height: 0.5)
            .padding(.horizontal, Theme.Spacing.md)
    }

    private var userProfileSortSheet: some View {
        OptionsSheet(title: L10n.string("Sort"), onDismiss: { showSortSheet = false }, detents: [.height(380)], useCustomCornerRadius: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ProfileSortOption.allCases.enumerated()), id: \.offset) { index, option in
                    Button(action: { profileSort = option }) {
                        HStack {
                            Text(L10n.string(option.rawValue))
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if profileSort == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.primaryColor)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                    }
                    .buttonStyle(.plain)
                    if index < ProfileSortOption.allCases.count - 1 { optionDivider }
                }
                optionDivider
                VStack(spacing: Theme.Spacing.sm) {
                    BorderGlassButton(L10n.string("Clear")) {
                        profileSort = .relevance
                    }
                    PrimaryGlassButton(L10n.string("Apply")) {
                        showSortSheet = false
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
            .background(
                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                    .fill(Theme.Colors.background)
            )
        }
    }

    private var userProfileFilterSheet: some View {
        OptionsSheet(title: L10n.string("Filter"), onDismiss: { showFilterSheet = false }, detents: [.height(580)], useCustomCornerRadius: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.string("Condition"))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
                ForEach(profileConditionOptions, id: \.raw) { option in
                    Button(action: { filterCondition = filterCondition == option.raw ? nil : option.raw }) {
                        HStack {
                            Text(L10n.string(option.display))
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if filterCondition == option.raw {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.primaryColor)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                    }
                    .buttonStyle(.plain)
                    optionDivider
                }
                Text(L10n.string("Price range"))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                HStack(spacing: Theme.Spacing.sm) {
                    SettingsTextField(placeholder: L10n.string("Min. Price"), text: $filterMinPrice, bordered: true)
                        .keyboardType(.decimalPad)
                    SettingsTextField(placeholder: L10n.string("Max. Price"), text: $filterMaxPrice, bordered: true)
                        .keyboardType(.decimalPad)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                optionDivider
                VStack(spacing: Theme.Spacing.sm) {
                    BorderGlassButton(L10n.string("Clear")) {
                        filterCondition = nil
                        filterMinPrice = ""
                        filterMaxPrice = ""
                    }
                    PrimaryGlassButton(L10n.string("Apply")) {
                        showFilterSheet = false
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
            }
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
            .background(
                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                    .fill(Theme.Colors.background)
            )
        }
    }

    // MARK: - Items Grid
    private var itemsGridSection: some View {
        var items = viewModel.items
        if let selectedBrand = selectedBrand { items = items.filter { $0.brand == selectedBrand } }
        if let selectedCategory = selectedCategory {
            items = items.filter { ($0.categoryName ?? $0.category.name) == selectedCategory }
        }
        if let cond = filterCondition { items = items.filter { $0.condition.uppercased() == cond.uppercased() } }
        let minP = Double(filterMinPrice.replacingOccurrences(of: ",", with: "."))
        let maxP = Double(filterMaxPrice.replacingOccurrences(of: ",", with: "."))
        if let min = minP, min > 0 { items = items.filter { $0.price >= min } }
        if let max = maxP, max > 0 { items = items.filter { $0.price <= max } }
        switch profileSort {
        case .relevance: break
        case .newestFirst: items = items.sorted { $0.createdAt > $1.createdAt }
        case .priceAsc: items = items.sorted { $0.price < $1.price }
        case .priceDesc: items = items.sorted { $0.price > $1.price }
        }
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm)
            ],
            spacing: Theme.Spacing.md
        ) {
            ForEach(items) { item in
                NavigationLink(destination: ItemDetailView(item: item, authService: authService)) {
                    WardrobeItemCard(item: item)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }
}
