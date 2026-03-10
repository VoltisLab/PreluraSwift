import SwiftUI

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
    @State private var showPriceFilterSheet: Bool = false
    init(seller: User, authService: AuthService?) {
        self.seller = seller
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(seller: seller, authService: authService))
    }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = geometry.size.width
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Theme.primaryColor)
                            .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(viewModel.user.username)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                    NavigationLink(destination: ReportUserView(username: viewModel.user.username)) {
                        Image(systemName: "flag")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.primaryColor)
                            .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.AppBar.horizontalPadding)
                .padding(.vertical, Theme.AppBar.verticalPadding)
                .background(Theme.Colors.background)

                ScrollView {
                    if viewModel.isLoading && viewModel.items.isEmpty && viewModel.errorMessage == nil {
                        ProfileShimmerView()
                    } else {
                        VStack(spacing: 0) {
                            profileHeaderSection
                            profileLocationSection
                            if let bio = viewModel.user.bio, !bio.isEmpty {
                                bioSection(bio)
                            }
                            if viewModel.user.isVacationMode {
                                vacationModeSection(isLoggedInUser: false)
                            } else {
                                filtersSection
                                itemsGridSection
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xxl)
                        .frame(maxWidth: contentWidth)
                    }
                    if let message = viewModel.errorMessage, !viewModel.items.isEmpty {
                        Text(message)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .padding()
                    }
                }
                .frame(width: contentWidth)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await viewModel.refreshAsync() }
        .onAppear {
            viewModel.load()
        }
    }

    private var profileHeaderSection: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                AsyncImage(url: URL(string: viewModel.user.avatarURL ?? "")) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Theme.Colors.secondaryBackground)
                            .frame(width: 75, height: 75)
                            .shimmer()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 75, height: 75)
                            .clipShape(Circle())
                    case .failure:
                        Circle()
                            .fill(Theme.primaryColor)
                            .frame(width: 75, height: 75)
                            .overlay(
                                Text(String(viewModel.user.username.prefix(1)).uppercased())
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 75, height: 75)

                NavigationLink(value: AppRoute.reviews(username: viewModel.user.username, rating: viewModel.user.rating)) {
                    HStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text("(\(viewModel.user.reviewCount))")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                }
                .buttonStyle(HapticTapButtonStyle())
            }

            HStack(spacing: 0) {
                StatColumn(value: "\(viewModel.items.count)", label: viewModel.items.count == 1 ? L10n.string("Listing") : L10n.string("Listings"))
                Spacer(minLength: Theme.Spacing.sm)
                NavigationLink(destination: FollowingListView(username: viewModel.user.username)) {
                    StatColumn(value: "\(viewModel.user.followingsCount)", label: L10n.string("Following"))
                }
                .buttonStyle(.plain)
                Spacer(minLength: Theme.Spacing.sm)
                NavigationLink(destination: FollowersListView(username: viewModel.user.username)) {
                    StatColumn(value: "\(viewModel.user.followersCount)", label: viewModel.user.followersCount == 1 ? L10n.string("Follower") : L10n.string("Followers"))
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, Theme.Spacing.xs)
        }
        .padding(.vertical, Theme.Spacing.md)
        .overlay(ContentDivider(), alignment: .bottom)
    }

    private var profileLocationSection: some View {
        Group {
            if let location = viewModel.user.location, !location.isEmpty {
                Text(location)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Theme.Spacing.md)
            }
        }
    }

    private func bioSection(_ bio: String) -> some View {
        Text(bio)
            .font(Theme.Typography.body)
            .lineSpacing(5)
            .foregroundColor(Theme.Colors.primaryText)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Spacing.md)
    }

    /// When the profile user has vacation mode on, show message and hide products (matches Flutter).
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
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        Spacer()
                        Image(systemName: expandedCategories ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
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
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.primaryText)
                                    Text("(\(category.count) \(category.count == 1 ? L10n.string("item") : L10n.string("items"))")
                                        .font(Theme.Typography.subheadline)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                    Spacer(minLength: Theme.Spacing.md)
                                    Image(systemName: selectedCategory == category.name ? "checkmark.square" : "square")
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedCategory == category.name ? Theme.primaryColor : Theme.Colors.secondaryText)
                                }
                                .padding(.vertical, Theme.Spacing.md)
                            }
                            .buttonStyle(PlainButtonStyle())
                            if category.name != viewModel.categoriesWithCounts.last?.name {
                                ContentDivider()
                            }
                        }
                    }
                }
            }
            .overlay(ContentDivider(), alignment: .bottom)

            HStack {
                Text(L10n.string("Multi-buy:"))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                Text(viewModel.user.isMultibuyEnabled ? L10n.string("On") : L10n.string("Off"))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            .padding(.vertical, Theme.Spacing.md)
            .overlay(ContentDivider(), alignment: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(L10n.string("Top brands"))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
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
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.md)
            }

            HStack {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 17))
                        Text(L10n.string("Filter"))
                            .font(Theme.Typography.body)
                    }
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
                .fixedSize(horizontal: true, vertical: false)
                Spacer()
                Button(action: { showSortSheet = true }) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(L10n.string(profileSort.rawValue))
                            .font(Theme.Typography.body)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .sheet(isPresented: $showSortSheet) { userProfileSortSheet }
        .sheet(isPresented: $showFilterSheet) { userProfileFilterSheet }
        .sheet(isPresented: $showPriceFilterSheet) { userProfilePriceFilterSheet }
    }

    private var userProfileSortSheet: some View {
        NavigationStack {
            List {
                ForEach(ProfileSortOption.allCases, id: \.self) { option in
                    Button(action: { profileSort = option; showSortSheet = false }) {
                        HStack {
                            Text(L10n.string(option.rawValue)).foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if profileSort == option { Image(systemName: "checkmark").foregroundColor(Theme.primaryColor) }
                        }
                    }
                }
                Section {
                    Button(role: .destructive, action: { profileSort = .relevance; showSortSheet = false }) { Text(L10n.string("Clear")).frame(maxWidth: .infinity) }
                }
            }
            .navigationTitle(L10n.string("Sort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.string("Done")) { showSortSheet = false } } }
        }
    }

    private var userProfileFilterSheet: some View {
        NavigationStack {
            List {
                Section(header: Text(L10n.string("Condition"))) {
                    ForEach(profileConditionOptions, id: \.raw) { option in
                        Button(action: { filterCondition = filterCondition == option.raw ? nil : option.raw }) {
                            HStack {
                                Text(L10n.string(option.display)).foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if filterCondition == option.raw { Image(systemName: "checkmark").foregroundColor(Theme.primaryColor) }
                            }
                        }
                    }
                }
                Section(header: Text(L10n.string("Price range"))) {
                    Button(action: { showFilterSheet = false; showPriceFilterSheet = true }) {
                        HStack {
                            Text(L10n.string("Price")).foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if !filterMinPrice.isEmpty || !filterMaxPrice.isEmpty {
                                Text([filterMinPrice, filterMaxPrice].filter { !$0.isEmpty }.joined(separator: " – "))
                                    .font(Theme.Typography.caption).foregroundColor(Theme.Colors.secondaryText)
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(Theme.Colors.secondaryText)
                        }
                    }
                }
                Section {
                    Button(role: .destructive, action: { filterCondition = nil; filterMinPrice = ""; filterMaxPrice = ""; showFilterSheet = false }) { Text(L10n.string("Clear")).frame(maxWidth: .infinity) }
                }
            }
            .navigationTitle(L10n.string("Filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.string("Done")) { showFilterSheet = false } } }
        }
    }

    private var userProfilePriceFilterSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.string("Min. Price"), text: $filterMinPrice).keyboardType(.decimalPad)
                    TextField(L10n.string("Max. Price"), text: $filterMaxPrice).keyboardType(.decimalPad)
                }
                Section {
                    Button(L10n.string("Clear")) { filterMinPrice = ""; filterMaxPrice = ""; showPriceFilterSheet = false }
                    Button(L10n.string("Apply")) { showPriceFilterSheet = false }.fontWeight(.semibold)
                }
            }
            .navigationTitle(L10n.string("Price"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.string("Done")) { showPriceFilterSheet = false } } }
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
        .padding(.vertical, Theme.Spacing.md)
    }
}
