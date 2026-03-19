# Offer cards – how it works & code reference

## Short explanation

- **Data:** The API only returns the **latest** offer per conversation. We keep a **history** of offers in `offerHistory` (and in UserDefaults) so we can show multiple cards (e.g. £60, then £78).
- **Timeline:** `timelineOrder` is a list of `TimelineEntry` (message id or offer id), sorted by date so messages and offer cards appear in chronological order.
- **Rendering:** For each `.offer(offerId)` we look up the offer in `offerCards` (backed by `offerHistory`) and render `OfferCardView`. Only the **last** card gets `forceGreyedOut: false` and the “Send new offer” / Accept/Decline / Pay now buttons; older cards are greyed (no button).
- **Sending a new offer:** We append an **optimistic** card (id `pending-UUID`, sent price, `createdAt: Date()`), call createOffer/respondToOffer, then **replace** that optimistic card with a **real** card that always uses the **sent** price and `Date()` so the UI never shows a stale server price. We give that card a **synthetic id** (`serverOffer.id-UUID`) so `syncLastOfferFromConversation` never overwrites it with stale server data.
- **Sync:** When `displayedConversation.offer` changes we run `syncLastOfferFromConversation()`; we **skip** replacing if the last card is optimistic or has a synthetic id, and we **preserve** the last card’s price/time when the server has a different (stale) value. When loading the chat we run `syncOfferHistoryFromConversation()` to merge cached history with the server’s latest and backfill timestamps; after every load we also call it so the “Refresh” button on the latest card can correct the price.

---

## 1. Model: `OfferInfo`  
**File:** `Prelura-swift/Models/OfferInfo.swift`

```swift
import Foundation

/// Offer data from createOffer response or conversations query. Used for offer card in chat.
struct OfferInfo: Codable, Hashable {
    let id: String
    let status: String?
    let offerPrice: Double
    let buyer: OfferUser?
    let products: [OfferProduct]?
    /// When the offer was sent; used for card timestamp. Set locally when not from server.
    let createdAt: Date?

    struct OfferUser: Codable, Hashable {
        let username: String?
        let profilePictureUrl: String?
    }

    struct OfferProduct: Codable, Hashable {
        let id: String?
        let name: String?
        let seller: OfferUser?
    }

    enum CodingKeys: String, CodingKey {
        case id, status, offerPrice, buyer, products, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let idStr = try? c.decode(String.self, forKey: .id) {
            id = idStr
        } else {
            let idAny = try c.decode(AnyCodable.self, forKey: .id)
            id = idAny.value as? String ?? String(describing: idAny.value)
        }
        status = try c.decodeIfPresent(String.self, forKey: .status)
        if let decimal = try? c.decodeIfPresent(Decimal.self, forKey: .offerPrice) {
            offerPrice = NSDecimalNumber(decimal: decimal).doubleValue
        } else if let double = try? c.decodeIfPresent(Double.self, forKey: .offerPrice) {
            offerPrice = double
        } else {
            offerPrice = 0
        }
        buyer = try c.decodeIfPresent(OfferUser.self, forKey: .buyer)
        products = try c.decodeIfPresent([OfferProduct].self, forKey: .products)
        if let interval = try? c.decodeIfPresent(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: interval)
        } else if let interval = try? c.decodeIfPresent(TimeInterval.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: interval)
        } else {
            createdAt = nil
        }
    }

    init(id: String, status: String?, offerPrice: Double, buyer: OfferUser?, products: [OfferProduct]?, createdAt: Date? = nil) {
        self.id = id
        self.status = status
        self.offerPrice = offerPrice
        self.buyer = buyer
        self.products = products
        self.createdAt = createdAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encode(offerPrice, forKey: .offerPrice)
        try c.encodeIfPresent(buyer, forKey: .buyer)
        try c.encodeIfPresent(products, forKey: .products)
        try c.encodeIfPresent(createdAt?.timeIntervalSince1970, forKey: .createdAt)
    }

    var offerIdInt: Int? { Int(id) }
    var isPending: Bool { (status ?? "").uppercased() == "PENDING" }
    var isAccepted: Bool { (status ?? "").uppercased() == "ACCEPTED" }
    var isRejected: Bool { (status ?? "").uppercased() == "REJECTED" || (status ?? "").uppercased() == "CANCELLED" }
}
```

