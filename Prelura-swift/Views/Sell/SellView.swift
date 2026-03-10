import SwiftUI
import PhotosUI

struct SellView: View {
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SellViewModel()
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: SellCategory? = nil
    @State private var brand: String? = nil
    @State private var condition: String? = nil
    @State private var colours: [String] = []
    @State private var measurements: String? = nil
    @State private var material: String? = nil
    @State private var style: String? = nil
    @State private var price: Double? = nil
    @State private var discountPrice: Double? = nil
    @State private var parcelSize: String? = nil
    @State private var draftCount: Int = 5 // TODO: Fetch from backend

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
                    action: {
                        viewModel.submitListing(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            price: price ?? 0.0,
                            brand: brand ?? "",
                            condition: condition ?? "",
                            size: "",
                            categoryId: category?.id,
                            categoryName: category?.name,
                            images: selectedImages
                        )
                    }
                )
            }
        }
        .navigationTitle(L10n.string("Sell an item"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CircleCloseButton(action: { dismiss() })
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
    
    // MARK: - Photo Upload Section
    private var photoUploadSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 20,
                matching: .images
            ) {
                VStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.Colors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Theme.Colors.glassBorder, lineWidth: 1)
                            )
                            .frame(height: 200)
                        
                        if selectedImages.isEmpty {
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
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 180, height: 180)
                                                .clipped()
                                                .cornerRadius(8)
                                            
                                            Button(action: {
                                                selectedImages.remove(at: index)
                                                selectedPhotos.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                    
                                    // Add more button
                                    if selectedImages.count < 20 {
                                        Button(action: {}) {
                                            VStack {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 30))
                                                    .foregroundColor(Theme.primaryColor)
                                            }
                                            .frame(width: 180, height: 180)
                                            .background(Theme.Colors.secondaryBackground)
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.sm)
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedPhotos) { newItems in
                Task {
                    selectedImages = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImages.append(image)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .overlay(ContentDivider(), alignment: .bottom)
    }
    
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

            NavigationLink(destination: CategorySelectionView(selectedCategory: $category)) {
                SellFormRow(title: L10n.string("Category"), value: category?.name)
            }
            .buttonStyle(.plain)
            .overlay(ContentDivider(), alignment: .bottom)

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
            NavigationLink(destination: StyleSelectionView(selectedStyle: $style)) {
                SellFormRow(title: L10n.string("Style (Optional)"), value: style)
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
            NavigationLink(destination: PriceInputView(price: $price)) {
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

// MARK: - Category Selection View (hierarchical, matches Flutter: root → children → leaf)
struct CategorySelectionView: View {
    @Binding var selectedCategory: SellCategory?
    @Environment(\.presentationMode) var presentationMode
    @State private var categories: [APICategory] = []
    @State private var isLoading = true
    @State private var loadError: String?
    private let service = CategoriesService()

    private static let rootOrder = ["Men", "Women", "Boys", "Girls", "Toddlers"]

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
                    ForEach(sortedCategories, id: \.id) { cat in
                        if cat.hasChildren == true {
                            NavigationLink(destination: SubCategoryView(
                                parentId: cat.id,
                                parentName: cat.name,
                                selectedCategory: $selectedCategory
                            )) {
                                categoryRow(cat.name, isSelected: false)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                selectedCategory = SellCategory(id: cat.id, name: cat.name)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                categoryRow(cat.name, isSelected: selectedCategory?.id == cat.id)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Select Category"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await loadCategories(parentId: nil)
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
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Sub Category View (children of a category; recursive)
struct SubCategoryView: View {
    let parentId: String
    let parentName: String
    @Binding var selectedCategory: SellCategory?
    @Environment(\.presentationMode) var presentationMode
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
                                selectedCategory: $selectedCategory
                            )) {
                                subCategoryRow(cat)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                selectedCategory = SellCategory(id: cat.id, name: cat.name)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                subCategoryRow(cat)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(parentName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            let id = Int(parentId)
            await loadCategories(parentId: id)
        }
    }

    private func subCategoryRow(_ cat: APICategory) -> some View {
        HStack {
            Text(cat.name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            if selectedCategory?.id == cat.id {
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
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Condition Selection View (display names, subtitles, icons)
struct ConditionSelectionView: View {
    @Binding var selectedCondition: String?
    @Environment(\.presentationMode) var presentationMode

    private static let conditions: [(key: String, title: String, subtitle: String, icon: String)] = [
        ("BRAND_NEW_WITH_TAGS", "Brand New With Tags", "Never worn, with original tags", "tag.fill"),
        ("BRAND_NEW_WITHOUT_TAGS", "Brand new Without Tags", "Never worn, tags removed", "sparkles"),
        ("EXCELLENT_CONDITION", "Excellent Condition", "Like new, minimal wear", "star.fill"),
        ("GOOD_CONDITION", "Good Condition", "Light wear, fully functional", "checkmark.circle.fill"),
        ("HEAVILY_USED", "Heavily Used", "Visible wear, still usable", "clock.fill")
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
                            .font(.system(size: 22))
                            .foregroundColor(Theme.primaryColor)
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
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        }
        .listStyle(PlainListStyle())
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

                        Circle()
                            .fill(ColoursSelectionView.sampleColor(for: colour))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.Colors.glassBorder, lineWidth: colour == "White" || colour == "Black" ? 1 : 0)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.primaryColor, lineWidth: selectedColours.contains(colour) ? 3 : 0)
                            )
                    }
                }
                .disabled(!selectedColours.contains(colour) && selectedColours.count >= Self.maxSelections)
            }
        }
        .listStyle(PlainListStyle())
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

// MARK: - Measurements View
struct MeasurementsView: View {
    @Binding var measurements: String?
    @Environment(\.presentationMode) var presentationMode
    @State private var measurementsText: String = ""
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            TextEditor(text: $measurementsText)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .frame(minHeight: 200)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(8)
                .padding(Theme.Spacing.md)
            
            Spacer()
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Measurements"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            measurementsText = measurements ?? ""
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    measurements = measurementsText.isEmpty ? nil : measurementsText
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - Material Selection View
struct MaterialSelectionView: View {
    @Binding var selectedMaterial: String?
    @Environment(\.presentationMode) var presentationMode
    
    let materials = ["Cotton", "Polyester", "Wool", "Silk", "Leather", "Denim", "Linen", "Cashmere", "Synthetic", "Other"]
    
    var body: some View {
        List {
            ForEach(materials, id: \.self) { material in
                Button(action: {
                    selectedMaterial = material
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(material)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Spacer()
                        
                        if selectedMaterial == material {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Select Material"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Style Selection View
struct StyleSelectionView: View {
    @Binding var selectedStyle: String?
    @Environment(\.presentationMode) var presentationMode
    
    let styles = ["Casual", "Formal", "Vintage", "Streetwear", "Bohemian", "Minimalist", "Sporty", "Elegant", "Edgy", "Classic", "Trendy", "Other"]
    
    var body: some View {
        List {
            ForEach(styles, id: \.self) { style in
                Button(action: {
                    selectedStyle = style
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(style)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Spacer()
                        
                        if selectedStyle == style {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Select Style"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Price Input View
struct PriceInputView: View {
    @Binding var price: Double?
    @Environment(\.presentationMode) var presentationMode
    @State private var priceText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text("£")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.primaryText)
                
                TextField("0", text: $priceText)
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.primaryText)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(8)
            .padding(Theme.Spacing.md)
            
            Spacer()
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Price"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let price = price {
                priceText = String(format: "%.0f", price)
            }
            isFocused = true
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    price = Double(priceText)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - Discount Price Input View
struct DiscountPriceInputView: View {
    @Binding var price: Double?
    @Binding var discountPrice: Double?
    @Environment(\.presentationMode) var presentationMode
    @State private var discountPriceText: String = ""
    @FocusState private var isFocused: Bool
    
    var discountPercent: Int {
        guard let price = price, let discountPrice = discountPrice, price > 0 else { return 0 }
        return Int(((price - discountPrice) / price) * 100)
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let price = price, price > 0 {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Original Price: £\(String(format: "%.0f", price))")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    HStack {
                        Text("£")
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        TextField("0", text: $discountPriceText)
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.primaryText)
                            .keyboardType(.decimalPad)
                            .focused($isFocused)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(8)
                    
                    if discountPercent > 0 {
                        Text(String(format: L10n.string("Discount: %d%%"), discountPercent))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.primaryColor)
                    }
                }
                .padding(Theme.Spacing.md)
            } else {
                Text(L10n.string("Please set the price first"))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(Theme.Spacing.md)
            }
            
            Spacer()
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Discount Price"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if let discountPrice = discountPrice {
                discountPriceText = String(format: "%.0f", discountPrice)
            }
            if price != nil {
                isFocused = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    discountPrice = Double(discountPriceText)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - Parcel Size Selection View
struct ParcelSizeSelectionView: View {
    @Binding var selectedParcelSize: String?
    @Environment(\.presentationMode) var presentationMode
    
    let parcelSizes = ["Small", "Medium", "Large", "Extra Large"]
    
    var body: some View {
        List {
            ForEach(parcelSizes, id: \.self) { size in
                Button(action: {
                    selectedParcelSize = size
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(size)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Spacer()
                        
                        if selectedParcelSize == size {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Parcel Size"))
        .navigationBarTitleDisplayMode(.inline)
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
                                Text(brand)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .padding(.horizontal, Theme.Spacing.md)
                            }
                            .buttonStyle(.plain)
                            if brand != filteredBrands.last {
                                ContentDivider()
                                    .padding(.leading, Theme.Spacing.md)
                            }
                        }
                    }
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.Glass.cornerRadius)
                    .padding(.horizontal, Theme.Spacing.md)
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
        isLoadingBrands = true
        productService.updateAuthToken(authService.authToken)
        do {
            let brands = try await productService.getBrandNames()
            fetchedBrands = brands
        } catch {
            fetchedBrands = []
        }
        isLoadingBrands = false
    }
}

#Preview {
    SellView(selectedTab: .constant(0))
        .preferredColorScheme(.dark)
}
