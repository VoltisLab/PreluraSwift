import SwiftUI
import PhotosUI
import Shimmer

struct SellView: View {
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @StateObject private var viewModel = SellViewModel()
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: SellCategory? = nil
    @State private var brand: String? = nil
    @State private var condition: String? = nil
    @State private var colours: [String] = []
    @State private var sizeId: Int? = nil
    @State private var sizeName: String? = nil
    @State private var measurements: String? = nil
    @State private var material: String? = nil
    @State private var styles: [String] = []
    @State private var price: Double? = nil
    @State private var discountPrice: Double? = nil
    @State private var parcelSize: String? = nil
    @State private var draftCount: Int = 5 // TODO: Fetch from backend
    @State private var showPhotoPicker: Bool = false
    @State private var showCategoryPicker: Bool = false

    private var discountPercentText: String {
        guard let price = price, let discountPrice = discountPrice, price > 0 else { return "0%" }
        let percent = Int(((price - discountPrice) / price) * 100)
        return "\(percent)%"
    }

    /// Flutter: category, description, images, parcel, title, price (not 0), selectedColors, brand or customBrand, condition
    private var canUpload: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedImages.isEmpty
            && category != nil
            && (brand != nil && !(brand?.isEmpty ?? true))
            && condition != nil
            && !colours.isEmpty
            && price != nil && (price ?? 0) > 0
            && parcelSize != nil
    }


    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Upload from drafts (Flutter: same)
                    if draftCount > 0 {
                        draftsSection
                    }
                    // 2. Photo upload (Flutter: same)
                    photoUploadSection
                    // 3. Item Details = Title + Describe your item only (Flutter)
                    itemDetailsSection
                    // 4. Item Information = Category, Brand, Condition, Colours (Flutter)
                    itemInformationSection
                    // 5. Additional Details (Flutter)
                    additionalDetailsSection
                    // 6. Pricing & Shipping (Flutter)
                    pricingShippingSection
                }
                .padding(.bottom, 100)
            }
            .background(Theme.Colors.background)

            PrimaryButtonBar {
                PrimaryGlassButton(
                    L10n.string("Upload"),
                    isEnabled: canUpload,
                    isLoading: viewModel.isSubmitting,
                    action: {
                        viewModel.submitListing(
                            authToken: authService.authToken,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            price: price ?? 0.0,
                            brand: brand ?? "",
                            condition: condition ?? "",
                            size: measurements ?? "",
                            categoryId: category?.id,
                            categoryName: category?.name,
                            images: selectedImages,
                            discountPrice: discountPrice,
                            parcelSize: parcelSize,
                            colours: colours,
                            sizeId: sizeId,
                            measurements: measurements,
                            material: material,
                            styles: styles
                        )
                    }
                )
            }
        }
        .navigationTitle(L10n.string("Sell an item"))
        .onChange(of: viewModel.submissionSuccess) { _, success in
            if success {
                HapticManager.success()
                selectedTab = 4 // Profile tab
                NotificationCenter.default.post(name: .preluraUserProfileDidUpdate, object: nil)
            }
        }
        .alert(L10n.string("Upload failed"), isPresented: Binding(
            get: { viewModel.submissionError != nil },
            set: { if !$0 { viewModel.submissionError = nil } }
        )) {
            Button(L10n.string("OK")) { viewModel.submissionError = nil }
        } message: {
            if let err = viewModel.submissionError { Text(err) }
        }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticManager.tap()
                        selectedTab = 0
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
    }
    
    // MARK: - Drafts Section
    private var draftsSection: some View {
        Button(action: {
            // TODO: Navigate to drafts
        }) {
            HStack {
                Text(L10n.string("Upload from drafts"))
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.primaryColor)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Theme.primaryColor)
                        .frame(width: 24, height: 24)
                    
                    Text("\(draftCount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(HapticTapButtonStyle())
        .overlay(ContentDivider(), alignment: .bottom)
    }
    
    // MARK: - Photo Upload Section (horizontal slider of thumbnails)
    private var photoUploadSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if selectedImages.isEmpty {
                emptyPhotoState
            } else {
                photoSlider
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .overlay(ContentDivider(), alignment: .bottom)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 20,
            matching: .images
        )
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                var loaded: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        loaded.append(image)
                    }
                }
                await MainActor.run { selectedImages = loaded }
            }
        }
    }

    /// Horizontal slider: thumbnails + Add photo cell; container height matches cell height so nothing is clipped.
    private var photoSlider: some View {
        GeometryReader { geo in
            let cellWidth = min(118, (geo.size.width - Theme.Spacing.md) / 2.6)
            let cellHeight = cellWidth / SellPhotoSliderCell.aspectRatio
            let spacing = Theme.Spacing.sm
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        SellPhotoSliderCell(
                            image: image,
                            cellWidth: cellWidth,
                            onRemove: {
                                selectedImages.remove(at: index)
                                selectedPhotos.remove(at: index)
                            }
                        )
                    }
                    if selectedImages.count < 20 {
                        SellAddPhotoSliderCell(cellWidth: cellWidth, action: { showPhotoPicker = true })
                    }
                }
                .padding(.horizontal, Theme.Spacing.xs)
            }
            .frame(height: cellHeight)
        }
        .frame(height: 155)
    }

    private var emptyPhotoState: some View {
        Button(action: { showPhotoPicker = true }) {
            VStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Theme.primaryColor.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.primaryColor)
                }
                Text(L10n.string("Add up to 20 photos"))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                Text(L10n.string("Tap to select photos from your gallery"))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.secondaryBackground)
            )
        }
        .buttonStyle(HapticTapButtonStyle())
    }
}