---

## 2. Timeline type (ChatDetailView)  
**File:** `Prelura-swift/Views/Chat/ChatDetailView.swift`

```swift
/// One item in the chat timeline: either a message or an offer card. Order is preserved so nothing moves above/below.
enum TimelineEntry: Hashable {
    case message(UUID)
    case offer(String)

    var isOffer: Bool {
        if case .offer = self { return true }
        return false
    }
}
```

---

## 3. ChatDetailView – offer state and persistence

```swift
    /// Offer cards to show: [previous, …] + current. After sending a counter we append optimistically so previous card shows greyed button.
    @State private var offerHistory: [OfferInfo] = []

    /// In-memory cache of offer chain per conversation so reloading the chat restores previous offers (API only returns latest).
    private static var offerHistoryCache: [String: [OfferInfo]] = [:]
    private static let offerHistoryUserDefaultsPrefix = "offerHistory_"
    /// Order of items in the chat (message vs offer card).
    @State private var timelineOrder: [TimelineEntry] = []
    private static var timelineOrderCache: [String: [TimelineEntry]] = [:]

    private static func persistOfferHistory(convId: String, offers: [OfferInfo]) {
        guard let data = try? JSONEncoder().encode(offers) else { return }
        UserDefaults.standard.set(data, forKey: offerHistoryUserDefaultsPrefix + convId)
    }

    private static func loadOfferHistory(convId: String) -> [OfferInfo]? {
        guard let data = UserDefaults.standard.data(forKey: offerHistoryUserDefaultsPrefix + convId),
              let offers = try? JSONDecoder().decode([OfferInfo].self, from: data) else { return nil }
        return offers
    }

    /// Current offer cards to show (history + current). Synced from displayedConversation.offer when it changes.
    private var offerCards: [OfferInfo] {
        if offerHistory.isEmpty, let offer = displayedConversation.offer {
            return [offer]
        }
        return offerHistory
    }
```

---

## 4. ChatDetailView – timeline row for offers (how cards are rendered)

```swift
        case .offer(let offerId):
            if let offer = offerCards.first(where: { $0.id == offerId }) {
                let isLatest = offer.id == offerCards.last?.id
                let prevIsOffer = (timelineIndex > 0 && timelineIndex - 1 < timelineOrder.count) && (timelineOrder[timelineIndex - 1].isOffer)
                let topPadding: CGFloat = timelineIndex == 0 ? 0 : (prevIsOffer ? 0 : Theme.Spacing.md)
                Group {
                    if timelineIndex > 0, timelineIndex - 1 < timelineOrder.count, timelineOrder[timelineIndex - 1].isOffer {
                        Rectangle()
                            .fill(Theme.Colors.glassBorder)
                            .frame(height: 0.5)
                    }
                    OfferCardView(
                        offer: offer,
                        currentUsername: authService.username,
                        isSeller: isSeller,
                        isResponding: isLatest ? isRespondingToOffer : false,
                        errorMessage: isLatest ? offerError : nil,
                        onAccept: { await handleRespondToOffer(action: "ACCEPT") },
                        onDecline: { await handleRespondToOffer(action: "REJECT") },
                        onSendNewOffer: { showCounterOfferSheet = true },
                        onPayNow: { presentPayNow() },
                        forceGreyedOut: !isLatest,
                        onRefresh: isLatest ? { loadConversationAndMessagesFromBackend() } : nil
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.background)
                    .id(isLatest ? "latest_offer_card" : offer.id)
                }
                .padding(.top, topPadding)
            }
```

---

## 5. ChatDetailView – sync and timeline build

