//
//  LookbooksUploadView.swift
//  Prelura-swift
//
//  Debug: upload banner, zoom/pan cropper, Upload + Tag (active when image selected).
//

import SwiftUI
import PhotosUI
import CoreImage

// MARK: - Models

struct LookbookTagData: Codable, Identifiable, Equatable {
    var id: String { "\(productId)_\(x)_\(y)" }
    let productId: String
    let x: Double
    let y: Double
}

struct LookbookUploadRecord: Codable {
    let id: String
    let imagePath: String
    var tags: [LookbookTagData]
    var caption: String?
}

// MARK: - Store

private enum LookbookUploadStore {
    static let defaults = UserDefaults.standard
    static let currentKey = "lookbook_upload_current"
    static let tagsPrefix = "lookbook_tags_"

    static func saveCurrent(record: LookbookUploadRecord) {
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: currentKey)
        }
    }

    static func loadCurrent() -> LookbookUploadRecord? {
        guard let data = defaults.data(forKey: currentKey),
              let record = try? JSONDecoder().decode(LookbookUploadRecord.self, from: data) else { return nil }
        return record
    }

    static func saveTags(imageId: String, tags: [LookbookTagData]) {
        if let data = try? JSONEncoder().encode(tags) {
            defaults.set(data, forKey: tagsPrefix + imageId)
        }
    }

    static func loadTags(imageId: String) -> [LookbookTagData] {
        guard let data = defaults.data(forKey: tagsPrefix + imageId),
              let tags = try? JSONDecoder().decode([LookbookTagData].self, from: data) else { return [] }
        return tags
    }
}

// MARK: - First page: Upload banner + two bottom buttons (active only when image selected)

struct LookbooksUploadView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImage: UIImage?
    @State private var caption: String = ""
    @State private var uploadState: UploadState = .idle
    @State private var showTagScreen = false
    @State private var uploadedRecord: LookbookUploadRecord?

    enum UploadState {
        case idle
        case uploading
        case uploaded
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Upload banner: full width, placeholder or selected image
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 1,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Group {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 44))
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Text("Tap to upload")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 200)
                        .background(Theme.Colors.secondaryBackground)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 200)
                .contentShape(Rectangle())
            }
            .onChange(of: selectedItems) { _, newValue in
                Task { await loadImage(from: newValue.first) }
            }

            if selectedImage != nil {
                TextField("Caption", text: $caption, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.Spacing.xs)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
            }

            Spacer(minLength: 24)

            // Two buttons at bottom – active only when image selected
            VStack(spacing: Theme.Spacing.sm) {
                if case .uploading = uploadState {
                    HStack(spacing: Theme.Spacing.sm) {
                        ProgressView()
                        Text("Uploading…")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }
                if case .failed(let msg) = uploadState {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                HStack(spacing: Theme.Spacing.md) {
                    Button("Upload") {
                        uploadImage()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(selectedImage == nil || uploadState.uploading)

                    Button("Tag") {
                        showTagScreen = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(selectedImage == nil)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .navigationTitle("Lookbooks Upload")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showTagScreen) {
            if let image = selectedImage {
                LookbookTagProductsView(
                    image: image,
                    imageURL: uploadedRecord.flatMap { lookbookImageURL($0.imagePath) },
                    imageId: uploadedRecord?.id ?? UUID().uuidString,
                    initialTags: uploadedRecord?.tags ?? [],
                    onDismiss: { showTagScreen = false }
                )
                .environmentObject(authService)
            }
        }
    }

    private func lookbookImageURL(_ path: String) -> URL? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return dir.appending(path: "lookbooks").appending(path: path)
    }

    private func loadImage(from pickerItem: PhotosPickerItem?) async {
        guard let pickerItem = pickerItem else {
            selectedImage = nil
            return
        }
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run {
            selectedImage = image
        }
    }

    private func uploadImage() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.85) else {
            uploadState = .failed("Could not encode image")
            return
        }
        uploadState = .uploading
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        service.setAuthToken(authService.authToken)
        Task {
            do {
                let imageUrl = try await service.uploadLookbookImage(imageData)
                _ = try await service.createLookbook(imageUrl: imageUrl, caption: caption.isEmpty ? nil : caption)
                await MainActor.run {
                    uploadState = .idle
                    selectedImage = nil
                    caption = ""
                    selectedItems = []
                    uploadedRecord = nil
                }
            } catch {
                await MainActor.run {
                    uploadState = .failed(error.localizedDescription)
                }
            }
        }
    }
}