// MARK: - Sell photo slider cell (fixed width, aspect 1:1.3, remove button)
private struct SellPhotoSliderCell: View {
    static let aspectRatio: CGFloat = 1.0 / 1.3
    let image: UIImage
    let cellWidth: CGFloat
    let onRemove: () -> Void

    var body: some View {
        let cellHeight = cellWidth / Self.aspectRatio
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.Colors.secondaryBackground)
                .frame(width: cellWidth, height: cellHeight)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: cellWidth, height: cellHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .frame(width: cellWidth, height: cellHeight)
    }
}

// MARK: - Sell add-photo slider cell (same width & aspect as thumbnails)
private struct SellAddPhotoSliderCell: View {
    let cellWidth: CGFloat
    let action: () -> Void

    var body: some View {
        let cellHeight = cellWidth / SellPhotoSliderCell.aspectRatio
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Theme.Colors.glassBorder, lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.primaryColor)
                        Text(L10n.string("Add photo"))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                )
        }
        .buttonStyle(HapticTapButtonStyle())
        .frame(width: cellWidth, height: cellHeight)
    }
}

extension SellView {
    // MARK: - Item Details Section (Flutter: header + Title + Describe your item only)
    private var itemDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.string("Item Details"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryText)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SellLabeledField(
                    label: "Title",
                    placeholder: "e.g. White COS Jumper",
                    text: $title
                )
                SellLabeledField(
                    label: "Describe your item",
                    placeholder: "e.g. only worn a few times, true to size",
                    text: $description,
                    minLines: 6,
                    maxLines: nil
                )
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .overlay(ContentDivider(), alignment: .bottom)
        }
        .padding(.top, Theme.Spacing.md)
        .background(Theme.Colors.background)
    }

    // MARK: - Item Information Section (Flutter: Category, Brand, Condition, Colours)
    private var itemInformationSection: some View {
        VStack(spacing: 0) {
            Text(L10n.string("Item Information"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)
                .background(Theme.Colors.background)

            Button(action: { showCategoryPicker = true }) {
                SellFormRow(title: L10n.string("Category"), value: category?.name)
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)
            .sheet(isPresented: $showCategoryPicker) {
                NavigationStack {
                    CategorySelectionView(selectedCategory: $category, onDismiss: { showCategoryPicker = false })
                }
            }

            NavigationLink(destination: BrandInputView(selectedBrand: $brand)) {
                SellFormRow(title: L10n.string("Brand"), value: brand)
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)

            NavigationLink(destination: ConditionSelectionView(selectedCondition: $condition)) {
                SellFormRow(title: L10n.string("Condition"), value: ConditionSelectionView.displayName(for: condition))
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)

            NavigationLink(destination: ColoursSelectionView(selectedColours: $colours)) {
                SellFormRow(
                    title: L10n.string("Colours"),
                    value: colours.isEmpty ? nil : colours.joined(separator: ", ")
                )
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)

            NavigationLink(destination: SizeSelectionView(
                selectedSizeId: $sizeId,
                selectedSizeName: $sizeName,
                categoryPath: category?.sizeApiPath ?? ""
            )) {
                SellFormRow(title: L10n.string("Size"), value: sizeName)
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)
        }
        .background(Theme.Colors.background)
    }
    
    // MARK: - Additional Details Section (Flutter: Measurements, Material, Style)
    private var additionalDetailsSection: some View {
        VStack(spacing: 0) {
            Text(L10n.string("Additional Details"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)
                .background(Theme.Colors.background)
            
            // Measurements Field
            NavigationLink(destination: MeasurementsView(measurements: $measurements)) {
                SellFormRow(title: L10n.string("Measurements (Optional)"), value: measurements)
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)

            // Material Field
            NavigationLink(destination: MaterialSelectionView(selectedMaterial: $material)) {
                SellFormRow(title: L10n.string("Material (Optional)"), value: material)
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)

            // Style Field
            NavigationLink(destination: StyleSelectionView(selectedStyles: $styles)) {
                SellFormRow(
                    title: L10n.string("Style (Optional)"),
                    value: styles.isEmpty ? nil : styles.map { StyleSelectionView.displayName(for: $0) }.joined(separator: ", ")
                )
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)
        }
    }
    
    // MARK: - Pricing & Shipping Section (Flutter: Price, Discount, Parcel, info banner)
    private var pricingShippingSection: some View {
        VStack(spacing: 0) {
            Text(L10n.string("Pricing & Shipping"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)
                .background(Theme.Colors.background)
            
            // Price Field
            NavigationLink(destination: PriceInputView(price: $price, categoryId: category?.id)) {
                SellFormRow(
                    title: L10n.string("Price"),
                    value: price.map { "£\(String(format: "%.0f", $0))" }
                )
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)

            // Discount Price Field
            NavigationLink(destination: DiscountPriceInputView(price: $price, discountPrice: $discountPrice)) {
                SellFormRow(
                    title: L10n.string("Discount Price (Optional)"),
                    value: discountPercentText
                )
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)

            // Parcel Size Field
            NavigationLink(destination: ParcelSizeSelectionView(selectedParcelSize: $parcelSize)) {
                SellFormRow(title: L10n.string("Parcel Size"), value: parcelSize)
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)

            // Info Banner (Flutter: primary 0.1 bg, primary icon & text)
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.primaryColor)

                Text(L10n.string("The buyer always pays for postage."))
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.primaryColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.primaryColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
    }
    
}

// MARK: - Category Selection View (hierarchical + search all categories/subs)
struct CategorySelectionView: View {
    @Binding var selectedCategory: SellCategory?
    var onDismiss: () -> Void
    @State private var categories: [APICategory] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var searchText = ""
    @State private var allCategories: [CategoryPathEntry] = []
    @State private var isLoadingSearch = false
    private let service = CategoriesService()

    private static let rootOrder = ["Men", "Women", "Boys", "Girls", "Toddlers"]

    private var filteredSearchResults: [CategoryPathEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return [] }
        return allCategories.filter {
            $0.displayPath.lowercased().contains(q) || $0.name.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            DiscoverSearchField(
                text: $searchText,
                placeholder: L10n.string("Search categories"),
                outerPadding: true,
                topPadding: Theme.Spacing.sm
            )
            .padding(.trailing, Theme.Spacing.sm)

            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchResultsContent
            } else {
                browseContent
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Select Category"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.string("Cancel")) { onDismiss() }
                    .foregroundColor(Theme.primaryColor)
            }
        }
        .task {
            await loadCategories(parentId: nil)
        }
        .task {
            await loadAllCategories()
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        let results = filteredSearchResults
        if isLoadingSearch && allCategories.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
                .tint(Theme.primaryColor)
        } else if results.isEmpty {
            Text(L10n.string("No categories found"))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(results, id: \.displayPath) { entry in
                        Button(action: {
                            selectedCategory = SellCategory(
                                id: entry.id,
                                name: entry.name,
                                pathNames: entry.pathNames,
                                pathIds: entry.pathIds
                            )
                            onDismiss()
                        }) {
                            Text(entry.displayPath)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md)
                        }
                        .buttonStyle(.plain)
                        if entry.displayPath != results.last?.displayPath {
                            ContentDivider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var browseContent: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tint(Theme.primaryColor)
            } else if let error = loadError {
                VStack(spacing: Theme.Spacing.md) {
                    Text(error)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedCategories, id: \.id) { cat in
                        let isInSelectedPath = selectedCategory.map { $0.pathNames.first == cat.name } ?? false
                        if cat.hasChildren == true {
                            NavigationLink(destination: SubCategoryView(
                                parentId: cat.id,
                                parentName: cat.name,
                                pathNames: [cat.name],
                                pathIds: [cat.id],
                                selectedCategory: $selectedCategory,
                                onDismiss: onDismiss
                            )) {
                                categoryRow(cat.name, isSelected: isInSelectedPath)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                selectedCategory = SellCategory(id: cat.id, name: cat.name, pathNames: [cat.name], pathIds: [cat.id], fullPath: cat.fullPath)
                                onDismiss()
                            }) {
                                categoryRow(cat.name, isSelected: selectedCategory?.id == cat.id)
                            }
                        }
                    }
                    .listRowBackground(Theme.Colors.background)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var sortedCategories: [APICategory] {
        guard categories.count > 1 else { return categories }
        return categories.sorted { a, b in
            let i1 = Self.rootOrder.firstIndex(of: a.name) ?? Self.rootOrder.count
            let i2 = Self.rootOrder.firstIndex(of: b.name) ?? Self.rootOrder.count
            return i1 < i2
        }
    }

    private func categoryRow(_ name: String, isSelected: Bool) -> some View {
        HStack {
            Text(name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(Theme.primaryColor)
            }
        }
    }

    private func loadCategories(parentId: Int?) async {
        isLoading = true
        loadError = nil
        do {
            categories = try await service.fetchCategories(parentId: parentId)
        } catch {
            loadError = L10n.userFacingError(error)
        }
        isLoading = false
    }

    private func loadAllCategories() async {
        isLoadingSearch = true
        do {
            allCategories = try await service.fetchAllCategoriesFlattened()
        } catch {
            allCategories = []
        }
        isLoadingSearch = false
    }
}

// MARK: - Sub Category View (children of a category; recursive)
struct SubCategoryView: View {
    let parentId: String
    let parentName: String
    let pathNames: [String]
    let pathIds: [String]
    @Binding var selectedCategory: SellCategory?
    var onDismiss: () -> Void
    @State private var categories: [APICategory] = []
    @State private var isLoading = true
    @State private var loadError: String?
    private let service = CategoriesService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tint(Theme.primaryColor)
            } else if let error = loadError {
                VStack(spacing: Theme.Spacing.md) {
                    Text(error)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(categories, id: \.id) { cat in
                        if cat.hasChildren == true {
                            NavigationLink(destination: SubCategoryView(
                                parentId: cat.id,
                                parentName: cat.name,
                                pathNames: pathNames + [cat.name],
                                pathIds: pathIds + [cat.id],
                                selectedCategory: $selectedCategory,
                                onDismiss: onDismiss
                            )) {
                                subCategoryRow(cat)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                selectedCategory = SellCategory(
                                    id: cat.id,
                                    name: cat.name,
                                    pathNames: pathNames + [cat.name],
                                    pathIds: pathIds + [cat.id],
                                    fullPath: cat.fullPath
                                )
                                onDismiss()
                            }) {
                                subCategoryRow(cat)
                            }
                        }
                    }
                    .listRowBackground(Theme.Colors.background)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Select Category"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            let id = Int(parentId)
            await loadCategories(parentId: id)
        }
    }

    private func subCategoryRow(_ cat: APICategory) -> some View {
        let isInSelectedPath = selectedCategory.map { $0.pathIds.contains(cat.id) || $0.id == cat.id } ?? false
        return HStack {
            Text(cat.name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            if isInSelectedPath {
                Image(systemName: "checkmark")
                    .foregroundColor(Theme.primaryColor)
            }
        }
    }

    private func loadCategories(parentId: Int?) async {
        isLoading = true
        loadError = nil
        do {
            categories = try await service.fetchCategories(parentId: parentId)
        } catch {
            loadError = L10n.userFacingError(error)
        }
        isLoading = false
    }
}

// MARK: - Condition Selection View (display names, subtitles, icons)
struct ConditionSelectionView: View {
    @Binding var selectedCondition: String?
    @Environment(\.presentationMode) var presentationMode

    private static let conditions: [(key: String, title: String, subtitle: String, icon: String)] = [
        ("BRAND_NEW_WITH_TAGS", "Brand New With Tags", "Never worn, with original tags", "tag"),
        ("BRAND_NEW_WITHOUT_TAGS", "Brand new Without Tags", "Never worn, tags removed", "sparkles"),
        ("EXCELLENT_CONDITION", "Excellent Condition", "Like new, minimal wear", "star"),
        ("GOOD_CONDITION", "Good Condition", "Light wear, fully functional", "checkmark.circle"),
        ("HEAVILY_USED", "Heavily Used", "Visible wear, still usable", "clock")
    ]

    /// Human-readable label for the condition key (for display in form after selection).
    static func displayName(for key: String?) -> String? {
        guard let key = key else { return nil }
        return conditions.first(where: { $0.key == key })?.title ?? key
    }

    var body: some View {
        List {
            ForEach(Self.conditions, id: \.key) { item in
                Button(action: {
                    selectedCondition = item.key
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(alignment: .center, spacing: Theme.Spacing.md) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(Theme.Colors.secondaryText)
                            .frame(width: 32, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(Theme.Typography.body)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.primaryText)
                            Text(item.subtitle)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }

                        Spacer()

                        if selectedCondition == item.key {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
            .listRowBackground(Theme.Colors.background)
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Select Condition"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Colours Selection View (ring around colour when selected; tap to toggle; max 3)
struct ColoursSelectionView: View {
    private static let maxSelections = 3
    @Binding var selectedColours: [String]
    @Environment(\.presentationMode) var presentationMode
    @State private var availableColours = ["Black", "White", "Red", "Blue", "Green", "Yellow", "Pink", "Purple", "Orange", "Brown", "Grey", "Beige", "Navy", "Maroon", "Teal"]

    var body: some View {
        List {
            ForEach(availableColours, id: \.self) { colour in
                Button(action: {
                    if selectedColours.contains(colour) {
                        selectedColours.removeAll { $0 == colour }
                    } else if selectedColours.count < Self.maxSelections {
                        selectedColours.append(colour)
                    }
                }) {
                    HStack {
                        Text(colour)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)

                        Spacer()

                        if selectedColours.contains(colour) {
                            Text(L10n.string("Selected"))
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }

                        colourSwatch(colour: colour, isSelected: selectedColours.contains(colour))

                        if selectedColours.contains(colour) {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                }
                .disabled(!selectedColours.contains(colour) && selectedColours.count >= Self.maxSelections)
            }
            .listRowBackground(Theme.Colors.background)
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Select Colours"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Theme.primaryColor)
            }
        }
    }

    private func colourSwatch(colour: String, isSelected: Bool) -> some View {
        let innerSize: CGFloat = 24
        let ringGap: CGFloat = 4
        let ringStroke: CGFloat = 2
        let outerSize = innerSize + ringGap * 2 + ringStroke * 2
        return ZStack {
            Circle()
                .fill(ColoursSelectionView.sampleColor(for: colour))
                .frame(width: innerSize, height: innerSize)
                .overlay(
                    Circle()
                        .strokeBorder(Theme.Colors.glassBorder, lineWidth: colour == "White" || colour == "Black" ? 1 : 0)
                )
            if isSelected {
                Circle()
                    .strokeBorder(Theme.primaryColor, lineWidth: ringStroke)
                    .frame(width: outerSize, height: outerSize)
            }
        }
        .frame(width: outerSize, height: outerSize)
    }

    private static func sampleColor(for name: String) -> Color {
        switch name.lowercased() {
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "pink": return .pink
        case "purple": return .purple
        case "orange": return .orange
        case "brown": return .brown
        case "grey", "gray": return .gray
        case "beige": return Color(red: 0.96, green: 0.96, blue: 0.86)
        case "navy": return Color(red: 0, green: 0, blue: 0.5)
        case "maroon": return Color(red: 0.5, green: 0, blue: 0)
        case "teal": return .teal
        default: return .gray
        }
    }
}

// MARK: - Size Selection View (sizes from backend by category path; under Colours in Item Information)
struct SizeSelectionView: View {
    @Binding var selectedSizeId: Int?
    @Binding var selectedSizeName: String?
    let categoryPath: String
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var authService: AuthService
    @State private var sizes: [APISize] = []
    @State private var isLoading = true
    @State private var loadError: String?
    private let productService = ProductService()

    var body: some View {
        Group {
            if categoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Text(L10n.string("Select a category first to see sizes"))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tint(Theme.primaryColor)
            } else if let error = loadError {
                VStack(spacing: Theme.Spacing.md) {
                    Text(error)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sizes, id: \.name) { size in
                        Button(action: {
                            selectedSizeId = size.id
                            selectedSizeName = size.name
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Text(size.name.replacingOccurrences(of: "_", with: " "))
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if selectedSizeId == size.id || selectedSizeName == size.name {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(Theme.primaryColor)
                                }
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                        .listRowBackground(Theme.Colors.background)
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Size"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            guard !categoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                isLoading = false
                return
            }
            productService.updateAuthToken(authService.authToken)
            isLoading = true
            loadError = nil
            do {
                var list = try await productService.fetchSizes(path: categoryPath)
                list = SizeSelectionView.sortedSizesForDisplay(list)
                sizes = list
            } catch {
                loadError = L10n.userFacingError(error)
                sizes = []
            }
            isLoading = false
        }
    }

    /// Order sizes to match backend fixture (add_sizes.py): ONE SIZE last, UK sizes numerically, letter sizes (XS,S,M,L,XL...), numeric-only by value.
    private static func sortedSizesForDisplay(_ list: [APISize]) -> [APISize] {
        return list.sorted { a, b in
            let na = a.name.uppercased()
            let nb = b.name.uppercased()
            if na == "ONE SIZE" { return false }
            if nb == "ONE SIZE" { return true }
            // UK sizes (e.g. UK 4, UK 6, UK 6.5)
            let ukA = parseUKSize(na)
            let ukB = parseUKSize(nb)
            if ukA != nil || ukB != nil {
                guard let va = ukA ?? ukB, let vb = ukB ?? ukA else { return na < nb }
                return va < vb
            }
            // Letter sizes: XXS, XS, S, M, L, XL, 2XL, ...
            let letterOrder = ["XXS", "XS", "S", "M", "L", "XL", "2XL", "3XL", "4XL", "5XL", "6XL", "7XL"]
            let ia = letterOrder.firstIndex(of: na) ?? letterOrder.count
            let ib = letterOrder.firstIndex(of: nb) ?? letterOrder.count
            if ia != ib { return ia < ib }
            // Numeric-only (e.g. kids shoes 15-40)
            if let va = Double(na), let vb = Double(nb) { return va < vb }
            return na < nb
        }
    }

    private static func parseUKSize(_ name: String) -> Double? {
        let pre = "UK "
        guard name.hasPrefix(pre) else { return nil }
        return Double(name.dropFirst(pre.count).trimmingCharacters(in: .whitespaces))
    }
}

// MARK: - Measurement entry for structured UI
private struct MeasurementRow: Identifiable {
    var id = UUID()
    var label: String
    var value: String
    var unit: String // "" for none, "in", "cm"
}

// MARK: - Measurements View (structured: label + value + unit; presets + custom)
struct MeasurementsView: View {
    @Binding var measurements: String?
    @Environment(\.presentationMode) var presentationMode
    @State private var entries: [MeasurementRow] = []
    @FocusState private var focusedRowId: UUID?

    private static let presetLabels = [
        "Chest", "Waist", "Hip", "Length", "Sleeve", "Inseam", "Shoulder", "Neck", "Size"
    ]
    private static let unitOptions = ["", "in", "cm"]

    var body: some View {
        VStack(spacing: 0) {
            if entries.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(entries) { entry in
                        measurementRowView(entry)
                    }
                    .onDelete(perform: deleteEntries)
                    .listRowBackground(Theme.Colors.background)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            addButton
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Measurements"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.string("Done")) {
                    commitToBinding()
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Theme.primaryColor)
            }
        }
        .onAppear {
            parseFromBinding()
        }
        .onDisappear {
            commitToBinding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "ruler")
                .font(.system(size: 44))
                .foregroundColor(Theme.Colors.secondaryText)
            Text(L10n.string("Add measurements like chest, waist, length"))
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private func measurementRowView(_ entry: MeasurementRow) -> some View {
        let binding = binding(for: entry)
        return HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Menu {
                ForEach(Self.presetLabels, id: \.self) { preset in
                    Button(preset) { binding.label.wrappedValue = preset }
                }
                Button(L10n.string("Custom…")) { binding.label.wrappedValue = "" }
            } label: {
                HStack(spacing: 4) {
                    Text(entry.label.isEmpty ? L10n.string("Label") : entry.label)
                        .font(Theme.Typography.body)
                        .foregroundColor(entry.label.isEmpty ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(width: 100, alignment: .leading)
            }
            TextField(L10n.string("Value"), text: binding.value)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
            Picker("", selection: binding.unit) {
                ForEach(Self.unitOptions, id: \.self) { opt in
                    Text(unitDisplay(opt)).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 56)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func binding(for entry: MeasurementRow) -> (label: Binding<String>, value: Binding<String>, unit: Binding<String>) {
        let i = entries.firstIndex(where: { $0.id == entry.id }) ?? 0
        return (
            Binding(get: { entries[i].label }, set: { entries[i].label = $0 }),
            Binding(get: { entries[i].value }, set: { entries[i].value = $0 }),
            Binding(get: { entries[i].unit }, set: { entries[i].unit = $0 })
        )
    }

    private func unitDisplay(_ unit: String) -> String {
        if unit.isEmpty { return "—" }
        return unit
    }

    private var addButton: some View {
        Button(action: addEntry) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(L10n.string("Add measurement"))
            }
            .font(Theme.Typography.body)
            .foregroundColor(Theme.primaryColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
    }

    private func addEntry() {
        entries.append(MeasurementRow(label: "", value: "", unit: ""))
    }

    private func deleteEntries(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    private static func parseLine(_ line: String) -> (label: String, value: String, unit: String)? {
        let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, let colon = line.firstIndex(of: ":") else { return nil }
        let label = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
        let rest = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        let parts = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let value = parts.isEmpty ? "" : String(parts[0])
        let unit = parts.count > 1 ? String(parts[1]) : ""
        return (label, value, unit)
    }

    private func parseFromBinding() {
        guard let raw = measurements, !raw.isEmpty else {
            entries = []
            return
        }
        let lines = raw.components(separatedBy: .newlines)
        entries = lines.compactMap { line -> MeasurementRow? in
            guard let t = Self.parseLine(line) else { return nil }
            return MeasurementRow(label: t.label, value: t.value, unit: t.unit)
        }
        if entries.isEmpty && !raw.isEmpty {
            entries = [MeasurementRow(label: "", value: raw, unit: "")]
        }
    }

    private func commitToBinding() {
        let lines = entries
            .filter { !$0.label.isEmpty && !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { row in
                let u = row.unit.trimmingCharacters(in: .whitespaces)
                return u.isEmpty ? "\(row.label): \(row.value)" : "\(row.label): \(row.value) \(u)"
            }
        measurements = lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

// MARK: - Material Selection View (materials fetched from backend)
struct MaterialSelectionView: View {
    @Binding var selectedMaterial: String?
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authService: AuthService
    @State private var materials: [APIMaterial] = []
    @State private var isLoading = true
    @State private var loadError: String?
    private let service = MaterialsService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tint(Theme.primaryColor)
            } else if let err = loadError {
                VStack(spacing: Theme.Spacing.md) {
                    Text(err)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(materials, id: \.id) { material in
                        Button(action: {
                            selectedMaterial = material.name
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Text(material.name)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)

                                Spacer()

                                if selectedMaterial == material.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.primaryColor)
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.Colors.background)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Select Material"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            service.setAuthToken(authService.authToken)
            await loadMaterials()
        }
    }

    private func loadMaterials() async {
        isLoading = true
        loadError = nil
        do {
            materials = try await service.fetchMaterials()
        } catch {
            loadError = L10n.userFacingError(error)
        }
        isLoading = false
    }
}

// MARK: - Style Selection View (tick when selected, multi-select max 2, list from GraphQL StyleEnum)
struct StyleSelectionView: View {
    @Binding var selectedStyles: [String]
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""

    /// Backend StyleEnum values (matches GraphQL schema; not fetched, enum is fixed).
    private static let styleEnumRawValues: [String] = [
        "WORKWEAR", "WORKOUT", "CASUAL", "PARTY_DRESS", "PARTY_OUTFIT", "FORMAL_WEAR", "EVENING_WEAR",
        "WEDDING_GUEST", "LOUNGEWEAR", "VACATION_RESORT_WEAR", "FESTIVAL_WEAR", "ACTIVEWEAR", "NIGHTWEAR",
        "VINTAGE", "Y2K", "BOHO", "MINIMALIST", "GRUNGE", "CHIC", "STREETWEAR", "PREPPY", "RETRO",
        "COTTAGECORE", "GLAM", "SUMMER_STYLES", "WINTER_ESSENTIALS", "SPRING_FLORALS", "AUTUMN_LAYERS",
        "RAINY_DAY_WEAR", "DENIM_JEANS", "DRESSES_GOWNS", "JACKETS_COATS", "KNITWEAR_SWEATERS",
        "SKIRTS_SHORTS", "SUITS_BLAZERS", "TOPS_BLOUSES", "SHOES_FOOTWEAR", "TRAVEL_FRIENDLY",
        "MATERNITY_WEAR", "ATHLEISURE", "ECO_FRIENDLY", "FESTIVAL_READY", "DATE_NIGHT", "ETHNIC_WEAR",
        "OFFICE_PARTY_OUTFIT", "COCKTAIL_ATTIRE", "PROM_DRESSES", "MUSIC_CONCERT_WEAR", "OVERSIZED",
        "SLIM_FIT", "RELAXED_FIT", "CHRISTMAS", "SCHOOL_UNIFORMS"
    ]

    private static let maxSelections = 2

    private var filteredStyles: [String] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return Self.styleEnumRawValues
        }
        return Self.styleEnumRawValues.filter {
            Self.displayName(for: $0).lowercased().contains(q)
        }
    }

    /// Human-readable label for a StyleEnum raw value (e.g. FORMAL_WEAR → "Formal wear").
    static func displayName(for rawValue: String) -> String {
        let lower = rawValue.replacingOccurrences(of: "_", with: " ").lowercased()
        guard !lower.isEmpty else { return rawValue }
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    var body: some View {
        VStack(spacing: 0) {
            DiscoverSearchField(
                text: $searchText,
                placeholder: L10n.string("Find a style"),
                outerPadding: true,
                topPadding: Theme.Spacing.sm
            )
            .padding(.trailing, Theme.Spacing.sm)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredStyles, id: \.self) { raw in
                        styleRow(rawValue: raw)
                        if raw != filteredStyles.last {
                            ContentDivider()
                        }
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Select Style"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.string("Done")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Theme.primaryColor)
            }
        }
    }

    private func styleRow(rawValue: String) -> some View {
        let isSelected = selectedStyles.contains(rawValue)
        let canSelect = selectedStyles.count < Self.maxSelections || isSelected
        return Button(action: {
            if isSelected {
                selectedStyles.removeAll { $0 == rawValue }
            } else if selectedStyles.count < Self.maxSelections {
                selectedStyles.append(rawValue)
            }
        }) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                Text(Self.displayName(for: rawValue))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Theme.primaryColor)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .contentShape(Rectangle())
            .opacity(canSelect ? 1 : 0.6)
        }
        .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
        .disabled(!canSelect)
    }
}

// MARK: - Price Input View (price field + similar items price comparison, matches Flutter price screen)
struct PriceInputView: View {
    @Binding var price: Double?
    var categoryId: String? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var priceText: String = ""
    @FocusState private var isFocused: Bool
    @State private var similarItems: [Item] = []
    @State private var similarLoading = false
    @State private var similarError: String?
    private let productService = ProductService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Price field — same styling as SettingsTextField (single rounded container, no extra bg)
                HStack(spacing: Theme.Spacing.sm) {
                    Text("£")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    TextField(L10n.string("0"), text: $priceText)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(30)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

                Text(L10n.string("Tip: similar price range is recommended based on similar items sold on Prelura."))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)

                // Similar sold items (feed-style grid)
                if let catId = categoryId, Int(catId) != nil {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(L10n.string("Similar sold items"))
                            .font(Theme.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.primaryColor)
                            .padding(.horizontal, Theme.Spacing.md)

                        if similarLoading {
                            PriceSimilarItemsShimmer()
                        } else if let err = similarError {
                            Text(err)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .padding(.horizontal, Theme.Spacing.md)
                        } else if !similarItems.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                                GridItem(.flexible(), spacing: Theme.Spacing.sm)
                            ], spacing: Theme.Spacing.sm) {
                                ForEach(similarItems.prefix(10), id: \.id) { item in
                                    PriceSimilarItemCard(item: item)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                    }
                    .padding(.top, Theme.Spacing.md)
                }
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Price"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.string("Done")) {
                    price = Double(priceText.replacingOccurrences(of: ",", with: "."))
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Theme.primaryColor)
            }
        }
        .onAppear {
            if let p = price, p > 0 {
                priceText = String(format: "%.0f", p)
            }
            isFocused = true
            if categoryId != nil {
                Task { await loadSimilarItems() }
            }
        }
    }

    private func loadSimilarItems() async {
        guard let catId = categoryId, let catIdInt = Int(catId) else { return }
        similarLoading = true
        similarError = nil
        do {
            similarItems = try await productService.getAllProducts(pageNumber: 1, pageCount: 10, categoryId: catIdInt)
        } catch {
            similarError = L10n.userFacingError(error)
        }
        similarLoading = false
    }
}

// Shimmer for "Similar sold items" feed while loading (2-column grid matching PriceSimilarItemCard layout).
private struct PriceSimilarItemsShimmer: View {
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Theme.Spacing.sm),
            GridItem(.flexible(), spacing: Theme.Spacing.sm)
        ], spacing: Theme.Spacing.sm) {
            ForEach(0..<6, id: \.self) { _ in
                PriceSimilarItemShimmerCell()
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .shimmering()
    }
}

private struct PriceSimilarItemShimmerCell: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 20, height: 20)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 60, height: 12)
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.xs * 1.5)

            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.Colors.secondaryBackground)
                .aspectRatio(1.0 / 1.3, contentMode: .fit)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 50, height: 14)
                    .padding(.top, Theme.Spacing.sm)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 80, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 40, height: 14)
            }
            .padding(.horizontal, Theme.Spacing.xs)
        }
    }
}