```swift
    /// Restore offer chain from cache (memory or UserDefaults) when reloading chat; merge with server's latest offer so we keep previous cards.
    private func syncOfferHistoryFromConversation() {
        let convId = displayedConversation.id
        if Self.offerHistoryCache[convId] == nil, let persisted = Self.loadOfferHistory(convId: convId), !persisted.isEmpty {
            Self.offerHistoryCache[convId] = persisted.map { o in
                OfferInfo(id: o.id, status: o.status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date())
            }
        }
        guard let serverOffer = displayedConversation.offer else {
            let cached = Self.offerHistoryCache[convId] ?? []
            offerHistory = cached.map { o in OfferInfo(id: o.id, status: o.status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date()) }
            rebuildTimelineOrder()
            return
        }
        if let cached = Self.offerHistoryCache[convId], !cached.isEmpty {
            let lastIsSameOffer = cached.last?.id == serverOffer.id
                || (cached.last.map { abs($0.offerPrice - serverOffer.offerPrice) < 0.01 } == true)
            let serverAlreadyInCache = cached.contains { $0.id == serverOffer.id || $0.id.hasPrefix(serverOffer.id + "-") }
            let withTimestamp: (OfferInfo) -> OfferInfo = { o in
                OfferInfo(id: o.id, status: o.status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date())
            }
            let filled = cached.map(withTimestamp)
            if lastIsSameOffer {
                offerHistory = filled.dropLast() + [withTimestamp(serverOffer)]
            } else if serverAlreadyInCache {
                offerHistory = filled
            } else {
                offerHistory = filled + [withTimestamp(serverOffer)]
            }
            Self.persistOfferHistory(convId: convId, offers: offerHistory)
        } else if offerHistory.isEmpty {
            let withTs = OfferInfo(id: serverOffer.id, status: serverOffer.status, offerPrice: serverOffer.offerPrice, buyer: serverOffer.buyer, products: serverOffer.products, createdAt: serverOffer.createdAt ?? Date())
            offerHistory = [withTs]
            Self.persistOfferHistory(convId: convId, offers: offerHistory)
        }
        rebuildTimelineOrder()
    }

    /// Build timeline order by merging offers and messages and sorting by date so an offer sent after a message appears below it.
    private func rebuildTimelineOrder() {
        let offers = offerCards
        let msgs = displayedMessages
        var entries: [(Date, TimelineEntry)] = []
        for o in offers {
            entries.append((o.createdAt ?? .distantPast, .offer(o.id)))
        }
        for m in msgs {
            entries.append((m.timestamp, .message(m.id)))
        }
        entries.sort { $0.0 < $1.0 }
        timelineOrder = entries.map(\.1)
    }

    /// Update only the last offer card when the server pushes an offer update (e.g. declined). Never overwrite an optimistic or just-added (synthetic id) card with stale server data.
    private func syncLastOfferFromConversation() {
        guard let serverOffer = displayedConversation.offer else { return }
        let withTimestamp: (OfferInfo) -> OfferInfo = { o in
            OfferInfo(id: o.id, status: o.status, offerPrice: o.offerPrice, buyer: o.buyer, products: o.products, createdAt: o.createdAt ?? Date())
        }
        if offerHistory.isEmpty {
            offerHistory = [withTimestamp(serverOffer)]
            return
        }
        let lastIndex = offerHistory.count - 1
        let last = offerHistory[lastIndex]
        let lastIsOptimistic = last.id.hasPrefix("pending-")
        if lastIsOptimistic {
            return
        }
        if !lastIsOptimistic && last.id != serverOffer.id && last.id.contains("-") {
            return
        }
        let isLastSameOffer = last.id == serverOffer.id || lastIsOptimistic
        if isLastSameOffer {
            var next = offerHistory
            let keepNewCardId = last.id != serverOffer.id
            let useLastPriceAndTime = !lastIsOptimistic && abs(last.offerPrice - serverOffer.offerPrice) >= 0.01
            let updatedOffer: OfferInfo
            if keepNewCardId {
                updatedOffer = OfferInfo(id: last.id, status: serverOffer.status, offerPrice: serverOffer.offerPrice, buyer: serverOffer.buyer, products: serverOffer.products, createdAt: last.createdAt ?? Date())
            } else if useLastPriceAndTime {
                updatedOffer = OfferInfo(id: serverOffer.id, status: serverOffer.status, offerPrice: last.offerPrice, buyer: serverOffer.buyer, products: serverOffer.products, createdAt: last.createdAt ?? Date())
            } else {
                updatedOffer = withTimestamp(OfferInfo(id: serverOffer.id, status: serverOffer.status, offerPrice: serverOffer.offerPrice, buyer: serverOffer.buyer, products: serverOffer.products, createdAt: serverOffer.createdAt ?? last.createdAt))
            }
            next[lastIndex] = updatedOffer
            offerHistory = next
            Self.offerHistoryCache[displayedConversation.id] = offerHistory
            Self.persistOfferHistory(convId: displayedConversation.id, offers: offerHistory)
        }
    }
```

