import SwiftUI

/// Ten Blaugrana-adjacent palettes inspired by iconic Barcelona kits (home, away, thirds, specials).
enum KitTheme: String, CaseIterable, Identifiable, Sendable {
    case blaugranaClassic
    case senyeraCatalan
    case dreamTeamOrange
    case tealPeacockAway
    case mintCoastalThird
    case deepNavyEuropean
    case crimsonSenyeraAway
    case goldCrestAccents
    case blackoutNightThird
    case softRoseSenyera

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blaugranaClassic: "Blaugrana ’11"
        case .senyeraCatalan: "Senyera stripes"
        case .dreamTeamOrange: "Dream Team orange"
        case .tealPeacockAway: "Peacock away"
        case .mintCoastalThird: "Coastal mint"
        case .deepNavyEuropean: "European navy"
        case .crimsonSenyeraAway: "Crimson Senyera"
        case .goldCrestAccents: "Crest gold"
        case .blackoutNightThird: "Night third"
        case .softRoseSenyera: "Rose Senyera"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .blaugranaClassic:
            return ThemePalette(
                primary: Color(red: 0.05, green: 0.20, blue: 0.55),
                secondary: Color(red: 0.65, green: 0.02, blue: 0.12),
                accent: Color(red: 0.95, green: 0.78, blue: 0.12),
                background: Color(red: 0.04, green: 0.06, blue: 0.12),
                card: Color(red: 0.08, green: 0.10, blue: 0.18)
            )
        case .senyeraCatalan:
            return ThemePalette(
                primary: Color(red: 0.86, green: 0.10, blue: 0.12),
                secondary: Color(red: 0.98, green: 0.78, blue: 0.10),
                accent: Color(red: 0.05, green: 0.25, blue: 0.55),
                background: Color(red: 0.07, green: 0.05, blue: 0.06),
                card: Color(red: 0.14, green: 0.09, blue: 0.10)
            )
        case .dreamTeamOrange:
            return ThemePalette(
                primary: Color(red: 0.96, green: 0.42, blue: 0.08),
                secondary: Color(red: 0.05, green: 0.18, blue: 0.48),
                accent: Color(red: 0.98, green: 0.86, blue: 0.20),
                background: Color(red: 0.08, green: 0.04, blue: 0.02),
                card: Color(red: 0.16, green: 0.09, blue: 0.05)
            )
        case .tealPeacockAway:
            return ThemePalette(
                primary: Color(red: 0.05, green: 0.52, blue: 0.55),
                secondary: Color(red: 0.10, green: 0.12, blue: 0.22),
                accent: Color(red: 0.55, green: 0.90, blue: 0.82),
                background: Color(red: 0.03, green: 0.07, blue: 0.10),
                card: Color(red: 0.06, green: 0.12, blue: 0.16)
            )
        case .mintCoastalThird:
            return ThemePalette(
                primary: Color(red: 0.55, green: 0.86, blue: 0.74),
                secondary: Color(red: 0.05, green: 0.22, blue: 0.42),
                accent: Color(red: 0.95, green: 0.70, blue: 0.20),
                background: Color(red: 0.03, green: 0.08, blue: 0.10),
                card: Color(red: 0.07, green: 0.14, blue: 0.16)
            )
        case .deepNavyEuropean:
            return ThemePalette(
                primary: Color(red: 0.04, green: 0.12, blue: 0.32),
                secondary: Color(red: 0.75, green: 0.08, blue: 0.16),
                accent: Color(red: 0.75, green: 0.82, blue: 0.95),
                background: Color(red: 0.02, green: 0.03, blue: 0.08),
                card: Color(red: 0.06, green: 0.08, blue: 0.14)
            )
        case .crimsonSenyeraAway:
            return ThemePalette(
                primary: Color(red: 0.62, green: 0.05, blue: 0.14),
                secondary: Color(red: 0.96, green: 0.78, blue: 0.12),
                accent: Color(red: 0.12, green: 0.32, blue: 0.62),
                background: Color(red: 0.07, green: 0.02, blue: 0.04),
                card: Color(red: 0.14, green: 0.05, blue: 0.08)
            )
        case .goldCrestAccents:
            return ThemePalette(
                primary: Color(red: 0.86, green: 0.66, blue: 0.18),
                secondary: Color(red: 0.05, green: 0.18, blue: 0.48),
                accent: Color(red: 0.96, green: 0.92, blue: 0.78),
                background: Color(red: 0.05, green: 0.04, blue: 0.02),
                card: Color(red: 0.12, green: 0.10, blue: 0.06)
            )
        case .blackoutNightThird:
            return ThemePalette(
                primary: Color(red: 0.10, green: 0.10, blue: 0.12),
                secondary: Color(red: 0.72, green: 0.05, blue: 0.14),
                accent: Color(red: 0.35, green: 0.78, blue: 0.95),
                background: Color(red: 0.02, green: 0.02, blue: 0.03),
                card: Color(red: 0.08, green: 0.08, blue: 0.10)
            )
        case .softRoseSenyera:
            return ThemePalette(
                primary: Color(red: 0.86, green: 0.45, blue: 0.55),
                secondary: Color(red: 0.05, green: 0.22, blue: 0.48),
                accent: Color(red: 0.98, green: 0.82, blue: 0.28),
                background: Color(red: 0.07, green: 0.04, blue: 0.06),
                card: Color(red: 0.14, green: 0.08, blue: 0.10)
            )
        }
    }
}

struct ThemePalette: Sendable {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let card: Color
}

@Observable
final class KitThemeStore {
    var current: KitTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey) }
    }

    /// Decorative kit patterns behind tabs (stripes, grids, etc.). Off = gradient only.
    var showBackgroundPatterns: Bool {
        didSet { UserDefaults.standard.set(showBackgroundPatterns, forKey: Self.patternsKey) }
    }

    private static let storageKey = "barcafan.kitTheme"
    private static let patternsKey = "barcafan.showBackgroundPatterns"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.current = KitTheme(rawValue: raw ?? KitTheme.blaugranaClassic.rawValue) ?? .blaugranaClassic
        if UserDefaults.standard.object(forKey: Self.patternsKey) == nil {
            self.showBackgroundPatterns = true
        } else {
            self.showBackgroundPatterns = UserDefaults.standard.bool(forKey: Self.patternsKey)
        }
    }
}
