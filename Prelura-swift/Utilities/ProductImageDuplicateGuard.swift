import Foundation
import UIKit
import CryptoKit

/// Product-upload duplicate guard.
///
/// Enforces duplicate prevention in two layers:
/// 1) Server precheck (platform-wide when backend exposes duplicate-check mutation).
/// 2) Local fallback/index (same-upload and previously accepted upload fingerprints on this device).
///
/// This guard is intentionally used only in product listing flows.
final class ProductImageDuplicateGuard {
    struct PreparedUpload {
        let fingerprints: [ImageFingerprint]
    }

    struct ImageFingerprint: Codable, Hashable {
        let sha256: String
        let dHash64Hex: String
    }

    private struct StoredFingerprint: Codable, Hashable {
        let sha256: String
        let dHash64Hex: String
        let createdAt: Date
    }

    private struct DuplicateCheckEnvelopeA: Decodable {
        let checkDuplicateProductImages: DuplicateCheckResult?
    }

    private struct DuplicateCheckEnvelopeB: Decodable {
        let checkProductImageDuplicates: DuplicateCheckResult?
    }

    private struct DuplicateCheckResult: Decodable {
        let isDuplicate: Bool?
        let hasDuplicates: Bool?
        let duplicateCount: Int?
        let message: String?
    }

    private let client: GraphQLClient
    private let userDefaults: UserDefaults
    private let storageKey = "wearhouse_product_image_dup_index_v1"
    private let maxStoredFingerprints = 2000
    private let localNearDuplicateHammingThreshold = 2

    init(client: GraphQLClient = GraphQLClient(), userDefaults: UserDefaults = .standard) {
        self.client = client
        self.userDefaults = userDefaults
    }

    /// Computes fingerprints and enforces duplicate checks before product image upload.
    /// Throws a user-facing error when a duplicate is detected.
    func validateBeforeUpload(images: [UIImage], authToken: String?) async throws -> PreparedUpload {
        guard !images.isEmpty else { return PreparedUpload(fingerprints: []) }
        let fingerprints = try images.map(Self.fingerprint(from:))
        try validateWithinCurrentSelection(fingerprints)

        // Server precheck is authoritative when available.
        // If backend mutation is not deployed yet, we fall back to local index checks.
        let serverCheckSupported = try await checkServerForDuplicatesIfSupported(fingerprints: fingerprints, authToken: authToken)
        if !serverCheckSupported {
            try validateAgainstLocalIndex(fingerprints)
        }
        return PreparedUpload(fingerprints: fingerprints)
    }

    /// Call after a successful listing create/update so future uploads can be locally compared.
    func markUploadAccepted(_ prepared: PreparedUpload) {
        guard !prepared.fingerprints.isEmpty else { return }
        var stored = loadStoredFingerprints()
        let now = Date()
        for fp in prepared.fingerprints {
            stored.append(StoredFingerprint(sha256: fp.sha256, dHash64Hex: fp.dHash64Hex, createdAt: now))
        }
        // Keep newest-first while deduping by SHA.
        var seen = Set<String>()
        var dedupedNewestFirst: [StoredFingerprint] = []
        for item in stored.sorted(by: { $0.createdAt > $1.createdAt }) {
            guard seen.insert(item.sha256).inserted else { continue }
            dedupedNewestFirst.append(item)
            if dedupedNewestFirst.count >= maxStoredFingerprints { break }
        }
        saveStoredFingerprints(dedupedNewestFirst)
    }

    private func validateWithinCurrentSelection(_ fingerprints: [ImageFingerprint]) throws {
        var seenSHA = Set<String>()
        var seenDHash = Set<String>()
        for fp in fingerprints {
            if !seenSHA.insert(fp.sha256).inserted || !seenDHash.insert(fp.dHash64Hex).inserted {
                throw duplicateError("You selected duplicate photos in this listing. Remove repeated images and try again.")
            }
        }
        // Near-duplicate check within the same selection.
        if fingerprints.count > 1 {
            for i in 0..<(fingerprints.count - 1) {
                for j in (i + 1)..<fingerprints.count {
                    let d = Self.hammingDistanceHex64(fingerprints[i].dHash64Hex, fingerprints[j].dHash64Hex)
                    if d <= localNearDuplicateHammingThreshold {
                        throw duplicateError("Some selected photos are visually identical. Please keep only unique photos.")
                    }
                }
            }
        }
    }

    private func validateAgainstLocalIndex(_ fingerprints: [ImageFingerprint]) throws {
        let stored = loadStoredFingerprints()
        guard !stored.isEmpty else { return }
        let storedSHA = Set(stored.map(\.sha256))
        for fp in fingerprints where storedSHA.contains(fp.sha256) {
            throw duplicateError("This photo has already been used in a product upload. Please choose a different image.")
        }
        // Conservative near-duplicate check against local accepted set.
        for fp in fingerprints {
            for old in stored {
                let d = Self.hammingDistanceHex64(fp.dHash64Hex, old.dHash64Hex)
                if d <= localNearDuplicateHammingThreshold {
                    throw duplicateError("This photo looks the same as one already uploaded. Please choose a different product image.")
                }
            }
        }
    }