---

## 6. ChatDetailView – create new offer (after “Send new offer” when offer was rejected)

```swift
    private func handleCreateNewOffer(offerPrice: Double) async {
        guard let offer = displayedConversation.offer,
              let productIds = offer.products?.compactMap({ p in p.id.flatMap(Int.init) }),
              !productIds.isEmpty else {
            await MainActor.run { offerError = "Could not load product" }
            return
        }
        await MainActor.run {
            isRespondingToOffer = true
            offerError = nil
            let cards = offerCards
            let optimistic = OfferInfo(id: "pending-\(UUID().uuidString)", status: "PENDING", offerPrice: offerPrice, buyer: offer.buyer, products: offer.products, createdAt: Date())
            offerHistory = cards + [optimistic]
            timelineOrder.append(.offer(optimistic.id))
        }
        do {
            let (_, newConv) = try await productService.createOffer(offerPrice: offerPrice, productIds: productIds, message: nil)
            let convs = try await chatService.getConversations()
            await MainActor.run {
                let updated = convs.first(where: { $0.id == displayedConversation.id })
                var offerForDisplay = (newConv?.id == displayedConversation.id ? newConv?.offer : nil) ?? updated?.offer
                if offerForDisplay == nil || abs(offerForDisplay!.offerPrice - offerPrice) >= 0.01 {
                    let base = offerForDisplay ?? displayedConversation.offer
                    offerForDisplay = OfferInfo(id: base?.id ?? "new-\(UUID().uuidString)", status: base?.status ?? "PENDING", offerPrice: offerPrice, buyer: base?.buyer, products: base?.products)
                }
                if let updated = updated {
                    displayedConversation = Conversation(id: updated.id, recipient: updated.recipient, lastMessage: updated.lastMessage, lastMessageTime: updated.lastMessageTime, unreadCount: updated.unreadCount, offer: offerForDisplay ?? updated.offer, order: updated.order)
                }
                let serverOffer = offerForDisplay
                if let serverOffer = serverOffer, !offerHistory.isEmpty {
                    let previous = Array(offerHistory.dropLast())
                    let newCardId = "\(serverOffer.id)-\(UUID().uuidString)"
                    let newCard = OfferInfo(id: newCardId, status: serverOffer.status, offerPrice: offerPrice, buyer: serverOffer.buyer, products: serverOffer.products, createdAt: Date())
                    offerHistory = previous + [newCard]
                    Self.offerHistoryCache[displayedConversation.id] = offerHistory
                    Self.persistOfferHistory(convId: displayedConversation.id, offers: offerHistory)
                    if let last = timelineOrder.last, case .offer(let pid) = last, pid.hasPrefix("pending-") {
                        timelineOrder[timelineOrder.count - 1] = .offer(newCardId)
                    }
                }
                isRespondingToOffer = false
                offerError = nil
            }
        } catch {
            await MainActor.run {
                if !offerHistory.isEmpty { offerHistory = Array(offerHistory.dropLast()) }
                if let last = timelineOrder.last, case .offer(let pid) = last, pid.hasPrefix("pending-") { timelineOrder.removeLast() }
                isRespondingToOffer = false
                offerError = error.localizedDescription
            }
        }
    }
```

---

## 7. ChatDetailView – counter offer (Accept / Decline / Send new offer)

