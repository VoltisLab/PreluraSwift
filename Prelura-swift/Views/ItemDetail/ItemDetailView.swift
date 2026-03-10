import SwiftUI
import UIKit

struct ItemDetailView: View {
    let item: Item
    @StateObject private var viewModel: ItemDetailViewModel
    @State private var selectedImageIndex: Int = 0
    @State private var selectedTab: Int = 0
    @State private var showFullScreenImages: Bool = false
    @State private var showSendOfferSheet: Bool = false
    @State private var showPaymentSheet: Bool = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    init(item: Item, authService: AuthService? = nil) {
        self.item = item
        _viewModel = StateObject(wrappedValue: ItemDetailViewModel(authService: authService))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Image Carousel (extends under status bar; back button in toolbar position)
                    imageCarousel
                    
                    // Product Top Details
                    productTopDetails
                    
                    // Description Section
                    descriptionSection
                    
                    // Product Attributes
                    productAttributes
                    
                    // Tabs
                    tabsSection
                    
                    // Tab Content
                    tabContent
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)

            // Bottom Action Buttons
            if !isCurrentUser {
                bottomActionButtons
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            if authService.isAuthenticated {
                viewModel.updateAuthToken(authService.authToken)
            }
            viewModel.syncLikeState(isLiked: item.isLiked, likeCount: item.likeCount)
            if let productId = item.productId {
                viewModel.loadSimilarProducts(productId: productId, categoryId: nil)
            }
            viewModel.loadMemberItems(username: item.seller.username, excludeProductId: item.id)
        }
        .onChange(of: authService.authToken) { oldToken, newToken in
            if authService.isAuthenticated {
                viewModel.updateAuthToken(newToken)
            }
        }
        .fullScreenCover(isPresented: $showFullScreenImages) {
            FullScreenImageViewer(
                imageURLs: item.imageURLs,
                selectedIndex: $selectedImageIndex,
                onDismiss: { showFullScreenImages = false }
            )
        }
        .sheet(isPresented: $showSendOfferSheet) {
            SendOfferSheet(item: item) { showSendOfferSheet = false }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentView(products: [item], totalPrice: item.price)
                .environmentObject(authService)
                .presentationDetents([.large])
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    private var isCurrentUser: Bool {
        // TODO: Check if current user is the seller
        false
    }
    
    // MARK: - Image Carousel (aspect 585:826; height capped at 58% of screen)
    private static let statusBarHeight: CGFloat = 54
    private static let imageAspectWidth: CGFloat = 585
    private static let imageAspectHeight: CGFloat = 826
    /// Max fraction of screen height the image area can use (60–65%).
    private static let maxImageHeightFraction: CGFloat = 0.65
    
    private var imageCarousel: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let screenH = UIScreen.main.bounds.height
            let aspectH = w * (Self.imageAspectHeight / Self.imageAspectWidth) + Self.statusBarHeight
            let h = min(aspectH, screenH * Self.maxImageHeightFraction)
            
            ZStack(alignment: .top) {
                TabView(selection: $selectedImageIndex) {
                ForEach(0..<item.imageURLs.count, id: \.self) { index in
                    AsyncImage(url: URL(string: item.imageURLs[index])) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Theme.Colors.secondaryBackground)
                                .shimmer()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Theme.Colors.secondaryBackground)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(Theme.Colors.secondaryText)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: w, height: h)
            .ignoresSafeArea(edges: .top)
            .contentShape(Rectangle())
            .onTapGesture {
                showFullScreenImages = true
            }
            
            // Heart Icon Overlay (bottom right) - tappable
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        if let productId = item.productId {
                            viewModel.toggleLike(productId: productId)
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                            Text("\(viewModel.likeCount)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.like() }))
                    .padding(.trailing, 15)
                    .padding(.bottom, 15)
                }
            }
            
            // Page Indicator (centered at bottom)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(0..<item.imageURLs.count, id: \.self) { index in
                            Circle()
                                .fill(selectedImageIndex == index ? Theme.primaryColor : Color.black)
                                .frame(width: selectedImageIndex == index ? 7 : 5,
                                       height: selectedImageIndex == index ? 7 : 5)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 15)
            }
            }
            .frame(width: w, height: h)
        }
        .frame(height: min(
            (UIScreen.main.bounds.width * Self.imageAspectHeight / Self.imageAspectWidth) + Self.statusBarHeight,
            UIScreen.main.bounds.height * Self.maxImageHeightFraction
        ))
    }
    
    // MARK: - Product Top Details
    private var productTopDetails: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Title (smaller than before; Flutter uses bodyLarge-style)
            Text(item.title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.primaryText)
                .lineLimit(4)
            
            // Brand and Size Row (tappable → filter by brand / size; same behaviour as Flutter)
            HStack {
                if let brand = item.brand {
                    NavigationLink(destination: FilteredProductsView(title: brand, filterType: .byBrand(brandName: brand), authService: authService)) {
                        Text(brand)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.primaryColor)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                }
                Spacer()
                if let size = item.size {
                    NavigationLink(destination: FilteredProductsView(title: "Size \(size)", filterType: .bySize(sizeName: size), authService: authService)) {
                        Text("Size \(size)")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.primaryColor)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                }
            }
            
            // Condition and Price Row
            HStack {
                Text(item.formattedCondition)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
                
                // Price with discount handling
                if let originalPrice = item.originalPrice {
                    Text(item.formattedOriginalPrice)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .strikethrough()
                    Text(item.formattedPrice)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    if let discount = item.discountPercentage {
                        Text("\(discount)%")
                            .font(Theme.Typography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "8d100f"))
                    }
                } else {
                    Text(item.formattedPrice)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
            
            // Seller Info (avatar + username tappable → seller profile)
            HStack(spacing: Theme.Spacing.sm) {
                NavigationLink(destination: UserProfileView(seller: item.seller, authService: authService)) {
                    HStack(spacing: Theme.Spacing.sm) {
                        AsyncImage(url: URL(string: item.seller.avatarURL ?? "")) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(Theme.Colors.secondaryBackground)
                                    .frame(width: 50, height: 50)
                                    .shimmer()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            case .failure:
                                Circle()
                                    .fill(Theme.primaryColor.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text(String(item.seller.username.prefix(1)).uppercased())
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(Theme.primaryColor)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.seller.username)
                                .font(Theme.Typography.body)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.Colors.primaryText)
                            HStack(spacing: 4) {
                                ForEach(0..<5, id: \.self) { _ in
                                    Image(systemName: "star")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.secondaryText)
                                }
                                Text("(\(item.seller.reviewCount))")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                NavigationLink(destination: ChatWithSellerView(seller: item.seller, authService: authService)) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.primaryColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.Colors.background)
    }
    
    // MARK: - Description Section (content only, no title or bullet)
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            descriptionBody
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.lg)
                .overlay(ContentDivider(), alignment: .bottom)
        }
        .background(Theme.Colors.background)
    }
    
    private var descriptionBody: some View {
        let lines = item.description.isEmpty ? ["—"] : item.description.components(separatedBy: "\n").filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(lines, id: \.self) { line in
                textWithHashtags(line.trimmingCharacters(in: .whitespaces))
                    .font(Theme.Typography.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Renders a string with hashtags (#word) in primary colour.
    private func textWithHashtags(_ string: String) -> Text {
        let segments = Self.parseHashtagSegments(string)
        return segments.reduce(Text(verbatim: "")) { acc, seg in
            acc + Text(seg.text)
                .font(Theme.Typography.body)
                .foregroundColor(seg.isHashtag ? Theme.primaryColor : Theme.Colors.primaryText)
        }
    }

    private static func parseHashtagSegments(_ string: String) -> [(text: String, isHashtag: Bool)] {
        var result: [(String, Bool)] = []
        let pattern = "#[\\w]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [(string, false)]
        }
        let range = NSRange(string.startIndex..., in: string)
        var lastEnd = string.startIndex
        regex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
            guard let match = match, let range = Range(match.range, in: string) else { return }
            if lastEnd < range.lowerBound {
                result.append((String(string[lastEnd..<range.lowerBound]), false))
            }
            result.append((String(string[range]), true))
            lastEnd = range.upperBound
        }
        if lastEnd < string.endIndex {
            result.append((String(string[lastEnd...]), false))
        }
        return result.isEmpty ? [(string, false)] : result
    }
    
    // MARK: - Product Attributes
    private var productAttributes: some View {
        VStack(spacing: 0) {
            attributeRow(label: "Category", value: item.categoryName ?? item.category.name)
            if let brandName = item.brand {
                NavigationLink(destination: FilteredProductsView(title: brandName, filterType: .byBrand(brandName: brandName), authService: authService)) {
                    attributeRow(label: "Material", value: brandName, valueColor: Theme.primaryColor)
                }
                .buttonStyle(.plain)
            }
            if let size = item.size {
                NavigationLink(destination: FilteredProductsView(title: "Size \(size)", filterType: .bySize(sizeName: size), authService: authService)) {
                    attributeRow(label: "Size", value: size, valueColor: Theme.primaryColor)
                }
                .buttonStyle(.plain)
            }
            attributeRow(label: "Condition", value: item.formattedCondition)
            attributeRow(label: "Views", value: "\(item.views)")
            attributeRow(label: "Uploaded", value: formatDate(item.createdAt))
            attributeRow(label: "Postage", value: "Postage: From £1.99", valueColor: Theme.primaryColor)
        }
        .background(Theme.Colors.background)
    }
    
    private func attributeRow(label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            Text(value)
                .font(Theme.Typography.body)
                .foregroundColor(valueColor ?? Theme.Colors.primaryText)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.lg)
        .overlay(ContentDivider(), alignment: .bottom)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Tabs Section
    private var tabsSection: some View {
        HStack(spacing: 0) {
            TabButton(title: L10n.string("Member's items"), isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            TabButton(title: L10n.string("Similar items"), isSelected: selectedTab == 1) {
                selectedTab = 1
            }
        }
        .background(Theme.Colors.background)
    }
    
    // MARK: - Tab Content
    private var tabContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if selectedTab == 0 {
                // Member's Items Tab
                membersItemsTab
            } else {
                // Similar Items Tab
                similarItemsTab
            }
        }
        .frame(minHeight: 300)
        .background(Theme.Colors.background)
    }
    
    private var membersItemsTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Shop Bundles Section
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(L10n.string("Shop bundles"))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text(L10n.string("Save on postage"))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer()
                PrimaryGlassButton("Create Bundle", action: {
                    // Create bundle
                })
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            
            // Product Grid
            if viewModel.isLoadingMember {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.memberItems.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "bag")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(L10n.string("No member items available yet"))
                        .font(Theme.Typography.body)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Theme.Spacing.sm),
                        GridItem(.flexible(), spacing: Theme.Spacing.sm)
                    ],
                    spacing: Theme.Spacing.md
                ) {
                    ForEach(viewModel.memberItems) { memberItem in
                        NavigationLink(destination: ItemDetailView(item: memberItem, authService: authService)) {
                            HomeItemCard(item: memberItem)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }
        }
    }
    
    private var similarItemsTab: some View {
        Group {
            if viewModel.isLoadingSimilar {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.similarItems.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "bag")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(L10n.string("No similar items available yet"))
                        .font(Theme.Typography.body)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Theme.Spacing.sm),
                        GridItem(.flexible(), spacing: Theme.Spacing.sm)
                    ],
                    spacing: Theme.Spacing.md
                ) {
                    ForEach(viewModel.similarItems) { similarItem in
                        NavigationLink(destination: ItemDetailView(item: similarItem, authService: authService)) {
                            HomeItemCard(item: similarItem)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }
        }
    }
    
    // MARK: - Bottom Action Buttons
    private var bottomActionButtons: some View {
        PrimaryButtonBar {
            HStack(spacing: Theme.Spacing.sm) {
                BorderGlassButton("Send an Offer", action: {
                    showSendOfferSheet = true
                })
                PrimaryGlassButton("Buy now", action: {
                    showPaymentSheet = true
                })
            }
        }
    }
}

// MARK: - Full Screen Image Viewer (slider)
struct FullScreenImageViewer: View {
    let imageURLs: [String]
    @Binding var selectedIndex: Int
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(0..<imageURLs.count, id: \.self) { index in
                    AsyncImage(url: URL(string: imageURLs[index])) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Theme.Colors.secondaryBackground)
                                .shimmer()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.9))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(HapticTapButtonStyle())
                    .padding(.trailing, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.lg)
                }
                Spacer()
                // Page indicator
                HStack(spacing: 6) {
                    ForEach(0..<imageURLs.count, id: \.self) { index in
                        Circle()
                            .fill(selectedIndex == index ? Theme.primaryColor : Color.white.opacity(0.4))
                            .frame(width: selectedIndex == index ? 8 : 6, height: selectedIndex == index ? 8 : 6)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(isSelected ? Theme.Colors.primaryText : Theme.Colors.secondaryText)
                    .fontWeight(isSelected ? .bold : .regular)
                    .padding(.vertical, Theme.Spacing.md)
                
                Rectangle()
                    .fill(isSelected ? Theme.primaryColor : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView {
        ItemDetailView(item: Item.sampleItems[0])
            .environmentObject(AuthService())
    }
    .preferredColorScheme(.dark)
}
