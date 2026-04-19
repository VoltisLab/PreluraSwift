import SwiftUI
import PhotosUI

/// Report user/account options (Flutter ReportAccountOptionsRoute).
struct ReportUserView: View {
    let username: String
    var isProduct: Bool = false
    var productId: Int?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var selectedOption: String?
    @State private var showDetailsScreen = false

    private let userService = UserService()
    private let productService = ProductService()

    private let userOptions = [
        "This user has engaged in inappropriate or offensive behaviour towards others",
        "This user has engaged in harassing or abusive behaviour towards others on the platform.",
        "The user has violated our community guidelines and terms of service.",
        "The user has posted inappropriate or explicit content.",
        "This user has been involved in fraudulent or deceptive activities.",
        "The user has been consistently unprofessional in their conduct.",
        "The user has been impersonating someone else on the platform.",
        "Other",
    ]
    private let productOptions = [
        "The product has violated our community guidelines and terms of service.",
        "The product has posted inappropriate or explicit content.",
        "This product has been involved in fraudulent or deceptive activities.",
        "The product has been consistently unprofessional in their description.",
        "Other",
    ]

    private var options: [String] { isProduct ? productOptions : userOptions }

    var body: some View {
        List {
            ForEach(options, id: \.self) { option in
                Button {
                    selectedOption = option
                    showDetailsScreen = true
                } label: {
                    HStack {
                        Text(option)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if selectedOption == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(PlainTappableButtonStyle())
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDetailsScreen) {
            if let selectedOption {
                ReportUserDetailsView(
                    username: username,
                    isProduct: isProduct,
                    productId: productId,
                    reason: selectedOption
                )
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct ReportUserDetailsView: View {
    let username: String
    let isProduct: Bool
    let productId: Int?
    let reason: String

    @State private var description: String = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showMacReportPhotoImporter: Bool = false
    @State private var selectedImageDataList: [Data] = []
    @State private var selectedPreviewImages: [UIImage] = []
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSubmitting = false

    private let userService = UserService()
    private let productService = ProductService()
    private let fileUploadService = FileUploadService()

    var body: some View {
        // `TextEditor` in `List` rows is vertically centered by the list; use `ScrollView` like Sell so the caret stays top-leading.
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Reason")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text(reason)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    PreluraMultilineDescriptionField(
                        placeholder: "",
                        text: $description,
                        minLines: 6,
                        highlightHashtags: false
                    )
                    .accessibilityLabel("Details")
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Group {
                        if IOSAppOnMacImageImport.isIOSAppOnMac {
                            Button {
                                showMacReportPhotoImporter = true
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Upload photos (optional)")
                                }
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.primaryColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, Theme.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                        } else {
                            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 6, matching: .images) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Upload photos (optional)")
                                }
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.primaryColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, Theme.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !selectedPreviewImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.xs) {
                                ForEach(Array(selectedPreviewImages.enumerated()), id: \.offset) { _, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }

                if let successMessage {
                    Text(successMessage)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.primaryColor)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.error)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.background)
        .navigationTitle("Report details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryGlassButton(isSubmitting ? "Submitting..." : "Submit report", isLoading: isSubmitting) {
                Task { await submit() }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background)
            .disabled(isSubmitting)
        }
        .macOnlyImageFileImporter(
            isPresented: $showMacReportPhotoImporter,
            allowsMultipleSelection: true,
            maxImageCount: 6
        ) { images in
            let capped = Array(images.prefix(6))
            selectedImageDataList = IOSAppOnMacImageImport.jpegDataList(from: capped, maxCount: 6)
            selectedPreviewImages = capped
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                var loaded: [Data] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(data)
                    }
                }
                await MainActor.run {
                    selectedImageDataList = loaded
                    selectedPreviewImages = loaded.compactMap { UIImage(data: $0) }
                }
            }
        }
    }

    private func submit() async {
        await MainActor.run {
            isSubmitting = true
            errorMessage = nil
            successMessage = nil
        }
        do {
            fileUploadService.setAuthToken(UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
            userService.updateAuthToken(UserDefaults.standard.string(forKey: "AUTH_TOKEN"))
            let uploaded: [(url: String, thumbnail: String)] = selectedImageDataList.isEmpty ? [] : (try await fileUploadService.uploadProductImages(selectedImageDataList))
            let imageUrls = uploaded.map { $0.url }
            let descRaw = description.trimmingCharacters(in: .whitespacesAndNewlines)
            let reportContent = ProfanityFilter.sanitize(descRaw)
            if ProfanityFilter.maskingWouldChange(descRaw) {
                _ = try? await userService.recordProfanityUsage(
                    channel: isProduct ? "report_product" : "report_account",
                    relatedConversationId: nil,
                    sanitizedSnippet: reportContent
                )
            }
            let submittedRef: SubmittedReportRef?
            if isProduct, let pid = productId {
                submittedRef = try await productService.reportProduct(
                    productId: String(pid),
                    reason: reason,
                    content: reportContent,
                    imagesUrl: imageUrls
                )
            } else {
                submittedRef = try await userService.reportAccount(
                    username: username,
                    reason: reason,
                    content: reportContent,
                    imagesUrl: imageUrls
                )
            }
            await MainActor.run {
                isSubmitting = false
                let ref = submittedRef?.publicId ?? "submitted"
                successMessage = "Report submitted. Reference: \(ref)"
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = L10n.userFacingError(error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReportUserView(username: "testuser")
            .environmentObject(AuthService())
    }
}