```swift
    private func handleRespondToOffer(action: String, offerPrice: Double? = nil) async {
        guard let offer = displayedConversation.offer, let offerId = offer.offerIdInt else { return }
        let isCounter = action == "COUNTER"
        let newPrice = offerPrice ?? offer.offerPrice
        if isCounter {
            await MainActor.run {
                let cards = offerCards
                let optimistic = OfferInfo(id: "pending-\(UUID().uuidString)", status: "PENDING", offerPrice: newPrice, buyer: offer.buyer, products: offer.products, createdAt: Date())
                offerHistory = cards + [optimistic]
                timelineOrder.append(.offer(optimistic.id))
            }
        }
        await MainActor.run {
            isRespondingToOffer = true
            offerError = nil
        }
        do {
            try await productService.respondToOffer(action: action, offerId: offerId, offerPrice: offerPrice)
            let convs = try await chatService.getConversations()
            await MainActor.run {
                if let updated = convs.first(where: { $0.id == displayedConversation.id }) {
                    displayedConversation = updated
                    if isCounter, let serverOffer = updated.offer {
                        if !offerHistory.isEmpty {
                            let previous = Array(offerHistory.dropLast())
                            let lastWasOptimistic = offerHistory.last?.id.hasPrefix("pending-") == true
                            if lastWasOptimistic {
                                let newCardId = "\(serverOffer.id)-\(UUID().uuidString)"
                                let newCard = OfferInfo(id: newCardId, status: serverOffer.status, offerPrice: newPrice, buyer: serverOffer.buyer, products: serverOffer.products, createdAt: Date())
                                offerHistory = previous + [newCard]
                                Self.offerHistoryCache[displayedConversation.id] = offerHistory
                                Self.persistOfferHistory(convId: displayedConversation.id, offers: offerHistory)
                                if let last = timelineOrder.last, case .offer(let pid) = last, pid.hasPrefix("pending-") {
                                    timelineOrder[timelineOrder.count - 1] = .offer(newCardId)
                                }
                            }
                        } else {
                            let withTs = OfferInfo(id: serverOffer.id, status: serverOffer.status, offerPrice: serverOffer.offerPrice, buyer: serverOffer.buyer, products: serverOffer.products, createdAt: serverOffer.createdAt ?? Date())
                            offerHistory = [withTs]
                            Self.offerHistoryCache[displayedConversation.id] = offerHistory
                            Self.persistOfferHistory(convId: displayedConversation.id, offers: offerHistory)
                        }
                    }
                }
                isRespondingToOffer = false
                offerError = nil
            }
        } catch {
            await MainActor.run {
                if isCounter, !offerHistory.isEmpty {
                    offerHistory = Array(offerHistory.dropLast())
                }
                if isCounter, let last = timelineOrder.last, case .offer(let pid) = last, pid.hasPrefix("pending-") {
                    timelineOrder.removeLast()
                }
                isRespondingToOffer = false
                offerError = error.localizedDescription
            }
        }
    }
```

---

## 8. ChatDetailView – sheet that sends a new offer

```swift
        .sheet(isPresented: $showCounterOfferSheet) {
            OptionsSheet(
                title: L10n.string("Send a new offer"),
                onDismiss: { showCounterOfferSheet = false },
                detents: item != nil ? [.height(480)] : [.height(340)],
                useCustomCornerRadius: false
            ) {
                OfferModalContent(
                    item: item,
                    listingPrice: nil,
                    onSubmit: { newPrice in
                        showCounterOfferSheet = false
                        Task {
                            if displayedConversation.offer?.isRejected == true {
                                await handleCreateNewOffer(offerPrice: newPrice)
                            } else {
                                await handleRespondToOffer(action: "COUNTER", offerPrice: newPrice)
                            }
                        }
                    },
                    onDismiss: { showCounterOfferSheet = false },
                    isSubmitting: $offerModalSubmitting,
                    errorMessage: $offerError
                )
            }
        }
```

---

## 9. OfferCardView (full struct)  
**File:** `Prelura-swift/Views/Chat/ChatDetailView.swift`

