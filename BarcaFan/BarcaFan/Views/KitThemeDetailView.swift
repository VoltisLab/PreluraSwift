import SwiftUI

struct KitThemeDetailView: View {
    let kit: KitTheme
    @Environment(KitThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss

    private var info: KitThemeInfo { KitThemeCatalog.info(for: kit) }
    private var palette: ThemePalette { kit.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                KitThemeBannerView(kit: kit)

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(kit.displayName)
                            .font(.title.weight(.bold))
                        HStack(spacing: 8) {
                            Text(info.seasonLong)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.accent)
                            Text("(\(info.seasonShort))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(info.tagline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Why this kit is special")
                        .font(.headline)
                    Text(info.whySpecial)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text("Spotlight squad")
                        .font(.headline)
                    Text("A few names strongly associated with this era - highlights only, not a full roster.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                        ForEach(info.spotlightPlayers, id: \.self) { name in
                            Text(name)
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(palette.card.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(palette.accent.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    Button {
                        themeStore.current = kit
                        dismiss()
                    } label: {
                        Label("Use this theme", systemImage: "paintbrush.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle("Kit story")
        .navigationBarTitleDisplayMode(.inline)
    }
}
