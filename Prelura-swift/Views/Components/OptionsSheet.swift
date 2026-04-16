import SwiftUI

/// How the sheet header dismisses and is laid out. Sort/filter use `.navigationDone` to match Lookbook **Comments** (inline nav title + system drag indicator + **Done**).
enum OptionsSheetChromeStyle {
    /// Custom capsule handle, centred title row, trailing × (`GlassIconButton`). Hides the system drag indicator.
    case handleAndClose
    /// `NavigationStack` with inline `navigationTitle` and trailing **Done** (same toolbar treatment as `LookbookCommentsSheet`). Shows the system drag indicator.
    case navigationDone
}

/// Reusable modal sheet with title and consistent presentation. Use for product options, sort, filter, and similar modals.
/// For multiple related sheets (sort / filter / search), use one `.sheet(item:)` with an `Identifiable` enum; chaining several `.sheet(isPresented:)` on the same view stacks modals when more than one binding is true.
/// Matches Sort modal: one colour (`Theme.Colors.modalSheetBackground`) for nav bar and content area.
struct OptionsSheet<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    var detents: [PresentationDetent]
    /// When false, uses system default sheet corner radius (e.g. product Options modal).
    var useCustomCornerRadius: Bool = true
    /// When true (default), a bottom `Spacer` fills the sheet so content stays at the top under `.fraction` detents. Set false with a tight `.height` detent so the sheet only wraps the header + rows (e.g. product Options).
    var fillsAvailableVerticalSpace: Bool = true
    var chromeStyle: OptionsSheetChromeStyle = .handleAndClose
    @ViewBuilder let content: () -> Content

    @State private var selectedDetent: PresentationDetent

    private var sheetBackground: Color { Theme.Colors.modalSheetBackground }

    init(
        title: String,
        onDismiss: @escaping () -> Void,
        /// Slightly above half-height so header + list are not cramped; user can still drag to `.large`.
        detents: [PresentationDetent] = [.fraction(0.58), .large],
        useCustomCornerRadius: Bool = true,
        fillsAvailableVerticalSpace: Bool = true,
        chromeStyle: OptionsSheetChromeStyle = .handleAndClose,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onDismiss = onDismiss
        self.detents = detents
        self.useCustomCornerRadius = useCustomCornerRadius
        self.fillsAvailableVerticalSpace = fillsAvailableVerticalSpace
        self.chromeStyle = chromeStyle
        self.content = content
        _selectedDetent = State(initialValue: detents.first ?? .fraction(0.58))
    }

    var body: some View {
        chromeRoot
            .background(sheetBackground)
            .presentationDetents(Set(detents), selection: $selectedDetent)
            .presentationDragIndicator(chromeStyle == .navigationDone ? .visible : .hidden)
            .presentationBackground(sheetBackground)
            .modifier(SheetCornerRadiusModifier(apply: useCustomCornerRadius))
    }

    @ViewBuilder
    private var chromeRoot: some View {
        switch chromeStyle {
        case .handleAndClose:
            handleAndCloseLayout
        case .navigationDone:
            navigationDoneLayout
        }
    }

    private var handleAndCloseLayout: some View {
        VStack(spacing: 0) {
            // Custom handle: avoids overlap with a centred title when using the system drag indicator
            // (fixed detents + `presentationBackground` often crowd the stock indicator into the header row).
            Capsule()
                .fill(Theme.Colors.secondaryText.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)

            HStack {
                Spacer()
                Text(title)
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                GlassIconButton(
                    icon: "xmark",
                    size: 36,
                    iconColor: Theme.Colors.primaryText,
                    iconSize: 15,
                    action: onDismiss
                )
                .padding(.trailing, Theme.Spacing.md)
            }
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.md)
            .layoutPriority(1)

            content()
                .frame(maxWidth: .infinity, alignment: .top)
                .layoutPriority(0)

            if fillsAvailableVerticalSpace {
                Spacer(minLength: 0)
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    /// Matches `LookbookCommentsSheet`: inline title, toolbar **Done** with primary tint (system glass / press animation on supported OS).
    private var navigationDoneLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content()
                    .frame(maxWidth: .infinity, alignment: .top)
                if fillsAvailableVerticalSpace {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(sheetBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(sheetBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done"), action: onDismiss)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.primaryColor)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Applies presentation corner radius when available (iOS 16.4+). When apply is false, leaves system default (e.g. product Options sheet).
private struct SheetCornerRadiusModifier: ViewModifier {
    var apply: Bool = true
    func body(content: Content) -> some View {
        if apply, #available(iOS 16.4, *) {
            content.presentationCornerRadius(20)
        } else {
            content
        }
    }
}
