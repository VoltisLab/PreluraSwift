import SwiftUI

/// Debug: compare raw `localizedDescription` vs `L10n.userFacingError` and preview branded banners.
struct NetworkErrorPresentationDebugView: View {
    private struct Sample: Identifiable {
        let id = UUID()
        let label: String
        let error: Error
    }

    private var samples: [Sample] {
        [
            Sample(label: "URLError.secureConnectionFailed", error: URLError(.secureConnectionFailed)),
            Sample(label: "URLError.serverCertificateUntrusted", error: URLError(.serverCertificateUntrusted)),
            Sample(label: "URLError.timedOut", error: URLError(.timedOut)),
            Sample(label: "URLError.notConnectedToInternet", error: URLError(.notConnectedToInternet)),
            Sample(
                label: "Synthetic TLS string (NSError)",
                error: NSError(
                    domain: NSURLErrorDomain,
                    code: NSURLErrorSecureConnectionFailed,
                    userInfo: [NSLocalizedDescriptionKey: "An SSL error has occurred and a secure connection to the server cannot be made."]
                )
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("System errors are mapped through `L10n.userFacingError` so users never see raw TLS/SSL strings.")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)

                ForEach(samples) { item in
                    sampleBlock(item)
                }
            }
            .padding(.vertical)
            .padding(.horizontal, Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Network error UI")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func sampleBlock(_ item: Sample) -> some View {
        let raw = item.error.localizedDescription
        let mapped = L10n.userFacingError(item.error)
        let title = L10n.userFacingErrorBannerTitle(item.error)

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(item.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryText)

            Group {
                Text("Raw (never show in production UI)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                Text(raw)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .textSelection(.enabled)
            }

            Group {
                Text("Mapped message + optional TLS headline (snackbar when title is set)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                Text("Title: \(title ?? "nil")")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.Colors.secondaryText)
                Text(mapped)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.primaryText)
            }

            FeedNetworkErrorPresentation(message: mapped, title: title, onTryAgain: {})
        }
        .padding(.bottom, Theme.Spacing.lg)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        NetworkErrorPresentationDebugView()
    }
}
#endif