extension LookbooksUploadView.UploadState {
    var uploading: Bool {
        if case .uploading = self { return true }
        return false
    }
}

// MARK: - Full-width zoom/pan cropper (UIKit) + Save button

struct ZoomableImageCropView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZoomableImageCropRepresentable(image: image, onSave: onSave)
                .ignoresSafeArea(edges: .top)
            Button("Save") {
                cropAndSave()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
            .background(Theme.Colors.background)
        }
        .background(Color.black)
        .overlay(alignment: .topLeading) {
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            .padding()
        }
    }

    private func cropAndSave() {
        NotificationCenter.default.post(name: .lookbookCropSaveRequested, object: nil)
    }
}

extension Notification.Name {
    static let lookbookCropSaveRequested = Notification.Name("lookbookCropSaveRequested")
}

struct ZoomableImageCropRepresentable: UIViewControllerRepresentable {
    let image: UIImage
    let onSave: (UIImage) -> Void

    func makeUIViewController(context: Context) -> ZoomableCropViewController {
        let vc = ZoomableCropViewController(image: image)
        vc.onSave = onSave
        return vc
    }

    func updateUIViewController(_ uiViewController: ZoomableCropViewController, context: Context) {}
}

final class ZoomableCropViewController: UIViewController {
    var onSave: ((UIImage) -> Void)?
    private let image: UIImage
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(saveRequested), name: .lookbookCropSaveRequested, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        var size = scrollView.bounds.size
        if size.width <= 0 || size.height <= 0 {
            size = view.bounds.size
        }
        guard size.width > 0, size.height > 0 else { return }
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }
        let scale = min(size.width / imgSize.width, size.height / imgSize.height)
        let displayW = imgSize.width * scale
        let displayH = imgSize.height * scale
        imageView.frame = CGRect(x: 0, y: 0, width: displayW, height: displayH)
        scrollView.contentSize = imageView.frame.size
        scrollView.zoomScale = 1
        scrollView.contentOffset = .zero
    }

    @objc private func saveRequested() {
        let scale = scrollView.zoomScale
        let offset = scrollView.contentOffset
        let bounds = scrollView.bounds
        let imgSize = image.size
        let displayScale = min(bounds.width / imgSize.width, bounds.height / imgSize.height)
        let displayW = imgSize.width * displayScale
        let displayH = imgSize.height * displayScale
        let cropX = (offset.x / scale) * (imgSize.width / displayW)
        let cropY = (offset.y / scale) * (imgSize.height / displayH)
        let cropW = (bounds.width / scale) * (imgSize.width / displayW)
        let cropH = (bounds.height / scale) * (imgSize.height / displayH)
        let rect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH).integral
        guard let cg = image.cgImage else {
            if let ci = image.ciImage {
                let ctx = CIContext()
                guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return }
                let scaleFactor = CGFloat(cg.width) / imgSize.width
                let pixelRect = CGRect(x: rect.minX * scaleFactor, y: rect.minY * scaleFactor, width: rect.width * scaleFactor, height: rect.height * scaleFactor).integral
                let boundsPx = CGRect(origin: .zero, size: CGSize(width: CGFloat(cg.width), height: CGFloat(cg.height)))
                let r = pixelRect.intersection(boundsPx)
                guard r.width > 0, r.height > 0, let cropped = cg.cropping(to: r) else { return }
                onSave?(UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation))
            }
            return
        }
        let scaleFactor = CGFloat(cg.width) / imgSize.width
        let pixelRect = CGRect(x: rect.minX * scaleFactor, y: rect.minY * scaleFactor, width: rect.width * scaleFactor, height: rect.height * scaleFactor).integral
        let boundsPx = CGRect(origin: .zero, size: CGSize(width: CGFloat(cg.width), height: CGFloat(cg.height)))
        let r = pixelRect.intersection(boundsPx)
        guard r.width > 0, r.height > 0, let cropped = cg.cropping(to: r) else { return }
        onSave?(UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation))
    }
}

