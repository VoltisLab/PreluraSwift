import SwiftUI

struct Theme {
    // Primary Color (same in light and dark)
    static let primaryColor = Color(hex: "AB28B2")

    /// Resolved scheme for the app (set from AppearanceRoot; used for glass colors).
    static var effectiveColorScheme: ColorScheme = .dark

    // Adaptive Colors (UIKit semantic colors follow system; glass colors use effectiveColorScheme)
    struct Colors {
        // Background colors
        static var background: Color {
            Color(uiColor: UIColor.systemBackground)
        }

        static var secondaryBackground: Color {
            Color(uiColor: UIColor.secondarySystemBackground)
        }

        static var tertiaryBackground: Color {
            Color(uiColor: UIColor.tertiarySystemBackground)
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
    }
    
    // Glassmorphism Constants (menu container corner radius reduced by 40% from 18)
    struct Glass {
        static let blurRadius: CGFloat = 20
        static let opacity: Double = 0.8
        static let borderWidth: CGFloat = 1
        static let cornerRadius: CGFloat = 10.8
        /// Corner radius for category/tag pills (unchanged by menu container reduction; keep pill-shaped)
        static let tagCornerRadius: CGFloat = 20
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

    /// Standard app bar / custom header layout so top-level icons and back buttons stay in the same position.
    struct AppBar {
        static let horizontalPadding: CGFloat = Spacing.md
        static let verticalPadding: CGFloat = Spacing.sm
        static let buttonSize: CGFloat = 44
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
