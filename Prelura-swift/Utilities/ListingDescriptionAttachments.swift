import Foundation

/// Embeds optional listing fields in the product `description` when the GraphQL schema has no dedicated field (e.g. free-form measurements).
enum ListingDescriptionAttachments {
    static let measurementsMarker = "\n\n── Measurements ──\n"

    static func embedMeasurements(_ description: String, measurements: String?) -> String {
        let stripped = stripMeasurements(description)
        let m = measurements?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !m.isEmpty else { return stripped }
        return stripped + measurementsMarker + m
    }

    static func stripMeasurements(_ description: String) -> String {
        guard let range = description.range(of: measurementsMarker) else {
            return description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(description[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Splits API description into buyer-facing body and extracted measurements (if we embedded them).
    static func splitMeasurements(from raw: String?) -> (body: String, measurements: String?) {
        guard let raw = raw, !raw.isEmpty else { return ("", nil) }
        guard let range = raw.range(of: measurementsMarker) else {
            return (raw, nil)
        }
        let body = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let meas = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (body, meas.isEmpty ? nil : meas)
    }
}

/// Shared mapping from GraphQL product fragments to display / `Item` fields.
enum ProductListingFields {
    static func materialSummary(from materials: [BrandData]?) -> String? {
        guard let materials, !materials.isEmpty else { return nil }
        let names = materials.compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        return names.joined(separator: ", ")
    }

    static func mergedStyleTags(styles: [String]?, legacyStyle: String?) -> [String] {
        var combined: [String] = []
        if let styles {
            for s in styles {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { combined.append(t) }
            }
        }
        if let leg = legacyStyle?.trimmingCharacters(in: .whitespacesAndNewlines), !leg.isEmpty {
            combined.append(leg)
        }
        // API often sends the same style in both `style` and `styles[0]` - dedupe by canonical enum raw.
        return StyleEnumCatalog.normalizedUnique(combined, maxCount: nil)
    }
}
