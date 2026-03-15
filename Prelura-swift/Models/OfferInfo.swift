import Foundation

/// Offer data from createOffer response or conversations query. Used for offer card in chat.
struct OfferInfo: Decodable, Hashable {
    let id: String
    let status: String?
    let offerPrice: Double
    let buyer: OfferUser?
    let products: [OfferProduct]?

    struct OfferUser: Decodable, Hashable {
        let username: String?
        let profilePictureUrl: String?
    }

    struct OfferProduct: Decodable, Hashable {
        let id: String?
        let name: String?
        let seller: OfferUser?
    }

    enum CodingKeys: String, CodingKey {
        case id, status, offerPrice, buyer, products
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idAny = try c.decode(AnyCodable.self, forKey: .id)
        id = idAny.value as? String ?? String(describing: idAny.value)
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
    }

    init(id: String, status: String?, offerPrice: Double, buyer: OfferUser?, products: [OfferProduct]?) {
        self.id = id
        self.status = status
        self.offerPrice = offerPrice
        self.buyer = buyer
        self.products = products
    }

    var offerIdInt: Int? { Int(id) }
    var isPending: Bool { (status ?? "").uppercased() == "PENDING" }
    var isAccepted: Bool { (status ?? "").uppercased() == "ACCEPTED" }
    var isRejected: Bool { (status ?? "").uppercased() == "REJECTED" || (status ?? "").uppercased() == "CANCELLED" }
}
