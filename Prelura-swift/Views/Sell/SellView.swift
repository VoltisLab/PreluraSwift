import SwiftUI
import PhotosUI

struct SellView: View {
    @StateObject private var viewModel = SellViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: Category? = nil
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
    
    var body: some View {
        ScrollView {
                VStack(spacing: 0) {
                    // Upload from drafts
                    if draftCount > 0 {
                        draftsSection
                    }
                    
                    // Photo Upload Section
                    photoUploadSection
                    
                    // Item Details Section
                    itemDetailsSection
                    
                    // Additional Details Section
                    additionalDetailsSection
                    
                    // Pricing & Shipping Section
                    pricingShippingSection
                    
                    // Upload Button
                    uploadButton
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle("Sell an item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
    }
    
    // MARK: - Drafts Section
    private var draftsSection: some View {
        Button(action: {
            // TODO: Navigate to drafts
        }) {
            HStack {
                Text("Upload from drafts")
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
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Theme.Colors.glassBorder),
            alignment: .bottom
        )
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.Colors.secondaryBackground)
                            .frame(height: 200)
                        
                        if selectedImages.isEmpty {
                            VStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 50))
                                    .foregroundColor(Theme.primaryColor)
                                
                                Text("Add up to 20 photos")
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.Colors.primaryText)
                                
                                Text("Tap to select photos from your gallery")
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
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Theme.Colors.glassBorder),
            alignment: .bottom
        )
    }
    
    // MARK: - Item Details Section
    private var itemDetailsSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Item Details")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background)
            
            // Category Field
            NavigationLink(destination: CategorySelectionView(selectedCategory: $category)) {
                HStack {
                    Text("Category")
                        .font(Theme.Typography.body)
                        .foregroundColor(category == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let category = category {
                        Text(category.name)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
            
            // Brand Field
            NavigationLink(destination: BrandInputView(selectedBrand: $brand)) {
                HStack {
                    Text("Brand")
                        .font(Theme.Typography.body)
                        .foregroundColor(brand == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let brand = brand {
                        Text(brand)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
            
            // Condition Field
            NavigationLink(destination: ConditionSelectionView(selectedCondition: $condition)) {
                HStack {
                    Text("Condition")
                        .font(Theme.Typography.body)
                        .foregroundColor(condition == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let condition = condition {
                        Text(condition)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
            
            // Colours Field
            NavigationLink(destination: ColoursSelectionView(selectedColours: $colours)) {
                HStack {
                    Text("Colours")
                        .font(Theme.Typography.body)
                        .foregroundColor(colours.isEmpty ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if !colours.isEmpty {
                        Text(colours.joined(separator: ", "))
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                            .lineLimit(1)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
        }
    }
    
    // MARK: - Additional Details Section
    private var additionalDetailsSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Additional Details")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background)
            
            // Measurements Field
            NavigationLink(destination: MeasurementsView(measurements: $measurements)) {
                HStack {
                    Text("Measurements (Optional)")
                        .font(Theme.Typography.body)
                        .foregroundColor(measurements == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let measurements = measurements {
                        Text(measurements)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                            .lineLimit(1)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
            
            // Material Field
            NavigationLink(destination: MaterialSelectionView(selectedMaterial: $material)) {
                HStack {
                    Text("Material (Optional)")
                        .font(Theme.Typography.body)
                        .foregroundColor(material == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let material = material {
                        Text(material)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
            
            // Style Field
            NavigationLink(destination: StyleSelectionView(selectedStyle: $style)) {
                HStack {
                    Text("Style (Optional)")
                        .font(Theme.Typography.body)
                        .foregroundColor(style == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let style = style {
                        Text(style)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
        }
    }
    
    // MARK: - Pricing & Shipping Section
    private var pricingShippingSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Pricing & Shipping")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background)
            
            // Price Field
            NavigationLink(destination: PriceInputView(price: $price)) {
                HStack {
                    Text("Price")
                        .font(Theme.Typography.body)
                        .foregroundColor(price == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let price = price {
                        Text("£\(String(format: "%.0f", price))")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
            
            // Discount Price Field
            NavigationLink(destination: DiscountPriceInputView(price: $price, discountPrice: $discountPrice)) {
                HStack {
                    Text("Discount Price (Optional)")
                        .font(Theme.Typography.body)
                        .foregroundColor(discountPrice == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let price = price, let discountPrice = discountPrice, price > 0 {
                        let discountPercent = Int(((price - discountPrice) / price) * 100)
                        Text("\(discountPercent)%")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                    } else {
                        Text("0%")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
            
            // Parcel Size Field
            NavigationLink(destination: ParcelSizeSelectionView(selectedParcelSize: $parcelSize)) {
                HStack {
                    Text("Parcel Size")
                        .font(Theme.Typography.body)
                        .foregroundColor(parcelSize == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let parcelSize = parcelSize {
                        Text(parcelSize)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
            
            // Info Banner
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Text("The buyer always pays for postage.")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.primaryColor)
            .cornerRadius(8)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
    }
    
    // MARK: - Item Information Section
    private var itemInformationSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Item Information")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background)
            
            // Category Field
            NavigationLink(destination: CategorySelectionView(selectedCategory: $category)) {
                HStack {
                    Text("Category")
                        .font(Theme.Typography.body)
                        .foregroundColor(category == nil ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    
                    Spacer()
                    
                    if let category = category {
                        Text(category.name)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )
        }
    }
    
    // MARK: - Upload Button
    private var uploadButton: some View {
        Button(action: {
            viewModel.submitListing(
                title: title,
                description: description,
                price: price ?? 0.0,
                brand: "", // Will be set in next screen
                condition: condition ?? "",
                size: "", // Will be set in next screen
                category: category,
                images: selectedImages
            )
        }) {
            Text("Upload")
                .font(Theme.Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [Theme.primaryColor, Theme.primaryColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
        }
            .disabled(selectedImages.isEmpty || category == nil || condition == nil || price == nil)
            .opacity((selectedImages.isEmpty || category == nil || condition == nil || price == nil) ? 0.6 : 1.0)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.lg)
    }
}

// MARK: - Category Selection View
struct CategorySelectionView: View {
    @Binding var selectedCategory: Category?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            ForEach(Category.allCategories, id: \.id) { category in
                Button(action: {
                    selectedCategory = category
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(category.name)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Spacer()
                        
                        if selectedCategory?.id == category.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Theme.Colors.background)
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Condition Selection View
struct ConditionSelectionView: View {
    @Binding var selectedCondition: String?
    @Environment(\.presentationMode) var presentationMode
    
    let conditions = [
        "BRAND_NEW_WITH_TAGS": "Brand New With Tags",
        "BRAND_NEW_WITHOUT_TAGS": "Brand new Without Tags",
        "EXCELLENT_CONDITION": "Excellent Condition",
        "GOOD_CONDITION": "Good Condition",
        "HEAVILY_USED": "Heavily Used"
    ]
    
    var body: some View {
        List {
            ForEach(Array(conditions.keys.sorted()), id: \.self) { key in
                Button(action: {
                    selectedCondition = key
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(conditions[key] ?? key)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Spacer()
                        
                        if selectedCondition == key {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Theme.Colors.background)
        .navigationTitle("Select Condition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Colours Selection View
struct ColoursSelectionView: View {
    @Binding var selectedColours: [String]
    @Environment(\.presentationMode) var presentationMode
    @State private var availableColours = ["Black", "White", "Red", "Blue", "Green", "Yellow", "Pink", "Purple", "Orange", "Brown", "Grey", "Beige", "Navy", "Maroon", "Teal"]
    
    var body: some View {
        List {
            ForEach(availableColours, id: \.self) { colour in
                Button(action: {
                    if selectedColours.contains(colour) {
                        selectedColours.removeAll { $0 == colour }
                    } else {
                        selectedColours.append(colour)
                    }
                }) {
                    HStack {
                        Text(colour)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Spacer()
                        
                        if selectedColours.contains(colour) {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Theme.Colors.background)
        .navigationTitle("Select Colours")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
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
        .navigationTitle("Measurements")
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
        .navigationTitle("Select Material")
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
        .navigationTitle("Select Style")
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
        .navigationTitle("Price")
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
                        Text("Discount: \(discountPercent)%")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.primaryColor)
                    }
                }
                .padding(Theme.Spacing.md)
            } else {
                Text("Please set the price first")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(Theme.Spacing.md)
            }
            
            Spacer()
        }
        .background(Theme.Colors.background)
        .navigationTitle("Discount Price")
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
        .navigationTitle("Parcel Size")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Brand Input View
struct BrandInputView: View {
    @Binding var selectedBrand: String?
    @Environment(\.presentationMode) var presentationMode
    @State private var brandText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            TextField("Enter brand name", text: $brandText)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(8)
                .padding(Theme.Spacing.md)
                .focused($isFocused)
            
            Spacer()
        }
        .background(Theme.Colors.background)
        .navigationTitle("Brand")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            brandText = selectedBrand ?? ""
            isFocused = true
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    selectedBrand = brandText.isEmpty ? nil : brandText
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

#Preview {
    SellView()
        .preferredColorScheme(.dark)
}
