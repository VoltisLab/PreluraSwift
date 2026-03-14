import Foundation
import UIKit

private enum SellDraftDate {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let noFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func decode(_ str: String) -> Date? {
        SellDraftDate.withFractional.date(from: str) ?? SellDraftDate.noFractional.date(from: str)
    }
    static func encode(_ date: Date) -> String {
        SellDraftDate.withFractional.string(from: date)
    }
}

/// Persists sell-form drafts to disk. Each draft is a folder with draft.json + 0.jpg, 1.jpg, ...
enum SellDraftStore {
    private static let subdir = "PreluraDrafts"
    private static let draftJSON = "draft.json"

    static var draftsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(subdir, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func draftURL(id: String) -> URL {
        draftsDirectory.appendingPathComponent(id, isDirectory: true)
    }

    /// Save current form state as a new draft. Images are written as 0.jpg, 1.jpg, ...
    static func saveDraft(
        title: String,
        description: String,
        category: SellCategory?,
        brand: String?,
        condition: String?,
        colours: [String],
        sizeId: Int?,
        sizeName: String?,
        measurements: String?,
        material: String?,
        styles: [String],
        price: Double?,
        discountPrice: Double?,
        parcelSize: String?,
        images: [UIImage]
    ) throws -> SellDraft {
        let id = UUID().uuidString
        let draftDir = draftURL(id: id)
        try FileManager.default.createDirectory(at: draftDir, withIntermediateDirectories: true)

        var imageFileNames: [String] = []
        for (index, image) in images.prefix(20).enumerated() {
            let name = "\(index).jpg"
            let fileURL = draftDir.appendingPathComponent(name)
            if let data = image.jpegData(compressionQuality: 0.85) {
                try data.write(to: fileURL)
                imageFileNames.append(name)
            }
        }

        let categoryDraft = category.map { SellCategoryDraft(id: $0.id, name: $0.name, pathNames: $0.pathNames, pathIds: $0.pathIds, fullPath: $0.fullPath) }
        let draft = SellDraft(
            id: id,
            savedAt: Date(),
            title: title,
            description: description,
            category: categoryDraft,
            brand: brand,
            condition: condition,
            colours: colours,
            sizeId: sizeId,
            sizeName: sizeName,
            measurements: measurements,
            material: material,
            styles: styles,
            price: price,
            discountPrice: discountPrice,
            parcelSize: parcelSize,
            imageFileNames: imageFileNames
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(SellDraftDate.encode(date))
        }
        let data = try encoder.encode(draft.payload)
        try data.write(to: draftDir.appendingPathComponent(draftJSON))
        return draft
    }

    /// List all drafts (newest first).
    static func listDrafts() -> [SellDraft] {
        let dir = draftsDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
            return []
        }
        let draftDirs = contents.filter { url in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            guard let date = SellDraftDate.decode(str) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
            }
            return date
        }
        var drafts: [SellDraft] = []
        for url in draftDirs {
            let jsonURL = url.appendingPathComponent(draftJSON)
            guard FileManager.default.fileExists(atPath: jsonURL.path),
                  let data = try? Data(contentsOf: jsonURL),
                  let p = try? decoder.decode(SellDraft.Payload.self, from: data) else { continue }
            drafts.append(SellDraft(payload: p))
        }
        drafts.sort { $0.savedAt > $1.savedAt }
        return drafts
    }

    /// Load draft by id; loads images from disk into UIImages.
    static func loadDraft(id: String) -> (draft: SellDraft, images: [UIImage])? {
        let dir = draftURL(id: id)
        let jsonURL = dir.appendingPathComponent(draftJSON)
        guard FileManager.default.fileExists(atPath: jsonURL.path),
              let data = try? Data(contentsOf: jsonURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            guard let date = SellDraftDate.decode(str) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
            }
            return date
        }
        guard let payload = try? decoder.decode(SellDraft.Payload.self, from: data) else { return nil }
        let draft = SellDraft(payload: payload)
        var images: [UIImage] = []
        for name in draft.imageFileNames {
            let fileURL = dir.appendingPathComponent(name)
            if let data = try? Data(contentsOf: fileURL), let img = UIImage(data: data) {
                images.append(img)
            }
        }
        return (draft, images)
    }

    static func deleteDraft(id: String) {
        try? FileManager.default.removeItem(at: draftURL(id: id))
    }

    static var draftCount: Int { listDrafts().count }
}
