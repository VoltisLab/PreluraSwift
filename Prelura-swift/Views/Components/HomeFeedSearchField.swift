import SwiftUI

private enum HomeFeedSearchPlaceholderData {
    static let rotating: [String] = [
        "Women's vintage dress",
        "Men's casual jacket",
        "Kids trainers",
        "Unisex hoodie",
        "Summer sandals",
        "Brands or colours",
        "Streetwear",
        "Sustainable fashion",
    ]
}

/// Home feed search: **pill + hairline** to match Debug’s `.appStandardSearchable` look; magnifying glass + field live inside the capsule. Lenny (sparkles) sits **beside** the pill so the field shape matches Debug (no trailing icon inside the bar).
struct HomeFeedSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var onSubmit: ((ParsedSearch) -> Void)?
    var onAITap: (() -> Void)?
    var topPadding: CGFloat? = nil
    /// When set (e.g. Help Centre), replaces the home product placeholder carousel. Same fade animation and sizing; first line is the lead hint, remaining lines shuffle into the rotation.
    var placeholderCarousel: [String]? = nil

    @State private var placeholderIndex: Int = 0
    @State private var placeholderOpacity: Double = 1
    @State private var cycleTimer: Timer?
    @State private var placeholders: [String] = []

    private let aiSearch = AISearchService()

    var body: some View {
        let pill = Capsule(style: .continuous)
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: Theme.SearchField.iconPointSize, weight: .medium))
                    .foregroundStyle(Theme.Colors.secondaryText)

                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(currentPlaceholder)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .opacity(placeholderOpacity)
                    }
                    TextField("", text: $text)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.primaryText)
                        .focused($isFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            let parsed = aiSearch.parse(query: text.trimmingCharacters(in: .whitespacesAndNewlines))
                            onSubmit?(parsed)
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(pill)
            .overlay {
                pill.strokeBorder(Theme.Colors.glassBorder.opacity(0.65), lineWidth: 0.5)
            }

            if let onAITap = onAITap {
                Button(action: onAITap) {
                    Image(systemName: "sparkles")
                        .font(.system(size: Theme.SearchField.iconPointSize, weight: .medium))
                        .foregroundStyle(Theme.primaryColor)
                        .frame(width: Theme.SearchField.trailingActionSlotWidth, height: Theme.SearchField.trailingActionSlotHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HapticTapButtonStyle())
                .accessibilityLabel(L10n.string("AI"))
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, topPadding ?? Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
        .onAppear {
            if placeholders.isEmpty {
                if let carousel = placeholderCarousel, !carousel.isEmpty {
                    let tail = Array(carousel.dropFirst())
                    placeholders = [carousel[0]] + (tail.isEmpty ? [] : tail.shuffled())
                } else {
                    placeholders = [L10n.string("Search items, brands or styles")] + HomeFeedSearchPlaceholderData.rotating.shuffled()
                }
            }
            startPlaceholderCycle()
        }
        .onDisappear {
            cycleTimer?.invalidate()
            cycleTimer = nil
        }
    }

    private var currentPlaceholder: String {
        if placeholders.isEmpty { return L10n.string("Search items, brands or styles") }
        return placeholders[placeholderIndex % placeholders.count]
    }

    private func startPlaceholderCycle() {
        cycleTimer?.invalidate()
        guard placeholders.count > 1 else { return }
        cycleTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    placeholderOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    placeholderIndex = (placeholderIndex + 1) % placeholders.count
                    withAnimation(.easeIn(duration: 0.25)) {
                        placeholderOpacity = 1
                    }
                }
            }
        }
        RunLoop.main.add(cycleTimer!, forMode: .common)
    }
}

/// Collapsed Home search row: tap the pill to move editing into the navigation toolbar (system-style). Sparkles stay beside the pill.
struct HomeFeedSearchCollapsedTrigger: View {
    let searchText: String
    var onPillTap: () -> Void
    var onAITap: () -> Void
    var topPadding: CGFloat? = nil
    var placeholderCarousel: [String]? = nil

    @State private var placeholderIndex: Int = 0
    @State private var placeholderOpacity: Double = 1
    @State private var cycleTimer: Timer?
    @State private var placeholders: [String] = []

    private var trimmed: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let pill = Capsule(style: .continuous)
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Button(action: onPillTap) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: Theme.SearchField.iconPointSize, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Group {
                        if trimmed.isEmpty {
                            Text(currentPlaceholder)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.secondaryText)
                                .opacity(placeholderOpacity)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(searchText)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.primaryText)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(pill)
            .overlay {
                pill.strokeBorder(Theme.Colors.glassBorder.opacity(0.65), lineWidth: 0.5)
            }

            Button(action: onAITap) {
                Image(systemName: "sparkles")
                    .font(.system(size: Theme.SearchField.iconPointSize, weight: .medium))
                    .foregroundStyle(Theme.primaryColor)
                    .frame(width: Theme.SearchField.trailingActionSlotWidth, height: Theme.SearchField.trailingActionSlotHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HapticTapButtonStyle())
            .accessibilityLabel(L10n.string("AI"))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, topPadding ?? Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
        .accessibilityLabel(L10n.string("Search"))
        .onAppear {
            bootstrapPlaceholders()
            restartPlaceholderCycle()
        }
        .onChange(of: trimmed) { _, _ in
            restartPlaceholderCycle()
        }
        .onDisappear {
            cycleTimer?.invalidate()
            cycleTimer = nil
        }
    }

    private var currentPlaceholder: String {
        if placeholders.isEmpty { return L10n.string("Search items, brands or styles") }
        return placeholders[placeholderIndex % placeholders.count]
    }

    private func bootstrapPlaceholders() {
        guard placeholders.isEmpty else { return }
        if let carousel = placeholderCarousel, !carousel.isEmpty {
            let tail = Array(carousel.dropFirst())
            placeholders = [carousel[0]] + (tail.isEmpty ? [] : tail.shuffled())
        } else {
            placeholders = [L10n.string("Search items, brands or styles")] + HomeFeedSearchPlaceholderData.rotating.shuffled()
        }
    }

    private func restartPlaceholderCycle() {
        cycleTimer?.invalidate()
        cycleTimer = nil
        guard trimmed.isEmpty, placeholders.count > 1 else { return }
        cycleTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    placeholderOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    placeholderIndex = (placeholderIndex + 1) % placeholders.count
                    withAnimation(.easeIn(duration: 0.25)) {
                        placeholderOpacity = 1
                    }
                }
            }
        }
        RunLoop.main.add(cycleTimer!, forMode: .common)
    }
}

#Preview {
    HomeFeedSearchField(
        text: .constant(""),
        onSubmit: { _ in },
        onAITap: {},
        topPadding: Theme.Spacing.xs
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