    /// Returns true when a server duplicate check endpoint was available and executed.
    private func checkServerForDuplicatesIfSupported(fingerprints: [ImageFingerprint], authToken: String?) async throws -> Bool {
        client.setAuthToken(authToken)
        let items: [[String: String]] = fingerprints.map { ["sha256": $0.sha256, "dHash64Hex": $0.dHash64Hex] }

        // Candidate A: checkDuplicateProductImages(images: ...)
        do {
            let queryA = """
            mutation CheckDuplicateProductImages($images: [ProductImageFingerprintInputType!]!) {
              checkDuplicateProductImages(images: $images) {
                isDuplicate
                hasDuplicates
                duplicateCount
                message
              }
            }
            """
            let responseA: DuplicateCheckEnvelopeA = try await client.execute(
                query: queryA,
                variables: ["images": items],
                responseType: DuplicateCheckEnvelopeA.self
            )
            if let result = responseA.checkDuplicateProductImages {
                try enforceServerResult(result)
                return true
            }
            return true
        } catch let error as GraphQLError {
            if !Self.isMissingSchemaField(error) { throw error }
        }

        // Candidate B: checkProductImageDuplicates(fingerprints: ...)
        do {
            let queryB = """
            mutation CheckProductImageDuplicates($fingerprints: [ProductImageFingerprintInputType!]!) {
              checkProductImageDuplicates(fingerprints: $fingerprints) {
                isDuplicate
                hasDuplicates
                duplicateCount
                message
              }
            }
            """
            let responseB: DuplicateCheckEnvelopeB = try await client.execute(
                query: queryB,
                variables: ["fingerprints": items],
                responseType: DuplicateCheckEnvelopeB.self
            )
            if let result = responseB.checkProductImageDuplicates {
                try enforceServerResult(result)
                return true
            }
            return true
        } catch let error as GraphQLError {
            if Self.isMissingSchemaField(error) {
                return false
            }
            throw error
        }
    }

    private func enforceServerResult(_ result: DuplicateCheckResult) throws {
        let isDuplicate = (result.isDuplicate == true)
            || (result.hasDuplicates == true)
            || ((result.duplicateCount ?? 0) > 0)
        guard !isDuplicate else {
            let msg = result.message?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let msg, !msg.isEmpty {
                throw duplicateError(msg)
            }
            throw duplicateError("This image is already used on another product listing. Please upload unique product photos.")
        }
    }

    private static func isMissingSchemaField(_ error: GraphQLError) -> Bool {
        guard case .graphQLErrors(let errors) = error else { return false }
        return errors.contains { e in
            let m = e.message.lowercased()
            return m.contains("cannot query field")
                || m.contains("unknown argument")
                || m.contains("unknown type")
        }
    }

    private func duplicateError(_ message: String) -> NSError {
        NSError(domain: "ProductImageDuplicateGuard", code: 409, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func loadStoredFingerprints() -> [StoredFingerprint] {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StoredFingerprint].self, from: data) else { return [] }
        return decoded
    }

    private func saveStoredFingerprints(_ items: [StoredFingerprint]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func fingerprint(from image: UIImage) throws -> ImageFingerprint {
        guard let normalizedJPEG = normalizedJPEGData(from: image, maxDimension: 1024, quality: 0.86),
              let hashPixels = grayscalePixelsForDHash(from: image, width: 9, height: 8) else {
            throw NSError(
                domain: "ProductImageDuplicateGuard",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image fingerprint for duplicate detection."]
            )
        }
        let sha = SHA256.hash(data: normalizedJPEG).map { String(format: "%02x", $0) }.joined()
        let dHash = makeDHashHex(from: hashPixels, width: 9, height: 8)
        return ImageFingerprint(sha256: sha, dHash64Hex: dHash)
    }

    private static func normalizedJPEGData(from image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let srcSize = image.size
        guard srcSize.width > 0, srcSize.height > 0 else { return nil }
        let scale = min(maxDimension / srcSize.width, maxDimension / srcSize.height, 1)
        let target = CGSize(width: floor(srcSize.width * scale), height: floor(srcSize.height * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }

    private static func grayscalePixelsForDHash(from image: UIImage, width: Int, height: Int) -> [UInt8]? {
        guard let cgImage = image.cgImage else {
            // Fallback for images that don't have direct CGImage backing.
            let renderer = UIGraphicsImageRenderer(size: image.size)
            let rendered = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
            guard let fallbackCG = rendered.cgImage else { return nil }
            return grayscalePixels(from: fallbackCG, width: width, height: height)
        }
        return grayscalePixels(from: cgImage, width: width, height: height)
    }

    private static func grayscalePixels(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 0, count: width * height)
        let bytesPerRow = width
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func makeDHashHex(from pixels: [UInt8], width: Int, height: Int) -> String {
        var hash: UInt64 = 0
        var bitIndex: UInt64 = 0
        for y in 0..<height {
            let rowStart = y * width
            for x in 0..<(width - 1) {
                let left = pixels[rowStart + x]
                let right = pixels[rowStart + x + 1]
                if left > right {
                    hash |= (1 << bitIndex)
                }
                bitIndex += 1
            }
        }
        return String(format: "%016llx", hash)
    }

    private static func hammingDistanceHex64(_ lhsHex: String, _ rhsHex: String) -> Int {
        let lhs = UInt64(lhsHex, radix: 16) ?? 0
        let rhs = UInt64(rhsHex, radix: 16) ?? 0
        return (lhs ^ rhs).nonzeroBitCount
    }
}
