import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Helpers for choosing images from **Finder** when the app runs as an iOS app on macOS (`isiOSAppOnMac`).
/// Design notes for iPad & Mac: see `Prelura-swift/pp/README.md`.
/// On iPhone and iPad, the system Photos pickers stay the default.
enum IOSAppOnMacImageImport {
    /// `true` when this iOS binary is running on macOS (Designed for iPad).
    static var isIOSAppOnMac: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac
    }

    /// Loads images from security-scoped URLs returned by SwiftUI `fileImporter`.
    static func uiImages(fromImporterURLs urls: [URL], maxCount: Int?) -> [UIImage] {
        let ordered = maxCount.map { Array(urls.prefix($0)) } ?? urls
        var out: [UIImage] = []
        out.reserveCapacity(ordered.count)
        for url in ordered {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            if let img = UIImage(data: data)?.normalizedForDisplay() {
                out.append(img)
            }
        }
        return out
    }

    static func jpegDataList(from images: [UIImage], maxCount: Int, compression: CGFloat = 0.92) -> [Data] {
        Array(images.prefix(maxCount)).compactMap { $0.jpegData(compressionQuality: compression) }
    }
}

private struct MacOnlyImageFileImporterModifier: ViewModifier {
    @Binding var isPresented: Bool
    let allowsMultipleSelection: Bool
    let maxImageCount: Int?
    let onPick: ([UIImage]) -> Void

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: allowsMultipleSelection
        ) { result in
            switch result {
            case .success(let urls):
                let imgs = IOSAppOnMacImageImport.uiImages(fromImporterURLs: urls, maxCount: maxImageCount)
                guard !imgs.isEmpty else { return }
                Task { @MainActor in
                    onPick(imgs)
                }
            case .failure:
                break
            }
        }
    }
}

extension View {
    /// Presents the system file importer (Finder on Mac) for images. Only attaches when `isiOSAppOnMac` — no extra UI on iPhone/iPad.
    func macOnlyImageFileImporter(
        isPresented: Binding<Bool>,
        allowsMultipleSelection: Bool,
        maxImageCount: Int? = nil,
        onPick: @escaping ([UIImage]) -> Void
    ) -> some View {
        Group {
            if IOSAppOnMacImageImport.isIOSAppOnMac {
                modifier(MacOnlyImageFileImporterModifier(
                    isPresented: isPresented,
                    allowsMultipleSelection: allowsMultipleSelection,
                    maxImageCount: maxImageCount,
                    onPick: onPick
                ))
            } else {
                self
            }
        }
    }
}
