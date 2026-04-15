import SwiftUI

/// AsyncImage wrapper that retries loading once on failure (e.g. transient network in chat/product lists).
struct RetryAsyncImage<Placeholder: View, FailurePlaceholder: View>: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    /// When false, image uses the container width and keeps the asset aspect ratio (`containerRelativeFrame`). `width` / `height` are ignored for layout (still used only by the fill mode).
    var fillsFixedFrame: Bool = true
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failurePlaceholder: () -> FailurePlaceholder

    @State private var retryId = 0

    init(
        url: URL?,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = 8,
        fillsFixedFrame: Bool = true,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failurePlaceholder: @escaping () -> FailurePlaceholder
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.fillsFixedFrame = fillsFixedFrame
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
                                if retryId == 0 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        retryId = 1
                                    }
                                }
                            }
                    @unknown default:
                        failurePlaceholder()
                    }
                }
                .id(retryId)
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
                                if retryId == 0 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        retryId = 1
                                    }
                                }
                            }
                    @unknown default:
                        failurePlaceholder()
                            .containerRelativeFrame(.horizontal)
                            .aspectRatio(1.0 / 1.3, contentMode: .fit)
                    }
                }
                .id(retryId)
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

