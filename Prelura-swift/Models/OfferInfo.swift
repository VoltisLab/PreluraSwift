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
