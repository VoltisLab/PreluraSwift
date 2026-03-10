import SwiftUI
import PhotosUI

/// Feed search field with AI-style parsing and optional image/colour attachment.
/// - Parses query for colours (with typos + alias mapping) and categories.
/// - User can attach an image; dominant colour is detected and used as a colour filter.
struct FeedSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var placeholder: String = "Search items, brands or colours"
    var onSubmit: ((ParsedSearch) -> Void)?
    var topPadding: CGFloat? = nil

    /// When user attaches an image we detect colour and set this (e.g. "Green"); shown as chip and included in search.
    @State private var colourFromImage: String?
    @State private var attachedPhoto: PhotosPickerItem?
    @State private var loadedImage: UIImage?
    @State private var isDetectingColor = false

    private let cornerRadius: CGFloat = 30
    private let aiSearch = AISearchService()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.secondaryText)

                TextField(placeholder, text: $text)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .focused($isFocused)
                    .onSubmit {
                        performSearch()
                    }

                // Colour-from-image chip
                if let colour = colourFromImage {
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(sampleColorForFeed(name: colour))
                            .frame(width: 20, height: 20)
                            .overlay(Circle().strokeBorder(Theme.Colors.glassBorder, lineWidth: 1))
                        Text(colour)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryText)
                        Button(action: {
                            colourFromImage = nil
                            loadedImage = nil
                            attachedPhoto = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        .buttonStyle(HapticTapButtonStyle())
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.secondaryBackground.opacity(0.8))
                    .cornerRadius(20)
                }

                // Attach image for colour search
                PhotosPicker(
                    selection: $attachedPhoto,
                    matching: .images
                ) {
                    if isDetectingColor {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Theme.Colors.secondaryText)
                            .frame(width: 32, height: 32)
                    }
                }
                .buttonStyle(HapticTapButtonStyle())
                .onChange(of: attachedPhoto) { _, newItem in
                    loadImageAndDetectColor(from: newItem)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isFocused ? Theme.primaryColor : Color.clear, lineWidth: 2)
            )
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, topPadding ?? Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xs)
        }
    }

    private func loadImageAndDetectColor(from item: PhotosPickerItem?) {
        guard let item = item else {
            colourFromImage = nil
            loadedImage = nil
            return
        }
        isDetectingColor = true
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        loadedImage = uiImage
                        if let name = ImageColorDetection.nearestAppColour(from: uiImage) {
                            colourFromImage = name
                        }
                        isDetectingColor = false
                    }
                } else {
                    await MainActor.run { isDetectingColor = false }
                }
            } catch {
                await MainActor.run { isDetectingColor = false }
            }
        }
    }

    /// Build full query from text + colour from image, parse with AI, and submit.
    private func performSearch() {
        var query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let c = colourFromImage, !c.isEmpty, !query.localizedCaseInsensitiveContains(c) {
            query = query.isEmpty ? c : "\(query) \(c)"
        }
        let parsed = aiSearch.parse(query: query)
        var finalParsed = parsed
        if let c = colourFromImage, !parsed.appliedColourNames.contains(c) {
            finalParsed = ParsedSearch(
                searchText: [parsed.searchText, c].filter { !$0.isEmpty }.joined(separator: " "),
                categoryOverride: parsed.categoryOverride,
                appliedColourNames: parsed.appliedColourNames + [c],
                closestMatchHint: parsed.closestMatchHint
            )
        }
        onSubmit?(finalParsed)
    }
}

// Use ColoursSelectionView.sampleColor from Sell - we need it in a shared place or duplicate minimal mapping here.
private func sampleColorForFeed(name: String) -> Color {
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
