import Foundation

struct User: Identifiable, Hashable {
    let id: UUID
    /// Backend numeric user id when available (e.g. from order.otherParty); used for rateUser, blockUnblock, etc.
    let userId: Int?
    let username: String
    let displayName: String
    let avatarURL: String?
    let bio: String?
    let location: String?
    let locationAbbreviation: String? // e.g., "LDN" for London
    let memberSince: Date
    let rating: Double
    let reviewCount: Int
    let listingsCount: Int
    let followingsCount: Int
    let followersCount: Int
    /// When true, show Admin Actions in Settings. Backend can set via isStaff/isSuperuser.
    let isStaff: Bool
    /// When true, email has been verified (from viewMe isVerified).
    let isVerified: Bool
    let isVacationMode: Bool
    let isMultibuyEnabled: Bool
    /// Account settings (from ViewMe)
    let email: String?
    let phoneDisplay: String?
    let dateOfBirth: Date?
    let gender: String?
    /// Shipping address (from ViewMe, JSONString).
    let shippingAddress: ShippingAddress?
    /// When viewing another user's profile: true if current user follows them (from getUser isFollowing).
    let isFollowing: Bool?
    /// Seller postage options (from viewMe/seller meta). Used at checkout to show delivery options.
    let postageOptions: SellerPostageOptions?

    init(
        id: UUID = UUID(),
        userId backendUserId: Int? = nil,
        username: String,
        displayName: String,
        avatarURL: String? = nil,
        bio: String? = nil,
        location: String? = nil,
        locationAbbreviation: String? = nil,
        memberSince: Date = Date(),
        rating: Double = 5.0,
        reviewCount: Int = 0,
        listingsCount: Int = 0,
        followingsCount: Int = 0,
        followersCount: Int = 0,
        isStaff: Bool = false,
        isVerified: Bool = false,
        isVacationMode: Bool = false,
        isMultibuyEnabled: Bool = false,
        email: String? = nil,
        phoneDisplay: String? = nil,
        dateOfBirth: Date? = nil,
        gender: String? = nil,
        shippingAddress: ShippingAddress? = nil,
        isFollowing: Bool? = nil,
        postageOptions: SellerPostageOptions? = nil
    ) {
        self.id = id
        self.userId = backendUserId
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.bio = bio
        self.location = location
        self.locationAbbreviation = locationAbbreviation
        self.memberSince = memberSince
        self.rating = rating
        self.reviewCount = reviewCount
        self.listingsCount = listingsCount
        self.followingsCount = followingsCount
        self.followersCount = followersCount
        self.isStaff = isStaff
        self.isVerified = isVerified
        self.isVacationMode = isVacationMode
        self.isMultibuyEnabled = isMultibuyEnabled
        self.email = email
        self.phoneDisplay = phoneDisplay
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.shippingAddress = shippingAddress
        self.isFollowing = isFollowing
        self.postageOptions = postageOptions
    }
    
    var formattedRating: String {
        String(format: "%.1f", rating)
    }
}

// Sample data
extension User {
    static let sampleUser = User(
        username: "Maddison2525",
        displayName: "Maddison",
        avatarURL: "https://i.pravatar.cc/150?img=68",
        bio: "Welcome to my wardrobe, all items are shipped from a clean, smoke free and reputable home. If you have any questions, please, reach out, thanks!",
        location: "London, United Kingdom",
        locationAbbreviation: "LDN",
        memberSince: Date().addingTimeInterval(-365 * 24 * 60 * 60),
        rating: 5.0,
        reviewCount: 300,
        listingsCount: 2025,
        followingsCount: 10,
        followersCount: 1000,
        isStaff: false,
        isVacationMode: false,
        isMultibuyEnabled: false
    )
    
    static let sampleUsers: [User] = [
        sampleUser,
        User(
            username: "vintageshop",
            displayName: "Emma Wilson",
            avatarURL: "avatar2",
            bio: "Curating unique vintage pieces",
            location: "Manchester, UK",
            locationAbbreviation: "MCR",
            rating: 4.9,
            reviewCount: 203,
            listingsCount: 1500,
            followingsCount: 25,
            followersCount: 5000,
            isVacationMode: false,
            isMultibuyEnabled: false
        ),
        User(
            username: "stylefinder",
            displayName: "James Brown",
            avatarURL: "avatar3",
            bio: "Designer pieces at affordable prices",
            location: "Birmingham, UK",
            locationAbbreviation: "BHM",
            rating: 4.7,
            reviewCount: 89,
            listingsCount: 800,
            followingsCount: 15,
            followersCount: 3000,
            isVacationMode: false,
            isMultibuyEnabled: false
        )
    ]
}
