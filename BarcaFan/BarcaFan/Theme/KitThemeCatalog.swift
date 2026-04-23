import Foundation

/// Editorial kit “season” notes: inspired by real eras; squads are highlight lists, not full registers.
struct KitThemeInfo: Sendable {
    /// Compact label for list rows, e.g. `10/11`.
    let seasonShort: String
    /// Human-readable span, e.g. `2010-11`.
    let seasonLong: String
    let tagline: String
    let whySpecial: String
    let spotlightPlayers: [String]
}

enum KitThemeCatalog {
    static func info(for kit: KitTheme) -> KitThemeInfo {
        switch kit {
        case .blaugranaClassic:
            return KitThemeInfo(
                seasonShort: "10/11",
                seasonLong: "2010-11",
                tagline: "Camp Nou lights, deep blue & garnet.",
                whySpecial: "This palette echoes the razor-sharp home strip from Pep Guardiola’s last great cycle: tight vertical blaugrana, gold trim energy, and floodlit European nights. It’s the look most fans picture when they hear “tiki-taka Barcelona.”",
                spotlightPlayers: [
                    "Lionel Messi", "Xavi Hernández", "Andrés Iniesta", "David Villa",
                    "Carles Puyol", "Dani Alves", "Gerard Piqué", "Sergio Busquets", "Pedro Rodríguez", "Víctor Valdés",
                ]
            )
        case .senyeraCatalan:
            return KitThemeInfo(
                seasonShort: "13/14",
                seasonLong: "2013-14",
                tagline: "Senyera energy with blaugrana anchors.",
                whySpecial: "Catalan identity on the chest: senyera reds and golds paired with deep blau anchors. That season’s story was swagger in La Liga and a Champions League quarter-final edge that felt personal to the city.",
                spotlightPlayers: [
                    "Lionel Messi", "Neymar Jr.", "Alexis Sánchez", "Cesc Fàbregas",
                    "Andrés Iniesta", "Xavi Hernández", "Sergio Busquets", "Javier Mascherano", "Marc Bartra", "Marc-André ter Stegen",
                ]
            )
        case .dreamTeamOrange:
            return KitThemeInfo(
                seasonShort: "91/92",
                seasonLong: "1991-92",
                tagline: "Cruyff-era citrus burst.",
                whySpecial: "The citrus away shirt is shorthand for the Dream Team: Wembley ’92, Koeman’s free-kick, and Cruyff’s philosophy made cloth. Orange reads bold on TV and in memory - never shy, always Barça.",
                spotlightPlayers: [
                    "Hristo Stoichkov", "Michael Laudrup", "Ronald Koeman", "José Mari Bakero",
                    "Pep Guardiola", "Eusebio Sacristán", "Andoni Zubizarreta", "Txiki Begiristain", "Jon Andoni Goikoetxea", "Miguel Ángel Nadal",
                ]
            )
        case .tealPeacockAway:
            return KitThemeInfo(
                seasonShort: "16/17",
                seasonLong: "2016-17",
                tagline: "Iridescent away-night tones.",
                whySpecial: "Teal-to-midnight gradients mirrored MSN-era away nights: glossy, modern, slightly audacious. Under lights the fabric seemed to shift color - perfect for a team that loved turning stadiums into stages.",
                spotlightPlayers: [
                    "Lionel Messi", "Luis Suárez", "Neymar Jr.", "Andrés Iniesta", "Sergio Busquets",
                    "Gerard Piqué", "Javier Mascherano", "Ivan Rakitić", "Marc-André ter Stegen", "Samuel Umtiti",
                ]
            )
        case .mintCoastalThird:
            return KitThemeInfo(
                seasonShort: "23/24",
                seasonLong: "2023-24",
                tagline: "Mediterranean breeze third kits.",
                whySpecial: "Mint channels the coast: open training sessions, humid evening kickoffs, and a third shirt that felt like a breath between two heavyweights. It’s the calm accent to blaugrana noise.",
                spotlightPlayers: [
                    "Robert Lewandowski", "Pedri", "Gavi", "Frenkie de Jong", "İlkay Gündoğan",
                    "Ronald Araújo", "Jules Koundé", "Marc-André ter Stegen", "Lamine Yamal", "Ferran Torres",
                ]
            )
        case .deepNavyEuropean:
            return KitThemeInfo(
                seasonShort: "24/25",
                seasonLong: "2024-25",
                tagline: "Champions nights, navy base.",
                whySpecial: "Navy reads European: floodlights, travel legs, and a quieter base that lets garnet and gold pop. It’s the palette of late group-stage chess and knockout composure.",
                spotlightPlayers: [
                    "Lamine Yamal", "Pedri", "Gavi", "Frenkie de Jong", "Robert Lewandowski",
                    "Ronald Araújo", "Jules Koundé", "Marc-André ter Stegen", "Raphinha", "Dani Olmo",
                ]
            )
        case .crimsonSenyeraAway:
            return KitThemeInfo(
                seasonShort: "14/15",
                seasonLong: "2014-15",
                tagline: "Deep red away frames.",
                whySpecial: "Crimson away kits framed MSN’s domestic dominance: confident, loud, and unmistakably Barça even on the road. Senyera gold accents nod to the flag without quoting it literally.",
                spotlightPlayers: [
                    "Lionel Messi", "Luis Suárez", "Neymar Jr.", "Andrés Iniesta", "Sergio Busquets",
                    "Gerard Piqué", "Javier Mascherano", "Ivan Rakitić", "Claudio Bravo", "Jordi Alba",
                ]
            )
        case .goldCrestAccents:
            return KitThemeInfo(
                seasonShort: "15/16",
                seasonLong: "2015-16",
                tagline: "Trophy-room gold highlights.",
                whySpecial: "Gold trim is trophy light: domestic doubles, late winners, and the sense that every touch could decide silverware. This theme keeps gold disciplined - accent, not costume.",
                spotlightPlayers: [
                    "Lionel Messi", "Luis Suárez", "Neymar Jr.", "Andrés Iniesta", "Sergio Busquets",
                    "Gerard Piqué", "Javier Mascherano", "Ivan Rakitić", "Marc-André ter Stegen", "Sergi Roberto",
                ]
            )
        case .blackoutNightThird:
            return KitThemeInfo(
                seasonShort: "20/21",
                seasonLong: "2020-21",
                tagline: "Stealth third with electric accents.",
                whySpecial: "Blackout thirds are stealth mode: training-ground grit, empty stands for stretches, then electric cyan for hope. It’s the kit palette of a rebuild that still demanded beauty.",
                spotlightPlayers: [
                    "Lionel Messi", "Ansu Fati", "Pedri", "Frenkie de Jong", "Antoine Griezmann",
                    "Ousmane Dembélé", "Sergio Busquets", "Gerard Piqué", "Marc-André ter Stegen", "Ronald Araújo",
                ]
            )
        case .softRoseSenyera:
            return KitThemeInfo(
                seasonShort: "24/25",
                seasonLong: "2024-25",
                tagline: "Rose quartz + senyera gold.",
                whySpecial: "Rose and gold nod to contemporary Barça identity beyond the men’s XI alone - creative, inclusive, and proudly Catalan. Pair it when you want warmth without losing edge.",
                spotlightPlayers: [
                    "Aitana Bonmatí", "Alexia Putellas", "Salma Paralluelo", "Caroline Graham Hansen",
                    "Patri Guijarro", "Mapi León", "Sandra Paños", "Ona Batlle", "Keira Walsh", "Ewa Pajor",
                ]
            )
        }
    }
}
