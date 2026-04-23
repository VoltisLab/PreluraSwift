import SwiftUI

struct NewsFeedView: View {
    @Environment(KitThemeStore.self) private var themeStore
    @Environment(NewsFeedViewModel.self) private var newsModel

    var body: some View {
        let palette = themeStore.current.palette
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if newsModel.isLoading, newsModel.stories.isEmpty {
                        ProgressView()
                            .tint(palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                    }

                    if let err = newsModel.lastError, newsModel.stories.isEmpty {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    NewsHeroCarousel(stories: newsModel.stories, palette: palette)

                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text("Fan feed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        ForEach(newsModel.stories) { story in
                            NavigationLink(value: story) {
                                NewsRowView(story: story, palette: palette)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .overlay(palette.primary.opacity(0.15))
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("News")
            .navigationDestination(for: NewsStory.self) { story in
                NewsDetailView(story: story, palette: palette)
            }
            .refreshable {
                await newsModel.refresh()
            }
            .task {
                if newsModel.stories.isEmpty {
                    await newsModel.refresh()
                }
            }
        }
        .tint(palette.accent)
    }
}

// MARK: - Hero carousel (edge-to-edge)

private struct NewsHeroCarousel: View {
    let stories: [NewsStory]
    let palette: ThemePalette

    private var slides: [NewsStory] {
        let withImage = stories.filter { $0.imageURL != nil }
        return Array(withImage.prefix(12))
    }

    var body: some View {
        Group {
            if slides.isEmpty {
                Color.clear.frame(height: 0)
            } else {
                TabView {
                    ForEach(slides) { story in
                        NavigationLink(value: story) {
                            NewsHeroSlide(story: story, palette: palette)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .horizontal)
            }
        }
    }
}

private struct NewsHeroSlide: View {
    let story: NewsStory
    let palette: ThemePalette

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                ZStack {
                    Rectangle().fill(palette.card)
                    if let url = story.imageURL {
                        RemoteNewsImageView(url: url, showProgressWhileLoading: true, showPhotoPlaceholderOnFailure: false)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 6) {
                TrustBadgeView(presentation: story.presentation)
                Text(story.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 2)
                    .lineLimit(3)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipped()
    }
}

// MARK: - Row

private struct NewsRowView: View {
    let story: NewsStory
    let palette: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                NewsThumbnailView(url: story.imageURL, palette: palette)
                    .frame(width: 72, height: 72)

                Text(story.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            }

            Text(story.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 8) {
                Text(story.sourceName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                Spacer(minLength: 8)
                TrustBadgeView(presentation: story.presentation)
                    .fixedSize(horizontal: true, vertical: true)
                Spacer(minLength: 8)
                Text(story.publishedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(palette.card.opacity(0.35))
    }
}

private struct NewsThumbnailView: View {
    let url: URL?
    let palette: ThemePalette

    var body: some View {
        Group {
            if let url {
                RemoteNewsImageView(url: url, showProgressWhileLoading: true, showPhotoPlaceholderOnFailure: true)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.card)
                    .overlay {
                        Image(systemName: "newspaper")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Detail

private struct NewsDetailView: View {
    let story: NewsStory
    let palette: ThemePalette
    @State private var showFullArticle = false
    @State private var fullPagePlain: String?
    @State private var fullPageLoading = true
    @State private var fullPageLoadFailed = false

    private var bodyArticleText: String {
        let full = story.fullPlainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !full.isEmpty { return full }
        let s = story.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "No preview text for this article." : s
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.card.opacity(0.55))
                    if let url = story.imageURL {
                        RemoteNewsImageView(url: url, showProgressWhileLoading: true, showPhotoPlaceholderOnFailure: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)

                HStack {
                    TrustBadgeView(presentation: story.presentation)
                    Spacer()
                    Text("Trust \(story.trustScore)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(palette.secondary.opacity(0.25))
                        .clipShape(Capsule())
                }
                Text(story.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                if fullPageLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(palette.accent)
                        Text("Loading full article…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if let fullPagePlain {
                    Text(fullPagePlain)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                } else if !fullPageLoading {
                    if fullPageLoadFailed {
                        Text("We could not pull the full article text from this page (format, paywall, or network). Here is the feed preview; open the site for the complete layout.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                    }
                    Text(bodyArticleText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Button {
                    showFullArticle = true
                } label: {
                    Label("Open publisher site", systemImage: "safari")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)

                Divider().overlay(palette.accent.opacity(0.25))
                LabeledContent("Source", value: story.sourceName)
                LabeledContent("Tier", value: "Tier \(story.tier.rawValue) - \(story.tier.title)")

                Button {
                    // POST report to your backend when available.
                } label: {
                    Label("Report this story", systemImage: "flag")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 520, alignment: .topLeading)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFullArticle) {
            SafariView(url: story.linkURL)
                .ignoresSafeArea()
        }
        .task(id: story.linkURL.absoluteString) {
            fullPageLoading = true
            fullPagePlain = nil
            fullPageLoadFailed = false
            defer { fullPageLoading = false }
            do {
                let text = try await ArticleFullTextLoader.loadPlainArticle(linkURL: story.linkURL)
                fullPagePlain = text
            } catch {
                fullPageLoadFailed = true
            }
        }
    }
}
