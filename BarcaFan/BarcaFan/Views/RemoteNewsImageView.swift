import SwiftUI
import UIKit

/// Loads RSS/CDN images with a browser-like `User-Agent` (many CDNs block the default iOS UA) and optional HTTPS upgrade.
enum NewsImagePipeline {
    static let cache = NSCache<NSString, UIImage>()
    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FCBHome/1.0 Mobile/15E148",
            "Accept": "image/avif,image/webp,image/apng,image/jpeg,image/png,image/*,*/*;q=0.8",
        ]
        c.urlCache = URLCache(memoryCapacity: 40 * 1024 * 1024, diskCapacity: 120 * 1024 * 1024)
        return URLSession(configuration: c)
    }()

    static func normalizedURL(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == "http", var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        parts.scheme = "https"
        return parts.url ?? url
    }

    static func loadUIImage(from url: URL) async -> UIImage? {
        let key = normalizedURL(url).absoluteString as NSString
        if let hit = cache.object(forKey: key) {
            return hit
        }
        var request = URLRequest(url: normalizedURL(url))
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 22
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            guard let raw = UIImage(data: data) else { return nil }
            let scaled = raw.preparedForDisplay(maxEdge: 360)
            cache.setObject(scaled, forKey: key)
            return scaled
        } catch {
            return nil
        }
    }
}

private extension UIImage {
    func preparedForDisplay(maxEdge: CGFloat) -> UIImage {
        let w = size.width
        let h = size.height
        let longest = max(w, h)
        guard longest > maxEdge, longest > 0 else { return self }
        let scale = maxEdge / longest
        let newSize = CGSize(width: max(1, w * scale), height: max(1, h * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

/// Remote image that fills its parent frame (use `.frame(width:height:)` outside).
struct RemoteNewsImageView: View {
    let url: URL
    var showProgressWhileLoading: Bool = true
    /// When decode/network fails, show a photo symbol instead of empty space.
    var showPhotoPlaceholderOnFailure: Bool = true

    @State private var uiImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else if loadFailed {
                    if showPhotoPlaceholderOnFailure {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    } else {
                        Color.clear
                    }
                } else if showProgressWhileLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.clear
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: url.absoluteString) {
            loadFailed = false
            uiImage = nil
            if let img = await NewsImagePipeline.loadUIImage(from: url) {
                uiImage = img
            } else {
                loadFailed = true
            }
        }
    }
}
