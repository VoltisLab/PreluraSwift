import Foundation

/// Persists scheduled listings and activates them (`ACTIVE`) once `activateAt` has passed, when the app becomes active (server creates them `INACTIVE` until then).
enum PendingScheduledListingActivator {
    private static let defaultsKey = "wearhouse_pending_scheduled_listing_activations_v1"

    private struct Entry: Codable, Equatable {
        let productId: Int
        let activateAt: Date
    }

    static func register(productId: Int, activateAt: Date) {
        // Allow slightly past dates (clock skew); very old dates are ignored.
        guard activateAt.timeIntervalSinceNow > -120 else { return }
        var list = load()
        list.removeAll { $0.productId == productId }
        list.append(Entry(productId: productId, activateAt: activateAt))
        save(list)
    }

    /// True while this product is in the local queue (scheduled go-live, including overdue until activation succeeds).
    static func isRegisteredForScheduledActivation(productId: Int) -> Bool {
        load().contains { $0.productId == productId }
    }

    static func processDueIfNeeded(authToken: String?) async {
        guard let token = authToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }
        var list = load()
        guard !list.isEmpty else { return }
        let now = Date()
        let svc = ProductService()
        svc.updateAuthToken(token)
        var remaining: [Entry] = []
        var didActivateAny = false
        for e in list {
            if e.activateAt <= now {
                do {
                    try await svc.updateProductStatus(productId: e.productId, status: "ACTIVE")
                    didActivateAny = true
                } catch {
                    remaining.append(e)
                }
            } else {
                remaining.append(e)
            }
        }
        save(remaining)
        if didActivateAny {
            await MainActor.run {
                NotificationCenter.default.post(name: .wearhouseUserProfileDidUpdate, object: nil)
            }
        }
    }

    private static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private static func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
