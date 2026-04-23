import EventKit
import SwiftUI

/// Per-feature working surfaces (MVP): local state, calendar hooks, tab jumps, and lightweight demos.
struct FanFeatureWorkspaceView: View {
    let feature: FanFeature
    @Environment(KitThemeStore.self) private var themeStore
    @Environment(AppTabRouter.self) private var tabRouter
    @Environment(MatchesViewModel.self) private var matchesModel
    @Environment(NewsFeedViewModel.self) private var newsModel

    private var palette: ThemePalette { themeStore.current.palette }

    var body: some View {
        Group {
            switch feature {
            case .liveMatchHub:
                LiveMatchHubWorkspace(palette: palette, tabRouter: tabRouter, matchesModel: matchesModel)
            case .fixturesAndResults:
                FixturesWorkspace(palette: palette, tabRouter: tabRouter, matchesModel: matchesModel)
            case .teamNewsFeed:
                TeamNewsWorkspace(palette: palette, tabRouter: tabRouter, newsModel: newsModel)
            case .squadProfiles:
                SquadProfilesWorkspace(palette: palette)
            case .matchChatRooms:
                MatchChatWorkspace(palette: palette)
            case .fanReactionsFeed:
                FanReactionsWorkspace(palette: palette)
            case .pollsAndPredictions:
                PollsWorkspace(palette: palette)
            case .fanReputation:
                ReputationWorkspace(palette: palette)
            case .aiMatchAnalyst:
                AnalystWorkspace(palette: palette)
            case .personalizedFeed:
                PersonalizedFeedWorkspace(palette: palette)
            case .voiceQA:
                VoiceQAWorkspace(palette: palette)
            case .fantasyMode:
                FantasyWorkspace(palette: palette)
            case .predictionLeagues:
                PredictionLeaguesWorkspace(palette: palette)
            case .dailyChallenges:
                DailyChallengeWorkspace(palette: palette)
            case .localFanGroups:
                LocalGroupsWorkspace(palette: palette)
            case .userProfiles:
                UserProfileWorkspace(palette: palette)
            case .clipsAndUploads:
                ClipsWorkspace(palette: palette)
            case .premiumTier:
                PremiumWorkspace(palette: palette)
            case .marketplaceMerch:
                MarketplaceWorkspace(palette: palette)
            case .eventTicketsWatchParties:
                EventsWorkspace(palette: palette)
            case .liveAudioCommentary:
                AudioCommentaryWorkspace(palette: palette)
            case .arKitTryOn:
                ARTryOnWorkspace(palette: palette)
            case .stadiumMode:
                StadiumModeWorkspace(palette: palette)
            case .transferTrackerEngine:
                TransferTrackerWorkspace(palette: palette)
            }
        }
        .navigationTitle(feature.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared chrome

private struct WorkspaceSection<Content: View>: View {
    let title: String
    let palette: ThemePalette
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(palette.card.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Core tabs

private struct LiveMatchHubWorkspace: View {
    let palette: ThemePalette
    let tabRouter: AppTabRouter
    let matchesModel: MatchesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Follow the ninety minutes with scores, lineups, and a timeline. Data below comes from the same schedule as the Matches tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                WorkspaceSection(title: "Next kickoffs", palette: palette) {
                    if matchesModel.upcoming.isEmpty {
                        Text(matchesModel.isLoading ? "Loading…" : "No upcoming fixtures loaded yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matchesModel.upcoming.prefix(5)) { fx in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(fx.homeTeam) vs \(fx.awayTeam)")
                                    .font(.subheadline.weight(.semibold))
                                Text(fx.kickoff.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Button("Open Matches tab") { tabRouter.selectedTab = 2 }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.accent)
                        .padding(.top, 6)
                }

                Button("Refresh schedule") {
                    Task { await matchesModel.refresh() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
        .task {
            if matchesModel.upcoming.isEmpty, matchesModel.recent.isEmpty, !matchesModel.isLoading {
                await matchesModel.refresh()
            }
        }
    }
}

private struct FixturesWorkspace: View {
    let palette: ThemePalette
    let tabRouter: AppTabRouter
    let matchesModel: MatchesViewModel
    @State private var calendarMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Browse kickoffs and add the next match to your calendar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                WorkspaceSection(title: "Up next", palette: palette) {
                    ForEach(matchesModel.upcoming.prefix(8)) { fx in
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(fx.homeTeam) vs \(fx.awayTeam)")
                                    .font(.subheadline.weight(.semibold))
                                Text(fx.kickoff.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button("Add") {
                                Task {
                                    calendarMessage = await FixtureCalendarWriter.add(fixture: fx)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(palette.accent)
                        }
                        .padding(.vertical, 4)
                    }
                    if matchesModel.upcoming.isEmpty {
                        Text("No fixtures yet. Pull to refresh on Matches or tap below.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let calendarMessage {
                    Text(calendarMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Open Matches tab") { tabRouter.selectedTab = 2 }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)

                Button("Reload fixtures") {
                    Task { await matchesModel.refresh() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
        .task {
            if matchesModel.upcoming.isEmpty, !matchesModel.isLoading {
                await matchesModel.refresh()
            }
        }
    }
}

private struct TeamNewsWorkspace: View {
    let palette: ThemePalette
    let tabRouter: AppTabRouter
    let newsModel: NewsFeedViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Headlines from the aggregated feed. Open the News tab for the full experience.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Open News tab") { tabRouter.selectedTab = 0 }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)

                WorkspaceSection(title: "Latest stories", palette: palette) {
                    if newsModel.stories.isEmpty {
                        Text(newsModel.isLoading ? "Loading…" : "No stories yet. Open News and pull to refresh.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(newsModel.stories.prefix(8)) { story in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(story.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(story.sourceName)
                                    .font(.caption)
                                    .foregroundStyle(palette.accent)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Button("Refresh headlines") {
                    Task { await newsModel.refresh() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
        .task {
            if newsModel.stories.isEmpty, !newsModel.isLoading {
                await newsModel.refresh()
            }
        }
    }
}

private struct SquadProfilesWorkspace: View {
    let palette: ThemePalette

    private let players: [(String, String)] = [
        ("Lamine Yamal", "Forward"), ("Raphinha", "Forward"), ("Robert Lewandowski", "Forward"),
        ("Pedri", "Midfielder"), ("Frenkie de Jong", "Midfielder"), ("Gavi", "Midfielder"),
        ("Dani Olmo", "Midfielder"), ("Fermín López", "Midfielder"), ("Marc Casadó", "Midfielder"),
        ("Ronald Araújo", "Defender"), ("Jules Koundé", "Defender"), ("Alejandro Balde", "Defender"),
        ("Iñigo Martínez", "Defender"), ("Eric García", "Defender"), ("Marc-André ter Stegen", "Goalkeeper"),
    ]

    var body: some View {
        List {
            Section {
                Text("Tap a player for a local stats card (demo data until a live API is wired in).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            Section("First team") {
                ForEach(players, id: \.0) { name, role in
                    NavigationLink {
                        PlayerCardDetailView(name: name, role: role, palette: palette)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.headline)
                            Text(role).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
    }
}

private struct PlayerCardDetailView: View {
    let name: String
    let role: String
    let palette: ThemePalette
    @State private var appearances = Int.random(in: 18 ... 32)
    @State private var goals = Int.random(in: 2 ... 18)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(name).font(.title.weight(.bold))
                Text(role).font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    statTile(title: "Apps", value: "\(appearances)", palette: palette)
                    statTile(title: "Goals", value: "\(goals)", palette: palette)
                    statTile(title: "Form", value: "B+", palette: palette)
                }
                Text("Heatmaps and injury history ship when stats are licensed. This screen proves navigation, layout, and local state.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Simulate match played") {
                    appearances += 1
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statTile(title: String, value: String, palette: ThemePalette) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.title2.weight(.bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(palette.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Fan engagement

private struct MatchChatWorkspace: View {
    let palette: ThemePalette
    @State private var draft = ""
    @State private var lines: [String] = [
        "System: Welcome to the demo room. Messages stay on this device.",
        "Culer_1999: Visca Barça!",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i])
                            .font(.footnote)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(palette.card.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding()
            }
            HStack {
                TextField("Message", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    lines.append("You: \(t)")
                    draft = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
            }
            .padding()
            .background(palette.card.opacity(0.35))
        }
        .background(palette.background.ignoresSafeArea())
    }
}

private struct FanReactionsWorkspace: View {
    let palette: ThemePalette
    @State private var likes: [String: Int] = [:]

    private let clipTitles = [
        "Goal cam: Yamal cuts inside",
        "Montjuïc crowd after the winner",
        "Training ground nutmeg (friendly)",
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(clipTitles, id: \.self) { title in
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(palette.card)
                            .frame(height: 180)
                            .overlay {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(palette.accent)
                            }
                        Text(title).font(.headline)
                        HStack {
                            let c = likes[title, default: 0]
                            Button {
                                likes[title] = c + 1
                            } label: {
                                Label("\(c) likes", systemImage: "hand.thumbsup.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(palette.accent)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(palette.card.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

private struct PollsWorkspace: View {
    let palette: ThemePalette
    @AppStorage("bf_poll_home") private var homeVotes = 42
    @AppStorage("bf_poll_draw") private var drawVotes = 18
    @AppStorage("bf_poll_away") private var awayVotes = 27

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Full-time result (demo poll)")
                    .font(.headline)
                Text("Barça vs next opponent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                pollButton(title: "Home win", count: homeVotes, palette: palette) { homeVotes += 1 }
                pollButton(title: "Draw", count: drawVotes, palette: palette) { drawVotes += 1 }
                pollButton(title: "Away win", count: awayVotes, palette: palette) { awayVotes += 1 }
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }

    private func pollButton(title: String, count: Int, palette: ThemePalette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(count)").font(.caption.monospacedDigit())
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(palette.card.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ReputationWorkspace: View {
    let palette: ThemePalette
    @AppStorage("bf_rep_xp") private var xp = 120

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your supporter XP (stored on-device for this demo).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(xp) XP")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(palette.accent)
                Button("Complete a +10 fair-play action") { xp += 10 }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                WorkspaceSection(title: "Next badges", palette: palette) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Streak: 3 correct polls", systemImage: "flame.fill")
                        Label("Helper: 5 good chat replies", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                }
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

// MARK: - Smart / AI

private struct AnalystWorkspace: View {
    let palette: ThemePalette
    @State private var question = ""
    @State private var answer = "Ask anything about shape, pressing, or set pieces. Answers are canned demos until a model is wired in."

    private let canned = [
        "Barça tilted possession left to isolate the winger, then switched quickly when the lane opened.",
        "The low block stayed compact; the breakthrough came from third-man runs behind the midfield line.",
        "Set-piece xG was modest, but recycled corners kept pressure high enough to force mistakes.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("e.g. Why did the press stall?", text: $question, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .textFieldStyle(.roundedBorder)
                Button("Ask analyst") {
                    answer = canned.randomElement() ?? answer
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                Text(answer)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.card.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

private struct PersonalizedFeedWorkspace: View {
    let palette: ThemePalette
    @AppStorage("bf_pref_youth") private var youth: Double = 0.45
    @AppStorage("bf_pref_transfer") private var transfers: Double = 0.55

    var body: some View {
        Form {
            Section("Taste sliders") {
                VStack(alignment: .leading) {
                    Text("Youth / La Masia weight")
                    Slider(value: $youth, in: 0 ... 1)
                }
                VStack(alignment: .leading) {
                    Text("Transfer market weight")
                    Slider(value: $transfers, in: 0 ... 1)
                }
            }
            Section("Preview mix") {
                Text("Rough blend: \(Int(youth * 100))% youth stories, \(Int(transfers * 100))% transfer noise. Server ranking comes later; this proves on-device prefs.")
                    .font(.footnote)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
    }
}

private struct VoiceQAWorkspace: View {
    let palette: ThemePalette
    @State private var textQ = ""
    @State private var out = "Type a question (voice input ships later). Try “next match” or “top scorer”."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Ask in text…", text: $textQ)
                    .textFieldStyle(.roundedBorder)
                Button("Answer") {
                    let q = textQ.lowercased()
                    if q.contains("next") || q.contains("match") {
                        out = "Next kickoff is pulled from the Matches tab schedule once it loads."
                    } else if q.contains("scorer") {
                        out = "Demo answer: attacking mids and wingers lead xG this week."
                    } else {
                        out = "Demo router: refine your question with a player or competition name."
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                Text(out).font(.body).foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

// MARK: - Games

private struct FantasyWorkspace: View {
    let palette: ThemePalette
    private let pool = ["Lamine Yamal", "Raphinha", "Lewandowski", "Pedri", "Gavi", "Frenkie", "Ronald Araújo", "Koundé", "Balde", "Ter Stegen"]
    @State private var picks: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick up to five players (local demo lineup).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(pool, id: \.self) { name in
                    Toggle(isOn: Binding(
                        get: { picks.contains(name) },
                        set: { on in
                            if on, picks.count < 5 { picks.insert(name) }
                            if !on { picks.remove(name) }
                        }
                    )) {
                        Text(name)
                    }
                    .tint(palette.accent)
                }
                Text("Selected: \(picks.sorted().joined(separator: ", "))")
                    .font(.footnote)
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

private struct PredictionLeaguesWorkspace: View {
    let palette: ThemePalette
    @AppStorage("bf_league_names") private var rawNames = "Anna|Leo|Marta"
    @State private var entry = ""

    private var board: [String] {
        rawNames.split(separator: "|").map(String.init).filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mini leaderboard (device-local).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(Array(board.enumerated()), id: \.offset) { idx, name in
                    HStack {
                        Text("\(idx + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Text(name).font(.headline)
                        Spacer()
                        Text("\(120 - idx * 7) pts")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.accent)
                    }
                    .padding(.vertical, 4)
                }
                HStack {
                    TextField("Add nickname", text: $entry)
                        .textFieldStyle(.roundedBorder)
                    Button("Join") {
                        let t = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        var next = board
                        next.append(t)
                        rawNames = next.joined(separator: "|")
                        entry = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                }
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

private struct DailyChallengeWorkspace: View {
    let palette: ThemePalette
    @State private var choice: String?
    @State private var streak = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Who scored the famous Wembley 1992 winner?")
                    .font(.headline)
                ForEach(["Romário", "Ronald Koeman", "Stoichkov"], id: \.self) { name in
                    Button {
                        choice = name
                        streak = (name == "Ronald Koeman") ? streak + 1 : 0
                    } label: {
                        HStack {
                            Text(name)
                            Spacer()
                            if choice == name {
                                Image(systemName: name == "Ronald Koeman" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.card.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Text("Streak: \(streak)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

// MARK: - Community

private struct LocalGroupsWorkspace: View {
    let palette: ThemePalette
    @AppStorage("bf_joined_groups") private var joined = ""

    private let chapters = ["London", "Paris", "Berlin", "New York", "Lagos", "Tokyo"]

    private var set: Set<String> {
        Set(joined.split(separator: ",").map(String.init))
    }

    var body: some View {
        List {
            Section("Chapters (demo)") {
                ForEach(chapters, id: \.self) { city in
                    Toggle(isOn: Binding(
                        get: { set.contains(city) },
                        set: { on in
                            var s = set
                            if on { s.insert(city) } else { s.remove(city) }
                            joined = s.sorted().joined(separator: ",")
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text("Penyes in \(city)")
                            Text("Chat + meetups (local demo state)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(palette.accent)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
    }
}

private struct UserProfileWorkspace: View {
    let palette: ThemePalette
    @AppStorage("bf_profile_nick") private var nick = "Culer"
    @AppStorage("bf_profile_hero") private var hero = "Pedri"

    var body: some View {
        Form {
            Section("Card") {
                TextField("Nickname", text: $nick)
                Picker("Favourite player", selection: $hero) {
                    ForEach(["Pedri", "Lamine Yamal", "Ter Stegen", "Ronald Araújo"], id: \.self) { Text($0) }
                }
            }
            Section("Preview") {
                Text("\(nick) - \(hero) stan")
                    .font(.headline)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
    }
}

private struct ClipsWorkspace: View {
    let palette: ThemePalette
    @State private var items = ["Training touch reel", "Montjuïc walk-in"]

    @State private var draft = ""

    var body: some View {
        List {
            Section {
                ForEach(items, id: \.self) { Text($0) }
            }
            Section("Upload (demo)") {
                TextField("Title", text: $draft)
                Button("Add clip entry") {
                    let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    items.insert(t, at: 0)
                    draft = ""
                }
                .tint(palette.accent)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
    }
}

// MARK: - Monetisation & misc

private struct PremiumWorkspace: View {
    let palette: ThemePalette
    @AppStorage("bf_premium_demo") private var isPro = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Simulate Pro access", isOn: $isPro)
                    .tint(palette.accent)
                WorkspaceSection(title: isPro ? "Unlocked" : "Locked", palette: palette) {
                    Text(isPro ? "Ad-free layout, deeper stats packs, early rooms." : "Toggle on to preview the Pro layout locally.")
                        .font(.footnote)
                }
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

private struct MarketplaceWorkspace: View {
    let palette: ThemePalette
    private let kits = ["2011 home inspired", "Dream Team orange", "European navy night"]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(kits, id: \.self) { name in
                    VStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(palette.card)
                            .frame(height: 120)
                            .overlay { Image(systemName: "tshirt.fill").foregroundStyle(palette.accent) }
                        Text(name).font(.caption).multilineTextAlignment(.center)
                        Button("Save") {}
                            .buttonStyle(.bordered)
                            .tint(palette.accent)
                    }
                    .padding(8)
                    .background(palette.card.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

private struct EventsWorkspace: View {
    let palette: ThemePalette

    var body: some View {
        List {
            Section("Watch parties (demo)") {
                Link("Barça Supporters Club - sample link", destination: URL(string: "https://www.fcbarcelona.com/en/club/fan-groups-penyas")!)
                Text("Ticketing partners plug in here with disclosed affiliate tags.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(palette.accent)
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
    }
}

private struct AudioCommentaryWorkspace: View {
    let palette: ThemePalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Low-latency audio rooms need a streaming SDK. This screen documents the flow and blocks accidental taps.")
                    .font(.body)
                Button("Start listen (disabled)") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

private struct ARTryOnWorkspace: View {
    let palette: ThemePalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("ARKit body tracking + licensed textures land later. Use Themes to preview kit palettes today.")
                    .font(.body)
                Image(systemName: "arkit")
                    .font(.system(size: 56))
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

private struct StadiumModeWorkspace: View {
    let palette: ThemePalette
    @AppStorage("bf_stadium_on") private var on = false

    var body: some View {
        Form {
            Toggle("Stadium mode (demo geofence UI)", isOn: $on)
                .tint(palette.accent)
            Section {
                Text(on ? "Seat chat channels unlock (mock)." : "Flip on to simulate being inside the ground.")
                    .font(.footnote)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
    }
}

private struct TransferTrackerWorkspace: View {
    let palette: ThemePalette
    @AppStorage("bf_rumor_likelihood") private var likelihood: Double = 0.35

    private let rows = [
        ("Wide forward depth", "Tier-3 press chatter"),
        ("Loan recall clause", "Agent-linked rumour"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.0).font(.headline)
                        Text(row.1).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.card.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading) {
                    Text("Demo likelihood slider")
                    Slider(value: $likelihood, in: 0 ... 1)
                    Text(String(format: "%.0f%% confidence (local only)", likelihood * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
    }
}

// MARK: - Calendar helper

private enum FixtureCalendarWriter {
    static func add(fixture: MatchFixture) async -> String {
        let store = EKEventStore()
        do {
            let ok = try await store.requestWriteOnlyAccessToEvents()
            guard ok else { return "Calendar access was denied." }
            let event = EKEvent(eventStore: store)
            event.title = "\(fixture.homeTeam) vs \(fixture.awayTeam)"
            event.startDate = fixture.kickoff
            event.endDate = fixture.kickoff.addingTimeInterval(2 * 60 * 60)
            event.calendar = store.defaultCalendarForNewEvents
            event.url = URL(string: "https://www.fcbarcelona.com")
            try store.save(event, span: .thisEvent)
            return "Added to your default calendar."
        } catch {
            return error.localizedDescription
        }
    }
}