// Same product format as feed (HomeItemCard): seller above, image only, then brand/title/condition/price below. No price on image, no like button.
private struct PriceSimilarItemCard: View {
    let item: Item
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Seller row (avatar + username) above image — matches feed
            HStack(spacing: Theme.Spacing.xs) {
                if let avatarURL = item.seller.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Circle()
                                .fill(Theme.primaryColor)
                                .overlay(
                                    Text(String((item.seller.username.isEmpty ? "U" : item.seller.username).prefix(1)).uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Theme.primaryColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(String((item.seller.username.isEmpty ? "U" : item.seller.username).prefix(1)).uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                Text(item.seller.username.isEmpty ? "User" : item.seller.username)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.xs * 1.5)

            // Image only (no price overlay) — matches feed
            GeometryReader { geo in
                let w = geo.size.width
                let h = w * 1.3
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.primaryColor.opacity(0.3),
                                    Theme.primaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: w, height: h)
                    if let first = item.imageURLs.first, let imageUrl = URL(string: first) {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            case .empty:
                                ImageShimmerPlaceholderFilled(cornerRadius: 8)
                                    .frame(width: w, height: h)
                            default:
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.primaryColor.opacity(0.5))
                                    .frame(width: w, height: h)
                            }
                        }
                        .frame(width: w, height: h)
                        .clipped()
                        .cornerRadius(8)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.primaryColor.opacity(0.5))
                            .frame(width: w, height: h)
                    }
                }
                .frame(width: w, height: h)
            }
            .aspectRatio(1.0 / 1.3, contentMode: .fit)

            // Product details below image — matches feed (brand, title, condition, price)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if let brand = item.brand {
                    Text(brand)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                        .padding(.top, Theme.Spacing.sm)
                }
                Text(item.title)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
                Text(item.formattedCondition)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                HStack(spacing: Theme.Spacing.xs) {
                    if let originalPrice = item.originalPrice {
                        Text(item.formattedOriginalPrice)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .strikethrough()
                    }
                    Text(item.formattedPrice)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.primaryText)
                    if let discount = item.discountPercentage {
                        Text("\(discount)% Off")
                            .font(Theme.Typography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }
            }
        }
    }
}

