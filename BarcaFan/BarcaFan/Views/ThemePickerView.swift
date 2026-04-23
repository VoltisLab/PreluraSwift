import SwiftUI

struct ThemePickerView: View {
    @Environment(KitThemeStore.self) private var themeStore

    var body: some View {
        let palette = themeStore.current.palette
        NavigationStack {
            List {
                Section {
                    Toggle(
                        "Background patterns",
                        isOn: Binding(
                            get: { themeStore.showBackgroundPatterns },
                            set: { themeStore.showBackgroundPatterns = $0 }
                        )
                    )
                    Text("Each kit uses a different texture behind the tabs. Turn off for a flat gradient only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Kits & specials") {
                    ForEach(KitTheme.allCases) { kit in
                        let info = KitThemeCatalog.info(for: kit)
                        NavigationLink(value: kit) {
                            HStack(alignment: .center, spacing: 14) {
                                KitJerseyIconView(kit: kit)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(kit.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(info.seasonShort)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(palette.accent)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(palette.card.opacity(0.65))
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(palette.accent.opacity(0.35), lineWidth: 1)
                                            )
                                    }
                                    Text(info.tagline)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("View more")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(palette.accent.opacity(0.85))
                                }
                                Spacer(minLength: 4)
                                if kit == themeStore.current {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(palette.accent)
                                        .imageScale(.large)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Themes")
            .navigationDestination(for: KitTheme.self) { kit in
                KitThemeDetailView(kit: kit)
            }
        }
        .tint(palette.accent)
    }
}