extension ZoomableCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
}

private struct ImageFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let n = nextValue()
        if n != .zero { value = n }
    }
}

// MARK: - Tag products (full-screen): draggable dot + Tag product button

struct LookbookTagProductsView: View {
    var image: UIImage?
    var imageURL: URL?
    let imageId: String
    let initialTags: [LookbookTagData]
    let onDismiss: () -> Void

    @EnvironmentObject var authService: AuthService
    @State private var tags: [LookbookTagData] = []
    @State private var resolvedItems: [String: Item] = [:]
    @State private var showProductSearch = false
    @State private var dotPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var selectedItemForDetail: Item?
    @State private var imageFrame: CGRect = .zero

    private let productService = ProductService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        imageContent(geo: geo)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .coordinateSpace(name: "lookbookContainer")
                            .onPreferenceChange(ImageFramePreferenceKey.self) { imageFrame = $0 }

                        if imageFrame != .zero {
                            ForEach(tags) { tag in
                                if let item = resolvedItems[tag.productId] {
                                    lookbookTagBadge(tag: tag, item: item, imageFrame: imageFrame) { newX, newY in
                                        updateTagPosition(tag: tag, newX: newX, newY: newY)
                                    }
                                }
                            }
                            draggableDot(geo: geo)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .ignoresSafeArea()

                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2)
                        }
                        .padding()
                    }
                    Spacer()
                    Button("Tag product") {
                        showProductSearch = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
                    .background(Color.black.opacity(0.6))
                }
            }
            .navigationDestination(item: $selectedItemForDetail) { item in
                ItemDetailView(item: item, authService: authService)
            }
        }
        .onAppear {
            tags = initialTags
            persistTags()
            loadResolvedItems()
        }
        .onChange(of: tags) { _, _ in persistTags() }
        .sheet(isPresented: $showProductSearch) {
            ProductSearchSheet(
                productService: productService,
                onSelect: { item in
                    let tag = LookbookTagData(productId: item.productId ?? "", x: Double(dotPosition.x), y: Double(dotPosition.y))
                    tags.append(tag)
                    resolvedItems[item.productId ?? ""] = item
                    showProductSearch = false
                },
                onCancel: { showProductSearch = false }
            )
        }
    }

    @ViewBuilder
    private func imageContent(geo: GeometryProxy) -> some View {
        if let img = image {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .background(
                    GeometryReader { inner in
                        Color.clear.preference(
                            key: ImageFramePreferenceKey.self,
                            value: inner.frame(in: .named("lookbookContainer"))
                        )
                    }
                )
        } else if let url = imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(
                            GeometryReader { inner in
                                Color.clear.preference(
                                    key: ImageFramePreferenceKey.self,
                                    value: inner.frame(in: .named("lookbookContainer"))
                                )
                            }
                        )
                case .failure:
                    Text("Failed to load image").foregroundColor(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Color.gray
        }
    }

    private func lookbookTagBadge(tag: LookbookTagData, item: Item, imageFrame: CGRect, onMove: @escaping (Double, Double) -> Void) -> some View {
        let pointerSize: CGFloat = 24
        let thumbSize: CGFloat = 32
        let cardWidth: CGFloat = 100
        let spacing: CGFloat = 6
        let totalWidth = pointerSize + spacing + cardWidth
        return Button(action: { selectedItemForDetail = item }) {
            HStack(alignment: .center, spacing: spacing) {
                Circle()
                    .fill(Color.orange.opacity(0.9))
                    .frame(width: pointerSize, height: pointerSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                HStack(spacing: 6) {
                    Group {
                        if let urlString = item.imageURLs.first, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                case .failure, .empty:
                                    Rectangle()
                                        .fill(Theme.Colors.secondaryBackground)
                                        .overlay(Image(systemName: "photo").font(.caption2).foregroundColor(Theme.Colors.secondaryText))
                                @unknown default: EmptyView()
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Theme.Colors.secondaryBackground)
                                .overlay(Image(systemName: "photo").font(.caption2).foregroundColor(Theme.Colors.secondaryText))
                        }
                    }
                    .frame(width: thumbSize, height: thumbSize)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text(item.brand ?? item.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.75))
                .cornerRadius(8)
                .frame(width: cardWidth, alignment: .leading)
            }
            .frame(width: totalWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
        .position(x: imageFrame.minX + imageFrame.width * tag.x - pointerSize / 2 + totalWidth / 2, y: imageFrame.minY + imageFrame.height * tag.y)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(coordinateSpace: .named("lookbookContainer"))
                .onEnded { value in
                    let nx = (value.location.x - imageFrame.minX) / imageFrame.width
                    let ny = (value.location.y - imageFrame.minY) / imageFrame.height
                    let clampedX = min(1, max(0, nx))
                    let clampedY = min(1, max(0, ny))
                    onMove(clampedX, clampedY)
                }
        )
    }

    private func updateTagPosition(tag: LookbookTagData, newX: Double, newY: Double) {
        guard let idx = tags.firstIndex(where: { $0.productId == tag.productId && $0.x == tag.x && $0.y == tag.y }) else { return }
        tags[idx] = LookbookTagData(productId: tag.productId, x: newX, y: newY)
    }

    private func draggableDot(geo: GeometryProxy) -> some View {
        let px = imageFrame.minX + imageFrame.width * dotPosition.x
        let py = imageFrame.minY + imageFrame.height * dotPosition.y
        return Circle()
            .fill(Color.orange)
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .position(x: px, y: py)
            .gesture(
                DragGesture(coordinateSpace: .named("lookbookContainer"))
                    .onChanged { value in
                        let nx = (value.location.x - imageFrame.minX) / imageFrame.width
                        let ny = (value.location.y - imageFrame.minY) / imageFrame.height
                        dotPosition.x = min(1, max(0, nx))
                        dotPosition.y = min(1, max(0, ny))
                    }
            )
    }

    private func persistTags() {
        LookbookUploadStore.saveTags(imageId: imageId, tags: tags)
        if var record = LookbookUploadStore.loadCurrent(), record.id == imageId {
            record.tags = tags
            LookbookUploadStore.saveCurrent(record: record)
        }
    }

    @MainActor
    private func loadResolvedItems() {
        Task {
            for tag in tags {
                guard let id = Int(tag.productId), resolvedItems[tag.productId] == nil else { continue }
                if let item = try? await productService.getProduct(id: id) {
                    resolvedItems[tag.productId] = item
                }
            }
        }
    }
}