// MARK: - Discount Price Input View (same UI as Price screen: scroll, single field, tip, Done)
struct DiscountPriceInputView: View {
    @Binding var price: Double?
    @Binding var discountPrice: Double?
    @Environment(\.presentationMode) var presentationMode
    @State private var discountPriceText: String = ""
    @FocusState private var isFocused: Bool
    
    private var discountPercent: Int {
        guard let price = price, let discountPrice = discountPrice, price > 0 else { return 0 }
        return Int(((price - discountPrice) / price) * 100)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Discount price field — same styling as Price screen (rounded container)
                HStack(spacing: Theme.Spacing.sm) {
                    Text("£")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    TextField(L10n.string("0"), text: $discountPriceText)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(30)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

                // Tip / state message
                if let p = price, p > 0 {
                    if let discount = Double(discountPriceText.replacingOccurrences(of: ",", with: ".")), discount > 0, discountPercent > 0 {
                        Text(String(format: L10n.string("Discount: %d%%"), discountPercent))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.primaryColor)
                            .padding(.horizontal, Theme.Spacing.md)
                    } else {
                        Text(L10n.string("Optional. Enter the discounted price; the discount % is calculated from the main price."))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .padding(.horizontal, Theme.Spacing.md)
                    }
                } else {
                    Text(L10n.string("Please set the price first"))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Discount Price"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.string("Done")) {
                    let parsed = Double(discountPriceText.replacingOccurrences(of: ",", with: "."))
                    discountPrice = parsed
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Theme.primaryColor)
            }
        }
        .onAppear {
            if let d = discountPrice, d > 0 {
                discountPriceText = String(format: "%.0f", d)
            }
            if price != nil && (price ?? 0) > 0 {
                isFocused = true
            }
        }
    }
}

