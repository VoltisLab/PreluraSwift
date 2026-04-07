//
//  LookbookAnalyticsView.swift
//  Insights for your lookbook post: taps on tagged products vs shop, plus engagement totals.
//

import Charts
import SwiftUI

struct LookbookAnalyticsView: View {
    let entry: LookbookEntry
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var refreshed: LookbookEntry?
    @State private var loading = true
    @State private var loadError: String?

    private var model: LookbookEntry { refreshed ?? entry }

    private struct FunnelRow: Identifiable {
        let label: String
        let value: Int
        var id: String { label }
    }

    private var funnelRows: [FunnelRow] {
        [
            FunnelRow(label: L10n.string("Product opens"), value: model.productLinkClicks),
            FunnelRow(label: L10n.string("Shop opens"), value: model.shopLinkClicks)
        ]
    }

    private struct DayBin: Identifiable {
        let date: Date
        let clicks: Int
        var id: Date { date }
    }

    private var lastSevenDayBins: [DayBin] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) ?? Date()
        return (0..<7).compactMap { offset -> DayBin? in
            guard let d = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayBin(date: d, clicks: 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xl)
                } else if let err = loadError, !err.isEmpty {
                    Text(err)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(.red)
                        .padding(.horizontal, Theme.Spacing.md)
                }

                Text(L10n.string("Engagement"))
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                    analyticsTile(title: L10n.string("Likes"), value: model.likesCount, symbol: "heart.fill", tint: .pink)
                    analyticsTile(title: L10n.string("Comments"), value: model.commentsCount, symbol: "bubble.right.fill", tint: .cyan)
                    analyticsTile(title: L10n.string("Product opens"), value: model.productLinkClicks, symbol: "bag.fill", tint: Theme.primaryColor)
                    analyticsTile(title: L10n.string("Shop opens"), value: model.shopLinkClicks, symbol: "storefront.fill", tint: .orange)
                }
                .padding(.horizontal, Theme.Spacing.md)

                Text(L10n.string("Traffic from this post"))
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)

                Chart(funnelRows) { row in
                    BarMark(
                        x: .value(L10n.string("Opens"), row.value),
                        y: .value(L10n.string("Type"), row.label)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.primaryColor, Theme.primaryColor.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 160)
                .padding(.horizontal, Theme.Spacing.md)

                Text(L10n.string("Daily activity"))
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)

                Text(L10n.string("Per-day charts will fill in as we log more events server-side. Totals above update in real time."))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)

                Chart(lastSevenDayBins) { bin in
                    AreaMark(
                        x: .value("Day", bin.date, unit: .day),
                        y: .value("Events", bin.clicks)
                    )
                    .foregroundStyle(Theme.primaryColor.opacity(0.22))
                    LineMark(
                        x: .value("Day", bin.date, unit: .day),
                        y: .value("Events", bin.clicks)
                    )
                    .foregroundStyle(Theme.primaryColor)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Analytics"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.string("Done")) { dismiss() }
                    .foregroundColor(Theme.primaryColor)
            }
        }
        .task { await refreshFromServer() }
    }

    private func analyticsTile(title: String, value: Int, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
            }
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.primaryText)
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.Colors.glassBorder.opacity(0.35), lineWidth: 0.5)
        )
    }

    private func refreshFromServer() async {
        loading = true
        loadError = nil
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        do {
            guard let post = try await service.fetchLookbookPost(postId: entry.apiPostId) else {
                await MainActor.run {
                    loadError = L10n.string("Could not load this post.")
                    loading = false
                }
                return
            }
            await MainActor.run {
                var next = entry
                next.likesCount = post.likesCount ?? next.likesCount
                next.commentsCount = post.commentsCount ?? next.commentsCount
                next.productLinkClicks = post.productLinkClicks ?? next.productLinkClicks
                next.shopLinkClicks = post.shopLinkClicks ?? next.shopLinkClicks
                refreshed = next
                loading = false
            }
        } catch {
            await MainActor.run {
                loadError = error.localizedDescription
                loading = false
            }
        }
    }
}
