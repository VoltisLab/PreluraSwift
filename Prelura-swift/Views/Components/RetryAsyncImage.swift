import SwiftUI

/// AsyncImage wrapper that retries transient load failures and supports a manual remount (e.g. bell row “reload image”).
struct RetryAsyncImage<Placeholder: View, FailurePlaceholder: View>: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    /// When false, image uses the container width and keeps the asset aspect ratio (`containerRelativeFrame`). `width` / `height` are ignored for layout (still used only by the fill mode).
    var fillsFixedFrame: Bool = true
    /// Automatic re-mount attempts after `.failure` (0 = one failure then stop; 2 = up to 3 total attempts).
    var maxAutoRetries: Int = 2
    /// Bump from the parent (e.g. tap) to force a fresh `AsyncImage` load without changing the URL.
    var externalReloadToken: Int = 0
    /// Called after the last auto-retry still ends in `.failure` (e.g. fall back to avatar URL).
    var onAutoRetriesExhausted: (() -> Void)?
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failurePlaceholder: () -> FailurePlaceholder

    @State private var retryGeneration = 0
    @State private var autoRetryTask: Task<Void, Never>?

    init(
        url: URL?,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = 8,
        fillsFixedFrame: Bool = true,
        maxAutoRetries: Int = 2,
        externalReloadToken: Int = 0,
        onAutoRetriesExhausted: (() -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failurePlaceholder: @escaping () -> FailurePlaceholder
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.fillsFixedFrame = fillsFixedFrame
        self.maxAutoRetries = max(0, maxAutoRetries)
        self.externalReloadToken = externalReloadToken
        self.onAutoRetriesExhausted = onAutoRetriesExhausted
        self.placeholder = placeholder
        self.failurePlaceholder = failurePlaceholder
    }

    var body: some View {
        if fillsFixedFrame {
            fillFixedFrameBody
        } else {
            fitContainerWidthBody
        }
    }

    private var remountIdentity: String {
        let u = url?.absoluteString ?? ""
        return "\(externalReloadToken)-\(retryGeneration)-\(u)"
    }

    private func scheduleAutoRetryIfNeeded() {
        autoRetryTask?.cancel()
        if retryGeneration >= maxAutoRetries {
            onAutoRetriesExhausted?()
            return
        }
        let step = retryGeneration
        let delayNs = UInt64((0.65 + 0.55 * Double(step)) * 1_000_000_000)
        autoRetryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled else { return }
            retryGeneration += 1
        }
    }

    private var fillFixedFrameBody: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: height)
                            .clipped()
                    case .failure:
                        failurePlaceholder()
                            .onAppear {
                                scheduleAutoRetryIfNeeded()
                            }
                    @unknown default:
                        failurePlaceholder()
                            .onAppear {
                                scheduleAutoRetryIfNeeded()
                            }
                    }
                }
                .id(remountIdentity)
            } else {
                failurePlaceholder()
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(cornerRadius)
    }

    private var fitContainerWidthBody: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder()
                            .containerRelativeFrame(.horizontal)
                            .aspectRatio(1.0 / 1.3, contentMode: .fit)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .containerRelativeFrame(.horizontal)
                    case .failure:
                        failurePlaceholder()
                            .containerRelativeFrame(.horizontal)
                            .aspectRatio(1.0 / 1.3, contentMode: .fit)
                            .onAppear {
                                scheduleAutoRetryIfNeeded()
                            }
                    @unknown default:
                        failurePlaceholder()
                            .containerRelativeFrame(.horizontal)
                            .aspectRatio(1.0 / 1.3, contentMode: .fit)
                            .onAppear {
                                scheduleAutoRetryIfNeeded()
                            }
                    }
                }
                .id(remountIdentity)
            } else {
                failurePlaceholder()
                    .containerRelativeFrame(.horizontal)
                    .aspectRatio(1.0 / 1.3, contentMode: .fit)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
