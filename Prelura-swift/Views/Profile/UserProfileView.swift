import SwiftUI

/// Other user's profile – same layout as ProfileView (read-only: no menu, no photo edit). Filter/Sort match Flutter.
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
        VStack(spacing: 0) {
            // Custom header (same position as all app bar icons/back buttons)
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
                Color.clear.frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
            }
            .padding(.horizontal, Theme.AppBar.horizontalPadding)
            .padding(.vertical, Theme.AppBar.verticalPadding)
            .background(Theme.Colors.background)

            ScrollView {
                if viewModel.isLoading && viewModel.items.isEmpty && viewModel.errorMessage == nil {
                    ProfileShimmerView()
                } else {
                    VStack(spacing: 0) {
                        profileSection
                        if let bio = viewModel.user.bio {
                            bioSection(bio)
                        }
                        userStatsSection
                        filtersSection
                        itemsGridSection
                    }
                }
                if let message = viewModel.errorMessage, !viewModel.items.isEmpty {
                    Text(message)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding()
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .refreshable { await viewModel.refreshAsync() }
        .onAppear {
            viewModel.load()
        }
    }

    // MARK: - Profile Section (same as ProfileView: 70px avatar, username, stars, location)
    private var profileSection: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            AsyncImage(url: URL(string: viewModel.user.avatarURL ?? "")) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(Theme.primaryColor)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                case .failure:
                    Circle()
                        .fill(Theme.primaryColor)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Text(String(viewModel.user.username.prefix(1)).uppercased())
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(viewModel.user.username)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                HStack(spacing: Theme.Spacing.xs) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.yellow)
                        }
                    }
                    Text("(\(viewModel.user.reviewCount))")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                }
                if let location = viewModel.user.location {
                    Text(location)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }

            Spacer()

            HStack(spacing: Theme.Spacing.sm) {
                Button(action: {}) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.primaryText)
                }
                Button(action: {}) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Theme.Colors.glassBorder),
            alignment: .bottom
        )
    }

    private func bioSection(_ bio: String) -> some View {
        Text(bio)
            .font(Theme.Typography.subheadline)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - User Stats (same as ProfileView: Listings, Followings, Followers, Reviews, Location)
    private var userStatsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
                StatColumn(value: "\(viewModel.items.count)", label: "Listings")
                StatColumn(value: "\(viewModel.user.followingsCount)", label: "Followings")
                StatColumn(value: "\(viewModel.user.followersCount)", label: "Followers")
                StatColumn(value: "\(viewModel.user.reviewCount)", label: "Reviews")
                StatColumn(value: viewModel.user.locationAbbreviation ?? "N/A", label: "Location")
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.md)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Theme.Colors.glassBorder),
            alignment: .bottom
        )
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
                        Text("Categories")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        Spacer()
                        Image(systemName: expandedCategories ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
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
                                    Text("(\(category.count) \(category.count == 1 ? "item" : "items"))")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                    Spacer(minLength: Theme.Spacing.md)
                                    Image(systemName: selectedCategory == category.name ? "checkmark.square" : "square")
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedCategory == category.name ? Theme.primaryColor : Theme.Colors.secondaryText)
                                }
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.md)
                            }
                            .buttonStyle(PlainButtonStyle())
                            if category.name != viewModel.categoriesWithCounts.last?.name {
                                Divider()
                                    .background(Theme.Colors.glassBorder)
                                    .padding(.leading, Theme.Spacing.lg)
                            }
                        }
                    }
                }
            }
            .overlay(
                Rectangle().frame(height: 0.5).foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )

            HStack {
                Text("Multi-buy:")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
                Text(viewModel.user.isMultibuyEnabled ? "On" : "Off")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .overlay(
                Rectangle().frame(height: 0.5).foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Top brands")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
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
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .padding(.vertical, Theme.Spacing.sm)
            }

            HStack {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14))
                        Text("Filter")
                            .font(Theme.Typography.subheadline)
                    }
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
                Spacer()
                Button(action: { showSortSheet = true }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(profileSort.rawValue)
                            .font(Theme.Typography.subheadline)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
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
                            Text(option.rawValue).foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if profileSort == option { Image(systemName: "checkmark").foregroundColor(Theme.primaryColor) }
                        }
                    }
                }
                Section {
                    Button(role: .destructive, action: { profileSort = .relevance; showSortSheet = false }) { Text("Clear").frame(maxWidth: .infinity) }
                }
            }
            .navigationTitle("Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSortSheet = false } } }
        }
    }

    private var userProfileFilterSheet: some View {
        NavigationStack {
            List {
                Section(header: Text("Condition")) {
                    ForEach(profileConditionOptions, id: \.raw) { option in
                        Button(action: { filterCondition = filterCondition == option.raw ? nil : option.raw }) {
                            HStack {
                                Text(option.display).foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if filterCondition == option.raw { Image(systemName: "checkmark").foregroundColor(Theme.primaryColor) }
                            }
                        }
                    }
                }
                Section(header: Text("Price range")) {
                    Button(action: { showFilterSheet = false; showPriceFilterSheet = true }) {
                        HStack {
                            Text("Price").foregroundColor(Theme.Colors.primaryText)
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
                    Button(role: .destructive, action: { filterCondition = nil; filterMinPrice = ""; filterMaxPrice = ""; showFilterSheet = false }) { Text("Clear").frame(maxWidth: .infinity) }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showFilterSheet = false } } }
        }
    }

    private var userProfilePriceFilterSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Min. Price", text: $filterMinPrice).keyboardType(.decimalPad)
                    TextField("Max. Price", text: $filterMaxPrice).keyboardType(.decimalPad)
                }
                Section {
                    Button("Clear") { filterMinPrice = ""; filterMaxPrice = ""; showPriceFilterSheet = false }
                    Button("Apply") { showPriceFilterSheet = false }.fontWeight(.semibold)
                }
            }
            .navigationTitle("Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showPriceFilterSheet = false } } }
        }
    }

    // MARK: - Items Grid (category + brand + filter + sort, matching Flutter)
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
