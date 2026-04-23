import SwiftUI

struct Theme {
    // Primary Color (same in light and dark)
    static let primaryColor = Color(hex: "AB28B2")

    /// Resolved scheme for the app (set from AppearanceRoot; used for glass colors).
    static var effectiveColorScheme: ColorScheme = .dark

    // Adaptive Colors (UIKit semantic colors follow system; glass colors use effectiveColorScheme)
    struct Colors {
        // Background colors (dark mode uses #0C0C0C for normal screens)
        static var background: Color {
            effectiveColorScheme == .dark ? Color(hex: "0C0C0C") : Color(uiColor: UIColor.systemBackground)
        }

        /// Dedicated modal sheet surface in dark mode (comments, sort/filter sheets; aligns with menu card grey).
        static var modalSheetBackground: Color {
            effectiveColorScheme == .dark ? Color(hex: "1C1C1E") : Color(uiColor: UIColor.systemBackground)
        }

        static var secondaryBackground: Color {
            Color(uiColor: UIColor.secondarySystemBackground)
        }

        static var tertiaryBackground: Color {
            Color(uiColor: UIColor.tertiarySystemBackground)
        }

        /// Inline cards on the chat thread (e.g. order-issue banner): dark mode sits just above `background` (#0C0C0C) so it is barely distinct; light mode matches grouped surfaces.
        static var chatInlineCardBackground: Color {
            effectiveColorScheme == .dark ? Color(hex: "111111") : Color(uiColor: UIColor.secondarySystemBackground)
        }

        // Text colors
        static var primaryText: Color {
            Color(uiColor: UIColor.label)
        }

        static var secondaryText: Color {
            Color(uiColor: UIColor.secondaryLabel)
        }

        static var tertiaryText: Color {
            Color(uiColor: UIColor.tertiaryLabel)
        }

        /// Text over video on auth screens (login/signup): always light for readability in both light and dark mode.
        static var authOverVideoText: Color {
            Color.white.opacity(0.95)
        }

        /// Error/destructive text and controls
        static var error: Color {
            Color(uiColor: .systemRed)
        }

        // Glass effect colors (light mode: dark tint; dark mode: light tint)
        static var glassBackground: Color {
            effectiveColorScheme == .dark
                ? Color.white.opacity(0.1)
                : Color.black.opacity(0.06)
        }

        static var glassBorder: Color {
            effectiveColorScheme == .dark
                ? Color.white.opacity(0.2)
                : Color.black.opacity(0.12)
        }

        /// Ring border around profile image (visible in light and dark mode).
        static var profileRingBorder: Color {
            effectiveColorScheme == .dark
                ? Color.white.opacity(0.35)
                : Color.black.opacity(0.2)
        }

        /// Hairline stroke for circular list avatars (messages, notifications); follows system separator in light/dark.
        static var avatarHairlineBorder: Color {
            Color(uiColor: UIColor.separator)
        }
    }
    
    // Glassmorphism Constants (menu container corner radius reduced by 40% from 18)
    struct Glass {
        static let blurRadius: CGFloat = 20
        static let opacity: Double = 0.8
        static let borderWidth: CGFloat = 1
        static let cornerRadius: CGFloat = 10.8
        /// Corner radius for menu-style containers and cards (e.g. Help with Order, profile menu popover)
        static let menuContainerCornerRadius: CGFloat = 12
        /// Corner radius for category/tag pills (unchanged by menu container reduction; keep pill-shaped)
        static let tagCornerRadius: CGFloat = 20
        /// Multiline description editors in order-issue flows and secondary list/order row cards (My orders, bag lines, payment rows).
        static let descriptionFieldCornerRadius: CGFloat = 30
        /// Same continuous corner as description fields: dashboard KPI tiles, analytics cards, feed error banner, sheet search bars, delivery option cards.
        static var bannerSurfaceCornerRadius: CGFloat { descriptionFieldCornerRadius }
        static let shadowRadius: CGFloat = 10
        static let shadowOpacity: Double = 0.1
    }
    
    // Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    /// Padding inside `TextField` / `TextEditor` backgrounds so the caret and text do not sit flush on rounded borders (SwiftUI defaults are tight).
    struct TextInput {
        static let insetHorizontal: CGFloat = Spacing.md + 8
        static let insetVertical: CGFloat = Spacing.md
        static let insetVerticalCompact: CGFloat = Spacing.sm + 6
    }

    /// Default search field chrome: matches the system navigation-bar search drawer (compact continuous corners, secondary background, caret-only focus — no thick accent ring).
    struct SearchField {
        static let cornerRadius: CGFloat = 12
        static let singleLineHeight: CGFloat = 44
        static let iconPointSize: CGFloat = 16
        /// Matches the sparkles control footprint so screens without `onAITap` still mirror Home layout (~min tap target).
        static let trailingActionSlotWidth: CGFloat = 44
        static let trailingActionSlotHeight: CGFloat = 44
    }

    /// Standard app bar / custom header layout so top-level icons and back buttons stay in the same position.
    struct AppBar {
        static let horizontalPadding: CGFloat = Spacing.md
        static let verticalPadding: CGFloat = Spacing.sm
        static let buttonSize: CGFloat = 52
    }
    
    // Typography
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 13, weight: .regular, design: .default)
    }

    /// Product colour names to SwiftUI Color (matches Flutter colorsProvider for detail colour integration).
    static func productColor(for name: String) -> Color? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch key.lowercased() {
        case "black": return .black
        case "brown": return .brown
        case "grey", "gray": return .gray
        case "white": return .white
        case "beige": return Color(hex: "F5F5DC")
        case "pink": return .pink
        case "purple": return .purple
        case "red": return .red
        case "yellow": return .yellow
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "tan": return Color(hex: "D2B48C")
        case "silver": return Color(hex: "C0C0C0")
        case "gold": return Color(hex: "D4AF37")
        case "navy": return Color(hex: "000080")
        default: return nil
        }
    }
}

extension View {
    /// 1pt border on circular avatars; apply after `clipShape(Circle())` or on a fixed square circular avatar.
    func circularAvatarHairlineBorder(lineWidth: CGFloat = 1) -> some View {
        overlay {
            Circle().stroke(Theme.Colors.avatarHairlineBorder, lineWidth: lineWidth)
        }
    }

    /// System-style search that uses the navigation bar drawer and moves into the nav bar when focused (`displayMode: .always` shows the field inline first).
    func appStandardSearchable(text: Binding<String>, prompt: Text) -> some View {
        searchable(
            text: text,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: prompt
        )
    }

    /// Home / Discover (and similar feeds): solid bar at rest, **automatic** visibility so the bar can soften as content scrolls under it (matches Profile / default stacks). Avoid `.visible`, which pins the bar and creates a sharp seam with `.searchable(.navigationBarDrawer)` above a white `ScrollView`.
    func preluraNavigationBarChrome() -> some View {
        self
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            .toolbarColorScheme(Theme.effectiveColorScheme, for: .navigationBar)
    }
}

// Color extension for hex support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
