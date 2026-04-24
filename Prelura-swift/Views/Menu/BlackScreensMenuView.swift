import SwiftUI

/// Debug: menu of dark background hex codes. Tapping a code opens a profile-style preview with that background.
struct BlackScreensMenuView: View {
    @State private var selectedHexForModal: String?

    /// Twenty curated dark-mode screen backgrounds (true black, OLED grays, iOS system surfaces, subtle tints).
    private static let darkScreenSamples: [(name: String, hex: String)] = [
        ("Pure black", "000000"),
        ("OLED hairline", "010101"),
        ("Deep charcoal", "050505"),
        ("Near black", "080808"),
        ("YouTube / OLED", "0F0F0F"),
        ("App default (Prelura)", "0C0C0C"),
        ("Soft black", "0A0A0A"),
        ("Graphite", "0E0E0E"),
        ("Carbon", "111111"),
        ("Material dark", "121212"),
        ("Elevated surface", "141414"),
        ("Tile", "161616"),
        ("Panel", "181818"),
        ("iOS secondary system", "1C1C1E"),
        ("iOS tertiary / grouped", "2C2C2E"),
        ("Cool blue-black", "0B0D12"),
        ("Warm brown-black", "0E0D0C"),
        ("Blue tint black", "080A10"),
        ("Green tint black", "0C100C"),
        ("Purple tint black", "100818"),
    ]

    var body: some View {
        List {
            Section {
                Text("20 curated dark backgrounds - tap the row for a quick sheet, or Profile for full layout.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            } header: {
                Text("Preview")
            }
            Section {
                ForEach(Self.darkScreenSamples, id: \.hex) { sample in
                    HStack(spacing: Theme.Spacing.md) {
                        Button {
                            selectedHexForModal = sample.hex
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: sample.hex))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sample.name)
                                        .font(Theme.Typography.body.weight(.semibold))
                                        .foregroundColor(Theme.Colors.primaryText)
                                    Text("#\(sample.hex)")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        NavigationLink(destination: BlackScreenProfileView(hex: sample.hex)) {
                            Text("Profile")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                }
            } header: {
                Text("20 variations")
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Black screens")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: Binding(
            get: { selectedHexForModal != nil },
            set: { if !$0 { selectedHexForModal = nil } }
        )) {
            if let hex = selectedHexForModal {
                BlackScreenModalSheetsPreview(hex: hex)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .wearhouseSheetContentColumnIfWide()
            }
        }
    }
}

private struct BlackScreenModalSheetsPreview: View {
    let hex: String
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Text("Modal sheet tester")
                    .font(Theme.Typography.title3)
                    .foregroundColor(.white)
                Text("Background: #\(hex)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.75))

                Button("Open medium sheet") { selectedDetent = .medium }
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.primaryColor)
                    .clipShape(Capsule())
                Button("Open large sheet") { selectedDetent = .large }
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.primaryColor.opacity(0.75))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: hex).ignoresSafeArea())
            .navigationTitle("Sheets on #\(hex)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }
}
