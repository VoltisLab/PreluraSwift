import SwiftUI

/// Command centre: every roadmap surface, grouped by priority tier. News, Matches, and Themes stay as full tabs.
struct FeatureHubView: View {
    @Environment(KitThemeStore.self) private var themeStore

    var body: some View {
        let palette = themeStore.current.palette
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(FeatureTier.allCases.sorted(), id: \.self) { tier in
                        let items = tier.features
                        if !items.isEmpty {
                            tierSection(tier: tier, items: items, palette: palette)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Fans")
            .navigationDestination(for: FanFeature.self) { feature in
                FanFeatureWorkspaceView(feature: feature)
            }
        }
    }

    @ViewBuilder
    private func tierSection(tier: FeatureTier, items: [FanFeature], palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tier.title)
                .font(.title3.weight(.bold))
                .padding(.horizontal, 16)
            Text(tier.headline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(items) { feature in
                    NavigationLink(value: feature) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: feature.systemImage)
                                .font(.title3)
                                .foregroundStyle(palette.accent)
                                .frame(width: 36, alignment: .center)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feature.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(feature.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(palette.primary.opacity(0.12))
                }
            }
            .background(palette.card.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
}