// MARK: - Parcel Size Selection View (same layout as Condition: icon, title, subtitle, checkmark)
struct ParcelSizeSelectionView: View {
    @Binding var selectedParcelSize: String?
    @Environment(\.presentationMode) var presentationMode

    private static let options: [(key: String, title: String, subtitle: String, icon: String)] = [
        ("Small", "Small", "Letters, jewellery, accessories", "envelope"),
        ("Medium", "Medium", "Standard clothing, shoes", "shippingbox"),
        ("Large", "Large", "Coats, bags, bulkier items", "shippingbox.fill")
    ]

    var body: some View {
        List {
            ForEach(Self.options, id: \.key) { item in
                Button(action: {
                    selectedParcelSize = item.key
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(alignment: .center, spacing: Theme.Spacing.md) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(Theme.Colors.secondaryText)
                            .frame(width: 32, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(Theme.Typography.body)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.primaryText)
                            Text(item.subtitle)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }

                        Spacer()

                        if selectedParcelSize == item.key {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
            .listRowBackground(Theme.Colors.background)
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Parcel Size"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Brand Input View (integrated: Theme colours, feed-matching search field, brand suggestions from API)
struct BrandInputView: View {
    @Binding var selectedBrand: String?
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authService: AuthService
    @State private var brandText: String = ""
    @State private var fetchedBrands: [String] = []
    @State private var isLoadingBrands: Bool = false
    @FocusState private var isFocused: Bool

    private let productService = ProductService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DiscoverSearchField(
                text: $brandText,
                placeholder: L10n.string("Enter brand name"),
                outerPadding: true,
                topPadding: Theme.Spacing.xs
            )
            .padding(.trailing, Theme.Spacing.sm)
            .onAppear { isFocused = true }

            if isLoadingBrands && fetchedBrands.isEmpty {
                HStack {
                    ProgressView()
                        .tint(Theme.primaryColor)
                    Text(L10n.string("Loading brands..."))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.md)
            }

            if !fetchedBrands.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredBrands, id: \.self) { brand in
                            Button {
                                brandText = brand
                                selectedBrand = brand
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack {
                                    Text(brand)
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.primaryText)
                                    Spacer(minLength: 0)
                                    if selectedBrand == brand {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Theme.primaryColor)
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if brand != filteredBrands.last {
                                ContentDivider()
                            }
                        }
                    }
                    .padding(.top, Theme.Spacing.md)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Brand"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .tint(Theme.primaryColor)
        .onAppear {
            brandText = selectedBrand ?? ""
            Task { await loadBrands() }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    selectedBrand = brandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : brandText.trimmingCharacters(in: .whitespacesAndNewlines)
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(Theme.primaryColor)
            }
        }
    }

    private var filteredBrands: [String] {
        let q = brandText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return fetchedBrands }
        return fetchedBrands.filter { $0.lowercased().contains(q) }
    }

    private func loadBrands() async {
        await MainActor.run { isLoadingBrands = true }
        productService.updateAuthToken(authService.authToken)
        do {
            let brands = try await productService.getBrandNames()
            await MainActor.run {
                fetchedBrands = brands
                isLoadingBrands = false
            }
        } catch {
            await MainActor.run {
                fetchedBrands = []
                isLoadingBrands = false
            }
        }
    }
}

#Preview {
    SellView(selectedTab: .constant(0))
        .preferredColorScheme(.dark)
}
