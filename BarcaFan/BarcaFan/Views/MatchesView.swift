import SwiftUI

struct MatchesView: View {
    @Environment(KitThemeStore.self) private var themeStore
    @Environment(MatchesViewModel.self) private var matchesModel

    var body: some View {
        let palette = themeStore.current.palette
        NavigationStack {
            List {
                if matchesModel.isLoading, matchesModel.upcoming.isEmpty, matchesModel.recent.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(palette.accent)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }

                if let err = matchesModel.errorMessage {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(palette.card.opacity(0.45))
                }

                if !matchesModel.upcoming.isEmpty {
                    Section("Up next") {
                        ForEach(matchesModel.upcoming) { fx in
                            MatchFixtureRow(fixture: fx, palette: palette)
                        }
                    }
                }

                if !matchesModel.recent.isEmpty {
                    Section("Recent results") {
                        ForEach(matchesModel.recent) { fx in
                            MatchFixtureRow(fixture: fx, palette: palette)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data source")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(
                            "Schedules and scores come from the public openfootball La Liga JSON (2025/26). Swap in API-Football or your Firebase worker when you’re ready for live lineups and push alerts."
                        )
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        Link("openfootball/football.json", destination: URL(string: "https://github.com/openfootball/football.json")!)
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(palette.card.opacity(0.35))
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Matches")
            .refreshable {
                await matchesModel.refresh()
            }
            .task {
                if matchesModel.upcoming.isEmpty, matchesModel.recent.isEmpty, !matchesModel.isLoading {
                    await matchesModel.refresh()
                }
            }
        }
        .tint(palette.accent)
    }
}

private struct MatchFixtureRow: View {
    let fixture: MatchFixture
    let palette: ThemePalette

    private static let kickoffFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fixture.roundName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.accent)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fixture.homeTeam)
                        .font(.body.weight(fixture.isBarcelonaHome ? .semibold : .regular))
                    Text(fixture.awayTeam)
                        .font(.body.weight(fixture.isBarcelonaHome ? .regular : .semibold))
                }
                Spacer(minLength: 8)
                if let line = fixture.scoreLine {
                    Text(line)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                } else {
                    Text(Self.kickoffFormat.string(from: fixture.kickoff))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(palette.card.opacity(0.5))
    }
}
