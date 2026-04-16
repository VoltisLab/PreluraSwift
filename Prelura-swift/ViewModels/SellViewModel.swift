import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
class SellViewModel: ObservableObject {
    @Published var isSubmitting: Bool = false
    @Published var submissionSuccess: Bool = false
    @Published var submissionError: String?
    /// When set, user chose “schedule”; the listing was saved as **INACTIVE** (see `ProductService.createProduct`). Shown in an alert before post-success navigation.
    @Published var listingSavedInactiveNotice: String?

    private let productService = ProductService()
    private let fileUploadService = FileUploadService()
    private let materialsService = MaterialsService()
    private let userService = UserService()

    /// Submit the full listing: upload images, then create product via GraphQL (matches Flutter createProduct flow).
    func submitListing(
        authToken: String?,
        title: String,
        description: String,
        price: Double,
        brand: String,
        condition: String,
        size: String,
        categoryId: String?,
        categoryName: String?,
        images: [UIImage],
        discountPrice: Double? = nil,
        parcelSize: String? = nil,
        colours: [String] = [],
        sizeId: Int? = nil,
        measurements: String? = nil,
        material: String? = nil,
        styles: [String] = [],
        scheduledPublishAt: Date? = nil
    ) {
        isSubmitting = true
        submissionError = nil
        listingSavedInactiveNotice = nil

        Task {
            do {
                guard let catIdStr = categoryId, let categoryIdInt = Int(catIdStr) else {
                    throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Please select a category."])
                }

                // Convert images to JPEG data (same as Flutter compression for upload)
                let imageDataList: [Data] = images.compactMap { image in
                    image.jpegData(compressionQuality: 0.85)
                }
                guard imageDataList.count == images.count, !imageDataList.isEmpty else {
                    throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare images."])
                }

                fileUploadService.setAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                productService.updateAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                materialsService.setAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))

                // 1. Upload product images (fileType: PRODUCT)
                let imageUrl = try await fileUploadService.uploadProductImages(imageDataList)

                // 2. Resolve brand id (use customBrand if not in list)
                let brandTrimmed = brand.trimmingCharacters(in: .whitespacesAndNewlines)
                let brandId = brandTrimmed.isEmpty ? nil : try? await productService.getBrandId(byName: brandTrimmed)
                let customBrand: String? = (brandId == nil && !brandTrimmed.isEmpty) ? brandTrimmed : nil

                // 3. Resolve material id(s) — we only have one material name
                var materialIds: [Int]? = nil
                if let mat = material, !mat.isEmpty, let mid = try? await materialsService.getMaterialId(byName: mat) {
                    materialIds = [mid]
                }

                // 4. Parcel size enum (Small -> SMALL, etc.)
                let parcelSizeEnum = Self.mapParcelSizeToEnum(parcelSize)

                // 5. Create product (optional measurements embedded in description; see ListingDescriptionAttachments)
                let titleRaw = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let descriptionRaw = description.trimmingCharacters(in: .whitespacesAndNewlines)
                let titleClean = ProfanityFilter.sanitize(titleRaw)
                let descriptionClean = ProfanityFilter.sanitize(descriptionRaw)
                let descriptionForApi = ListingDescriptionAttachments.embedMeasurements(descriptionClean, measurements: measurements)
                if ProfanityFilter.maskingWouldChange(titleRaw) || ProfanityFilter.maskingWouldChange(descriptionRaw) {
                    userService.updateAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                    let snippet = "\(titleClean) — \(descriptionClean)"
                    _ = try? await userService.recordProfanityUsage(
                        channel: "sell_listing",
                        relatedConversationId: nil,
                        sanitizedSnippet: snippet
                    )
                }
                let styleRaws = StyleSelectionView.normalizedUniqueStyleRaws(styles)
                let savedInactiveBecauseScheduled = scheduledPublishAt != nil
                let scheduleAt = scheduledPublishAt
                let newProductId = try await productService.createProduct(
                    name: titleClean,
                    description: descriptionForApi,
                    price: price,
                    imageUrl: imageUrl,
                    categoryId: categoryIdInt,
                    condition: condition.isEmpty ? nil : condition,
                    parcelSize: parcelSizeEnum,
                    discount: discountPrice,
                    color: colours.isEmpty ? nil : colours,
                    brandId: brandId,
                    customBrand: customBrand,
                    materialIds: materialIds,
                    style: styleRaws.first,
                    styles: styleRaws.count > 1 ? Array(styleRaws.prefix(2)) : nil,
                    sizeId: sizeId,
                    status: "ACTIVE",
                    scheduledPublishAt: scheduledPublishAt,
                    isMysteryBox: false,
                    mysteryIncludedProductIds: []
                )

                if savedInactiveBecauseScheduled, let at = scheduleAt {
                    PendingScheduledListingActivator.register(productId: newProductId, activateAt: at)
                    await ListingGoLiveReminder.schedule(productId: newProductId, fireDate: at, listingTitle: titleClean)
                }

                isSubmitting = false
                listingSavedInactiveNotice = savedInactiveBecauseScheduled
                    ? String(format: L10n.string("Your listing will appear on your profile on %@."), Self.formattedScheduleDate(scheduleAt ?? Date()))
                    : nil
                submissionSuccess = true
                if !savedInactiveBecauseScheduled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    submissionSuccess = false
                }
            } catch {
                isSubmitting = false
                submissionError = L10n.userFacingError(error)
            }
        }
    }

    /// Splits a single-field brand line (comma-separated) into trimmed names.
    private static func brandNames(fromJoinedOrSingleField line: String) -> [String] {
        line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// One catalog id when exactly one known brand; otherwise full list in `customBrand` (comma-separated).
    private static func resolveBrandFields(productService: ProductService, brandNames: [String]) async -> (brandId: Int?, customBrand: String?) {
        let parts = brandNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let first = parts.first else { return (nil, nil) }
        if parts.count == 1 {
            let id = try? await productService.getBrandId(byName: first)
            return (id, id == nil ? first : nil)
        }
        return (nil, parts.joined(separator: ", "))
    }

    /// Mystery box listing: uploads a single generated cover image, then creates the product with linked included listing ids.
    func submitMysteryBoxListing(
        authToken: String?,
        title: String,
        description: String,
        price: Double,
        brands: [String],
        condition: String,
        size: String,
        categoryId: String?,
        categoryName: String?,
        parcelSize: String? = nil,
        colours: [String] = [],
        sizeId: Int? = nil,
        measurements: String? = nil,
        material: String? = nil,
        styles: [String] = [],
        scheduledPublishAt: Date? = nil,
        mysteryIncludedProductIds: [Int]
    ) {
        isSubmitting = true
        submissionError = nil
        listingSavedInactiveNotice = nil

        Task {
            do {
                guard price > 0 else {
                    throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: L10n.string("Please enter a price.")])
                }
                guard price <= 100 else {
                    throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: L10n.string("Mystery box price cannot exceed £100.")])
                }
                guard !mysteryIncludedProductIds.isEmpty else {
                    throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: L10n.string("Select at least one listing to include in your mystery box.")])
                }
                guard let catIdStr = categoryId, let categoryIdInt = Int(catIdStr) else {
                    throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Please select a category."])
                }

                userService.updateAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                let profile = try await userService.getUser(username: nil)
                let existingProducts = try await userService.getUserProducts(username: nil)
                let activeMysteryCount = SellerMysteryQuota.activeMysteryListingCount(from: existingProducts)
                if let cap = SellerMysteryQuota.mysteryListingCap(profileTier: profile.profileTier), activeMysteryCount >= cap {
                    throw NSError(
                        domain: "SellViewModel",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: L10n.string("You've reached the maximum number of mystery box listings for your plan. Open Settings → Plan to upgrade.")]
                    )
                }

                guard let cover = MysteryBoxListingCoverImage.makeImage(),
                      let jpeg = cover.jpegData(compressionQuality: 0.85) else {
                    throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare listing image."])
                }

                fileUploadService.setAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                productService.updateAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                materialsService.setAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))

                let imageUrl = try await fileUploadService.uploadProductImages([jpeg])

                let brandParts = brands.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                guard !brandParts.isEmpty else {
                    throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: L10n.string("Please add at least one brand.")])
                }
                let (brandId, customBrand) = await Self.resolveBrandFields(productService: productService, brandNames: brandParts)

                var materialIds: [Int]? = nil
                if let mat = material, !mat.isEmpty, let mid = try? await materialsService.getMaterialId(byName: mat) {
                    materialIds = [mid]
                }

                let parcelSizeEnum = Self.mapParcelSizeToEnum(parcelSize)

                let titleRaw = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let descriptionRaw = description.trimmingCharacters(in: .whitespacesAndNewlines)
                let titleClean = ProfanityFilter.sanitize(titleRaw)
                let descriptionClean = ProfanityFilter.sanitize(descriptionRaw)
                let descriptionForApi = ListingDescriptionAttachments.embedMeasurements(descriptionClean, measurements: measurements)
                if ProfanityFilter.maskingWouldChange(titleRaw) || ProfanityFilter.maskingWouldChange(descriptionRaw) {
                    userService.updateAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                    let snippet = "\(titleClean) — \(descriptionClean)"
                    _ = try? await userService.recordProfanityUsage(
                        channel: "sell_mystery_box",
                        relatedConversationId: nil,
                        sanitizedSnippet: snippet
                    )
                }
                let styleRaws = StyleSelectionView.normalizedUniqueStyleRaws(styles)
                let savedInactiveBecauseScheduled = scheduledPublishAt != nil
                let scheduleAt = scheduledPublishAt
                let newProductId = try await productService.createProduct(
                    name: titleClean,
                    description: descriptionForApi,
                    price: price,
                    imageUrl: imageUrl,
                    categoryId: categoryIdInt,
                    condition: condition.isEmpty ? nil : condition,
                    parcelSize: parcelSizeEnum,
                    discount: nil,
                    color: colours.isEmpty ? nil : colours,
                    brandId: brandId,
                    customBrand: customBrand,
                    materialIds: materialIds,
                    style: styleRaws.first,
                    styles: styleRaws.count > 1 ? Array(styleRaws.prefix(2)) : nil,
                    sizeId: sizeId,
                    status: "ACTIVE",
                    scheduledPublishAt: scheduledPublishAt,
                    isMysteryBox: true,
                    mysteryIncludedProductIds: mysteryIncludedProductIds
                )

                if savedInactiveBecauseScheduled, let at = scheduleAt {
                    PendingScheduledListingActivator.register(productId: newProductId, activateAt: at)
                    await ListingGoLiveReminder.schedule(productId: newProductId, fireDate: at, listingTitle: titleClean)
                }

                isSubmitting = false
                listingSavedInactiveNotice = savedInactiveBecauseScheduled
                    ? String(format: L10n.string("Your listing will appear on your profile on %@."), Self.formattedScheduleDate(scheduleAt ?? Date()))
                    : nil
                submissionSuccess = true
                if !savedInactiveBecauseScheduled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    submissionSuccess = false
                }
            } catch {
                isSubmitting = false
                submissionError = L10n.userFacingError(error)
            }
        }
    }

    /// Update an existing listing. When `newListingImages` is empty, existing photos are unchanged. When non-empty, uploads are appended and the full gallery is sent with `UPDATE_INDEX`.
    func updateListing(
        authToken: String?,
        productId: Int,
        existingImagePairs: [(url: String, thumbnail: String)],
        title: String,
        description: String,
        price: Double,
        brand: String,
        condition: String,
        size: String,
        categoryId: String?,
        categoryName: String?,
        newListingImages: [UIImage],
        discountPrice: Double? = nil,
        parcelSize: String? = nil,
        colours: [String] = [],
        sizeId: Int? = nil,
        measurements: String? = nil,
        material: String? = nil,
        styles: [String] = []
    ) {
        isSubmitting = true
        submissionError = nil
        listingSavedInactiveNotice = nil
        Task {
            do {
                guard let catIdStr = categoryId, let categoryIdInt = Int(catIdStr) else {
                    throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Please select a category."])
                }
                fileUploadService.setAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                productService.updateAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                materialsService.setAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))

                let brandParts = Self.brandNames(fromJoinedOrSingleField: brand)
                let (brandId, customBrand) = await Self.resolveBrandFields(productService: productService, brandNames: brandParts)

                var materialIds: [Int]? = nil
                if let mat = material, !mat.isEmpty, let mid = try? await materialsService.getMaterialId(byName: mat) {
                    materialIds = [mid]
                }

                let parcelSizeEnum = Self.mapParcelSizeToEnum(parcelSize)

                var imagePairs: [(url: String, thumbnail: String)]? = nil
                var imageAction: String? = nil
                if !newListingImages.isEmpty {
                    let imageDataList: [Data] = newListingImages.compactMap { $0.jpegData(compressionQuality: 0.85) }
                    guard imageDataList.count == newListingImages.count else {
                        throw NSError(domain: "SellViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare images."])
                    }
                    let uploaded = try await fileUploadService.uploadProductImages(imageDataList)
                    let combined = existingImagePairs + uploaded
                    imagePairs = combined
                    imageAction = "UPDATE_INDEX"
                }

                let titleRaw = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let descriptionRaw = description.trimmingCharacters(in: .whitespacesAndNewlines)
                let titleClean = ProfanityFilter.sanitize(titleRaw)
                let descriptionClean = ProfanityFilter.sanitize(descriptionRaw)
                let descriptionForApi = ListingDescriptionAttachments.embedMeasurements(descriptionClean, measurements: measurements)
                if ProfanityFilter.maskingWouldChange(titleRaw) || ProfanityFilter.maskingWouldChange(descriptionRaw) {
                    userService.updateAuthToken(authToken ?? UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
                    let snippet = "\(titleClean) — \(descriptionClean)"
                    _ = try? await userService.recordProfanityUsage(
                        channel: "sell_listing_edit",
                        relatedConversationId: nil,
                        sanitizedSnippet: snippet
                    )
                }
                let styleRaws = StyleSelectionView.normalizedUniqueStyleRaws(styles)
                try await productService.updateProduct(
                    productId: productId,
                    name: titleClean,
                    description: descriptionForApi,
                    price: price,
                    categoryId: categoryIdInt,
                    condition: condition.isEmpty ? nil : condition,
                    parcelSize: parcelSizeEnum,
                    discountSalePrice: discountPrice,
                    color: colours.isEmpty ? nil : colours,
                    brandId: brandId,
                    customBrand: customBrand,
                    materialIds: materialIds,
                    style: styleRaws.first,
                    styles: styleRaws.count > 1 ? Array(styleRaws.prefix(2)) : nil,
                    sizeId: sizeId,
                    imagePairs: imagePairs,
                    imageAction: imageAction
                )

                isSubmitting = false
                submissionSuccess = true
                try? await Task.sleep(nanoseconds: 500_000_000)
                submissionSuccess = false
            } catch {
                isSubmitting = false
                submissionError = L10n.userFacingError(error)
            }
        }
    }

    func acknowledgeInactiveListingSavedNotice() {
        listingSavedInactiveNotice = nil
        submissionSuccess = false
    }

    private static func formattedScheduleDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// Maps UI parcel size to backend ParcelSizeEnum. Backend only supports SMALL, MEDIUM, LARGE.
    private static func mapParcelSizeToEnum(_ value: String?) -> String? {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        switch v.lowercased() {
        case "small": return "SMALL"
        case "medium": return "MEDIUM"
        case "large", "extra large": return "LARGE"
        default: return "LARGE"
        }
    }
}