// MARK: - Product search sheet

struct ProductSearchSheet: View {
    let productService: ProductService
    let onSelect: (Item) -> Void
    let onCancel: () -> Void

    @State private var query: String = ""
    @State private var results: [Item] = []
    @State private var searching = false

    var body: some View {
        NavigationStack {
            List {
                TextField("Search products", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { runSearch() }

                if searching {
                    HStack {
                        ProgressView()
                        Text("Searching…")
                    }
                }

                if !searching && results.isEmpty {
                    emptyStatePlaceholder
                }

                ForEach(results) { item in
                    Button(action: { onSelect(item) }) {
                        HStack(spacing: Theme.Spacing.md) {
                            if let urlString = item.imageURLs.first, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Theme.Colors.secondaryBackground)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Text(item.formattedPrice)
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Tag product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear { runSearch() }
            .onChange(of: query) { _, _ in runSearch() }
        }
    }

    private var emptyStatePlaceholder: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "tag")
                .font(.system(size: 44))
                .foregroundColor(Theme.Colors.secondaryText)
            Text(query.trimmingCharacters(in: .whitespaces).isEmpty ? "Search for products to tag" : "No products found")
                .font(.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Try a different search term")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.secondaryText.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func runSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        searching = true
        Task {
            do {
                let items = try await productService.searchProducts(query: query, pageCount: 20)
                await MainActor.run {
                    results = items
                    searching = false
                }
            } catch {
                await MainActor.run {
                    results = []
                    searching = false
                }
            }
        }
    }
}

#if DEBUG
struct LookbooksUploadView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LookbooksUploadView()
                .environmentObject(AuthService())
        }
    }
}
#endif