```swift
// MARK: - Offer card (Flutter OfferFirstCard)

struct OfferCardView: View {
    let offer: OfferInfo
    let currentUsername: String?
    let isSeller: Bool
    let isResponding: Bool
    let errorMessage: String?
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    let onSendNewOffer: () -> Void
    let onPayNow: () -> Void
    var forceGreyedOut: Bool = false
    var onRefresh: (() -> Void)? = nil

    private var offerLine: String {
        let priceStr = String(format: "£%.2f", offer.offerPrice)
        let isBuyer = offer.buyer?.username == currentUsername
        if isBuyer {
            return "You offered \(priceStr)"
        }
        return "\(offer.buyer?.username ?? "They") offered \(priceStr)"
    }

    private var statusText: String {
        switch (offer.status ?? "").uppercased() {
        case "PENDING": return "Pending"
        case "ACCEPTED": return "Accepted"
        case "REJECTED", "CANCELLED": return "Declined"
        default: return offer.status ?? "Pending"
        }
    }

    private var statusColor: Color {
        switch (offer.status ?? "").uppercased() {
        case "PENDING": return Theme.Colors.secondaryText
        case "ACCEPTED": return .green
        case "REJECTED", "CANCELLED": return .red
        default: return Theme.Colors.secondaryText
        }
    }

    private var shouldShowStatus: Bool {
        let s = (offer.status ?? "").uppercased()
        return s != "PENDING" && s != "COUNTERED"
    }

    private var isMyOffer: Bool { offer.buyer?.username == currentUsername }

    private static func relativeTimestamp(for date: Date) -> String {
        let now = Date()
        if now.timeIntervalSince(date) < 60 {
            return "Just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let str = formatter.localizedString(for: date, relativeTo: now)
        if str.hasPrefix("in ") { return "Just now" }
        return str
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(offerLine)
                .font(Theme.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.primaryText)
            if shouldShowStatus {
                Text(statusText)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(statusColor)
            }
            if let err = errorMessage, !err.isEmpty {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.red)
            }

            if forceGreyedOut {
                // Overwritten by a newer offer: hide "Send new offer" so only the latest card shows it.
            } else if isSeller && offer.isPending {
                VStack(spacing: Theme.Spacing.sm) {
                    Button(action: { Task { await onAccept() } }) {
                        Text("Accept")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(22)
                    }
                    .disabled(isResponding)
                    HStack(spacing: Theme.Spacing.sm) {
                        Button(action: { Task { await onDecline() } }) {
                            Text("Decline")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                                .foregroundColor(Theme.Colors.primaryText)
                                .cornerRadius(22)
                        }
                        .disabled(isResponding)
                        Button(action: onSendNewOffer) {
                            Text("Send new offer")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.primaryColor)
                                .foregroundColor(.white)
                                .cornerRadius(22)
                        }
                        .disabled(isResponding)
                    }
                }
            } else if !isSeller && offer.isPending {
                Button(action: onSendNewOffer) {
                    Text("Send new offer")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(22)
                }
                .disabled(isResponding)
            } else if !isSeller && offer.isAccepted {
                Button(action: onPayNow) {
                    Text("Pay now")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(22)
                }
            } else if offer.isRejected {
                Button(action: onSendNewOffer) {
                    Text("Send new offer")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(22)
                }
                .disabled(isResponding)
            } else if !isSeller && !offer.isAccepted {
                Button(action: onSendNewOffer) {
                    Text("Send new offer")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(22)
                }
                .disabled(isResponding)
            }

            if isResponding {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            HStack {
                Spacer(minLength: 0)
                if let onRefresh = onRefresh {
                    Button(action: onRefresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.trailing, Theme.Spacing.sm)
                }
                Text(offer.createdAt.map { Self.relativeTimestamp(for: $0) } ?? "—")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }
}
```

---

## 10. ChatDetailView – when sync and load run

```swift
        .onAppear {
            connectWebSocket()
            fetchOfferProductIfNeeded()
            fetchOrderProductIfNeeded()
            syncOfferHistoryFromConversation()
            loadConversationAndMessagesFromBackend()
        }
        .onChange(of: displayedConversation.offer) { _, _ in
            syncLastOfferFromConversation()
        }
        .onChange(of: displayedConversation.id) { _, _ in
            offerHistory = []
            timelineOrder = []
            syncOfferHistoryFromConversation()
        }
        .onDisappear {
            if !offerHistory.isEmpty {
                Self.offerHistoryCache[displayedConversation.id] = offerHistory
                Self.persistOfferHistory(convId: displayedConversation.id, offers: offerHistory)
            }
            // ...
        }
```

In `loadConversationAndMessagesFromBackend()`, after setting `displayedConversation` and `messages`, we call `syncOfferHistoryFromConversation()` then `rebuildTimelineOrder()` so the “Refresh” button on the latest card refetches and updates the displayed price.
d id 