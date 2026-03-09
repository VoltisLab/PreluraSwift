import Foundation
import Combine

@MainActor
class UserService: ObservableObject {
    private var client: GraphQLClient
    
    init(client: GraphQLClient? = nil) {
        self.client = client ?? GraphQLClient()
        // Try to load auth token from UserDefaults
        if let token = UserDefaults.standard.string(forKey: "AUTH_TOKEN") {
            self.client.setAuthToken(token)
        }
    }
    
    func updateAuthToken(_ token: String?) {
        client.setAuthToken(token)
    }
    
    func getUser(username: String? = nil) async throws -> User {
        let query = """
        query ViewMe {
          viewMe {
            id
            username
            displayName
            fullName
            profilePictureUrl
            bio
            email
            gender
            dob
            phone {
              countryCode
              number
            }
            location {
              locationName
            }
            listing
            noOfFollowing
            noOfFollowers
            isVacationMode
            isMultibuyEnabled
            reviewStats {
              noOfReviews
              rating
            }
            shippingAddress
          }
        }
        """
        
        let response: GetUserResponse = try await client.execute(
            query: query,
            responseType: GetUserResponse.self
        )
        
        guard let userData = response.viewMe else {
            throw UserError.userNotFound
        }
        
        // Extract location name from location object
        let locationName = userData.location?.locationName
        
        // Extract review stats
        let reviewCount = userData.reviewStats?.noOfReviews ?? 0
        let rating = userData.reviewStats?.rating ?? 5.0
        
        // Convert id to string
        let idString: String
        if let anyCodable = userData.id {
            if let intValue = anyCodable.value as? Int {
                idString = String(intValue)
            } else if let stringValue = anyCodable.value as? String {
                idString = stringValue
            } else {
                idString = String(describing: anyCodable.value)
            }
        } else {
            idString = ""
        }
        
        let phoneDisplay: String? = {
            guard let phone = userData.phone else { return nil }
            let code = phone.countryCode ?? ""
            let num = phone.number ?? ""
            if code.isEmpty && num.isEmpty { return nil }
            if code.isEmpty { return num }
            return "+\(code) \(num)"
        }()
        let dobDate: Date? = {
            guard let dob = userData.dob else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            if let d = formatter.date(from: dob) { return d }
            let fallback = DateFormatter()
            fallback.dateFormat = "yyyy-MM-dd"
            return fallback.date(from: dob)
        }()

        return User(
            id: UUID(uuidString: idString) ?? UUID(),
            username: userData.username ?? "",
            displayName: userData.displayName ?? "",
            avatarURL: userData.profilePictureUrl,
            bio: userData.bio,
            location: locationName,
            locationAbbreviation: extractLocationAbbreviation(from: locationName),
            rating: rating,
            reviewCount: reviewCount,
            listingsCount: userData.listing ?? 0,
            followingsCount: userData.noOfFollowing ?? 0,
            followersCount: userData.noOfFollowers ?? 0,
            isStaff: userData.isStaff ?? false,
            isVacationMode: userData.isVacationMode ?? false,
            isMultibuyEnabled: userData.isMultibuyEnabled ?? false,
            email: userData.email,
            phoneDisplay: phoneDisplay,
            dateOfBirth: dobDate,
            gender: userData.gender,
            shippingAddress: parseShippingAddress(userData.shippingAddress)
        )
    }
    
    /// Fetch current user's earnings (networth, balance, etc.) for Shop Value screen. Matches Flutter userRepo.getUserEarning().
    func getUserEarnings() async throws -> UserEarnings {
        let query = """
        query UserEarnings {
          userEarnings {
            networth
            pendingPayments { quantity value }
            completedPayments { quantity value }
            earningsInMonth { quantity value }
            totalEarnings { quantity value }
          }
        }
        """
        let response: UserEarningsResponse = try await client.execute(
            query: query,
            responseType: UserEarningsResponse.self
        )
        guard let data = response.userEarnings else {
            throw UserError.userNotFound
        }
        return UserEarnings(
            networth: data.networth ?? 0,
            pendingPayments: QuantityValue(quantity: data.pendingPayments?.quantity ?? 0, value: data.pendingPayments?.value ?? 0),
            completedPayments: QuantityValue(quantity: data.completedPayments?.quantity ?? 0, value: data.completedPayments?.value ?? 0),
            earningsInMonth: QuantityValue(quantity: data.earningsInMonth?.quantity ?? 0, value: data.earningsInMonth?.value ?? 0),
            totalEarnings: QuantityValue(quantity: data.totalEarnings?.quantity ?? 0, value: data.totalEarnings?.value ?? 0)
        )
    }
    
    /// Update profile. Matches Flutter userRepo.updateProfile(Variables$Mutation$UpdateProfile(...)).
    /// Pass only fields that changed; nil means don't update.
    func updateProfile(
        isVacationMode: Bool? = nil,
        displayName: String? = nil,
        gender: String? = nil,
        dob: Date? = nil,
        phoneNumber: (countryCode: String, number: String)? = nil,
        bio: String? = nil,
        shippingAddress: ShippingAddress? = nil
    ) async throws {
        let mutation = """
        mutation UpdateProfile(
          $isVacationMode: Boolean
          $displayName: String
          $gender: String
          $dob: String
          $phoneNumber: PhoneInputType
          $bio: String
          $shippingAddress: ShippingAddressInputType
        ) {
          updateProfile(
            isVacationMode: $isVacationMode
            displayName: $displayName
            gender: $gender
            dob: $dob
            phoneNumber: $phoneNumber
            bio: $bio
            shippingAddress: $shippingAddress
          ) {
            message
          }
        }
        """
        var variables: [String: Any] = [:]
        if let v = isVacationMode { variables["isVacationMode"] = v }
        if let v = displayName, !v.isEmpty { variables["displayName"] = v }
        if let v = gender, !v.isEmpty { variables["gender"] = v }
        if let d = dob {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            variables["dob"] = formatter.string(from: d)
        }
        if let p = phoneNumber {
            variables["phoneNumber"] = [
                "countryCode": p.countryCode,
                "number": p.number,
                "completed": "\(p.countryCode)\(p.number)"
            ]
        }
        if let v = bio { variables["bio"] = v }
        if let s = shippingAddress {
            variables["shippingAddress"] = [
                "address": s.address,
                "city": s.city,
                "country": s.country,
                "postcode": s.postcode
            ]
        }
        _ = try await client.execute(
            query: mutation,
            variables: variables.isEmpty ? nil : variables,
            responseType: UpdateProfileResponse.self
        )
    }

    /// Change email (backend sends verification). Matches Flutter changeEmail mutation.
    func changeEmail(_ email: String) async throws {
        let mutation = """
        mutation ChangeEmail($email: String) {
          changeEmail(email: $email) {
            message
          }
        }
        """
        _ = try await client.execute(
            query: mutation,
            variables: ["email": email],
            responseType: ChangeEmailResponse.self
        )
    }

    // MARK: - Security & Privacy (client-only; backend unchanged)

    /// Reset password. Matches Flutter passwordChange(oldPassword, newPassword).
    func passwordChange(currentPassword: String, newPassword: String) async throws {
        let mutation = """
        mutation PasswordChange($oldPassword: String!, $newPassword1: String!, $newPassword2: String!) {
          passwordChange(oldPassword: $oldPassword, newPassword1: $newPassword1, newPassword2: $newPassword2) {
            success
            errors
          }
        }
        """
        struct Payload: Decodable { let passwordChange: PasswordChangePayload? }
        struct PasswordChangePayload: Decodable { let success: Bool?; let errors: [String: String]? }
        let vars: [String: Any] = ["oldPassword": currentPassword, "newPassword1": newPassword, "newPassword2": newPassword]
        let response: Payload = try await client.execute(query: mutation, variables: vars, responseType: Payload.self)
        if response.passwordChange?.success != true, let err = response.passwordChange?.errors?.values.first {
            throw NSError(domain: "PasswordChange", code: -1, userInfo: [NSLocalizedDescriptionKey: err])
        }
    }

    /// Delete account. Matches Flutter deleteAccount(password).
    func deleteAccount(password: String) async throws {
        let mutation = """
        mutation DeleteAccount($password: String!) {
          deleteAccount(password: $password) {
            success
            errors
          }
        }
        """
        struct Payload: Decodable { let deleteAccount: DeleteAccountPayload? }
        struct DeleteAccountPayload: Decodable { let success: Bool?; let errors: [String: String]? }
        let response: Payload = try await client.execute(query: mutation, variables: ["password": password], responseType: Payload.self)
        if response.deleteAccount?.success != true, let err = response.deleteAccount?.errors?.values.first {
            throw NSError(domain: "DeleteAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: err])
        }
    }

    /// Pause (archive) account. Backend: archiveAccount(password).
    func archiveAccount(password: String) async throws {
        let mutation = """
        mutation ArchiveAccount($password: String!) {
          archiveAccount(password: $password) {
            success
            errors
          }
        }
        """
        struct Payload: Decodable { let archiveAccount: ArchiveAccountPayload? }
        struct ArchiveAccountPayload: Decodable { let success: Bool?; let errors: [String: String]? }
        let response: Payload = try await client.execute(query: mutation, variables: ["password": password], responseType: Payload.self)
        if response.archiveAccount?.success != true, let err = response.archiveAccount?.errors?.values.first {
            throw NSError(domain: "ArchiveAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: err])
        }
    }

    /// Fetch blocked users. Matches Flutter getBlockedUsers.
    func getBlockedUsers(pageNumber: Int = 1, pageCount: Int = 20, search: String? = nil) async throws -> [BlockedUser] {
        let query = """
        query BlockedUsers($pageNumber: Int, $pageCount: Int, $search: String) {
          blockedUsers(pageNumber: $pageNumber, pageCount: $pageCount, search: $search) {
            id
            username
            displayName
            profilePictureUrl
            thumbnailUrl
          }
          blockedUsersTotalNumber
        }
        """
        var vars: [String: Any] = ["pageNumber": pageNumber, "pageCount": pageCount]
        if let s = search, !s.isEmpty { vars["search"] = s }
        let response: BlockedUsersResponse = try await client.execute(query: query, variables: vars, responseType: BlockedUsersResponse.self)
        return (response.blockedUsers ?? []).compactMap { u in
            guard let id = u.id else { return nil }
            return BlockedUser(id: id, username: u.username ?? "", displayName: u.displayName ?? "", profilePictureUrl: u.profilePictureUrl, thumbnailUrl: u.thumbnailUrl)
        }
    }

    /// Unblock user. Matches Flutter blockUnblockUser(action: false) → blockUser: false.
    func unblockUser(userId: Int) async throws {
        let mutation = """
        mutation BlockUnblock($userId: Int!, $blockUser: Boolean!) {
          blockUnblock(userId: $userId, blockUser: $blockUser) {
            success
            message
          }
        }
        """
        struct Payload: Decodable { let blockUnblock: BlockUnblockPayload? }
        struct BlockUnblockPayload: Decodable { let success: Bool?; let message: String? }
        let response: Payload = try await client.execute(query: mutation, variables: ["userId": userId, "blockUser": false], responseType: Payload.self)
        if response.blockUnblock?.success != true {
            throw NSError(domain: "BlockUnblock", code: -1, userInfo: [NSLocalizedDescriptionKey: response.blockUnblock?.message ?? "Unblock failed"])
        }
    }

    // MARK: - Payment methods (fetch / add / delete; backend unchanged)

    /// Fetch current payment method. Matches Flutter getUserPaymentMethod (query userPaymentMethods).
    func getUserPaymentMethod() async throws -> PaymentMethod? {
        let query = """
        query UserPaymentMethods {
          userPaymentMethods {
            paymentMethodId
            last4Digits
            cardBrand
          }
        }
        """
        struct Payload: Decodable {
            let userPaymentMethods: RawPaymentMethod?
        }
        struct RawPaymentMethod: Decodable {
            let paymentMethodId: String?
            let last4Digits: String?
            let cardBrand: String?
        }
        let response: Payload = try await client.execute(query: query, variables: nil, responseType: Payload.self)
        guard let raw = response.userPaymentMethods,
              let id = raw.paymentMethodId, !id.isEmpty else {
            return nil
        }
        return PaymentMethod(
            paymentMethodId: id,
            last4Digits: raw.last4Digits ?? "••••",
            cardBrand: raw.cardBrand ?? "Card"
        )
    }

    /// Add payment method (Stripe payment method ID). Matches Flutter addPaymentMethod.
    func addPaymentMethod(paymentMethodId: String) async throws {
        let mutation = """
        mutation AddPaymentMethod($paymentMethodID: String!) {
          addPaymentMethod(paymentMethodId: $paymentMethodID) {
            success
          }
        }
        """
        struct Payload: Decodable { let addPaymentMethod: AddPaymentMethodPayload? }
        struct AddPaymentMethodPayload: Decodable { let success: Bool? }
        let response: Payload = try await client.execute(query: mutation, variables: ["paymentMethodID": paymentMethodId], responseType: Payload.self)
        if response.addPaymentMethod?.success != true {
            throw NSError(domain: "AddPaymentMethod", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to add payment method"])
        }
    }

    /// Delete payment method. Matches Flutter deletePaymentMethod.
    func deletePaymentMethod(paymentMethodId: String) async throws {
        let mutation = """
        mutation DeletePaymentMethod($paymentMethodID: String!) {
          deletePaymentMethod(paymentMethodId: $paymentMethodID) {
            success
            error
          }
        }
        """
        struct Payload: Decodable { let deletePaymentMethod: DeletePaymentMethodPayload? }
        struct DeletePaymentMethodPayload: Decodable { let success: Bool?; let error: String? }
        let response: Payload = try await client.execute(query: mutation, variables: ["paymentMethodID": paymentMethodId], responseType: Payload.self)
        if response.deletePaymentMethod?.success != true {
            throw NSError(domain: "DeletePaymentMethod", code: -1, userInfo: [NSLocalizedDescriptionKey: response.deletePaymentMethod?.error ?? "Failed to delete"])
        }
    }

    // MARK: - Multi-buy discounts (matches Flutter userMultibuyDiscounts / createMultibuyDiscount / deactivateMultibuyDiscounts)

    /// Fetch current user multi-buy discount tiers. userId nil = current user.
    func getMultibuyDiscounts(userId: Int? = nil) async throws -> [MultibuyDiscount] {
        let query = """
        query UserMultibuyDiscounts($userId: Int) {
          userMultibuyDiscounts(userId: $userId) {
            id
            minItems
            discountValue
            isActive
          }
        }
        """
        var variables: [String: Any] = [:]
        if let userId = userId { variables["userId"] = userId }
        struct Payload: Decodable {
            let userMultibuyDiscounts: [MultibuyDiscountRow]?
        }
        struct MultibuyDiscountRow: Decodable {
            let id: AnyCodable?
            let minItems: Int?
            let discountValue: DecimalStringOrNumber?
            let isActive: Bool?
        }
        let response: Payload = try await client.execute(query: query, variables: variables.isEmpty ? nil : variables, responseType: Payload.self)
        let rows = response.userMultibuyDiscounts ?? []
        return rows.compactMap { row in
            guard let minItems = row.minItems else { return nil }
            let idInt: Int? = row.id.flatMap { id in (id.value as? Int) ?? (id.value as? String).flatMap { Int($0) } }
            let valueStr = row.discountValue?.stringValue ?? "0"
            return MultibuyDiscount(
                id: idInt,
                minItems: minItems,
                discountValue: valueStr,
                isActive: row.isActive ?? true
            )
        }
    }

    /// Create or update multi-buy discount tiers. Each input: id nil = create, id set = update.
    func createOrUpdateMultibuyDiscount(inputs: [MultibuyDiscountInput]) async throws {
        let mutation = """
        mutation CreateMultibuyDiscount($inputs: [MultibuyInputType]!) {
          createMultibuyDiscount(inputs: $inputs) {
            success
          }
        }
        """
        let inputDicts: [[String: Any]] = inputs.map { input in
            var d: [String: Any] = [
                "minItems": input.minItems,
                "discountPercentage": input.discountPercentage,
                "isActive": input.isActive
            ]
            if let id = input.id { d["id"] = id }
            return d
        }
        struct Payload: Decodable {
            let createMultibuyDiscount: CreateMultibuyResult?
        }
        struct CreateMultibuyResult: Decodable {
            let success: Bool?
        }
        let response: Payload = try await client.execute(query: mutation, variables: ["inputs": inputDicts], responseType: Payload.self)
        if response.createMultibuyDiscount?.success != true {
            throw NSError(domain: "CreateMultibuyDiscount", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save multi-buy discounts"])
        }
    }

    // MARK: - User orders (matches Flutter userOrders query)

    /// Fetch orders for current user. isSeller true = Sold, false = Bought. Status filter is client-side (All / In Progress / Cancelled / Completed).
    func getUserOrders(isSeller: Bool, pageNumber: Int = 1, pageCount: Int = 50) async throws -> (orders: [Order], totalNumber: Int) {
        let query = """
        query UserOrders($filters: OrderFiltersInput, $pageCount: Int, $pageNumber: Int) {
          userOrders(filters: $filters, pageCount: $pageCount, pageNumber: $pageNumber) {
            id
            priceTotal
            discountPrice
            status
            createdAt
            updatedAt
            shippingAddress
            user { id username displayName profilePictureUrl }
            products { id name imagesUrl price }
          }
          userOrdersTotalNumber
        }
        """
        let filters: [String: Any] = ["isSeller": isSeller]
        let variables: [String: Any] = [
            "filters": filters,
            "pageCount": pageCount,
            "pageNumber": pageNumber
        ]
        struct Payload: Decodable {
            let userOrders: [OrderRow]?
            let userOrdersTotalNumber: Int?
        }
        struct OrderRow: Decodable {
            let id: AnyCodable?
            let priceTotal: String?
            let discountPrice: String?
            let status: String?
            let createdAt: String?
            let updatedAt: String?
            let shippingAddress: String?
            let user: OrderUserRow?
            let products: [OrderProductRow]?
        }
        struct OrderUserRow: Decodable {
            let id: AnyCodable?
            let username: String?
            let displayName: String?
            let profilePictureUrl: String?
        }
        struct OrderProductRow: Decodable {
            let id: AnyCodable?
            let name: String?
            let imagesUrl: [String]?
            let price: String?
        }
        let response: Payload = try await client.execute(query: query, variables: variables, responseType: Payload.self)
        let rows = response.userOrders ?? []
        let orders = rows.compactMap { row -> Order? in
            guard let idVal = row.id?.value else { return nil }
            let idStr = (idVal as? Int).map { String($0) } ?? (idVal as? String) ?? String(describing: idVal)
            let otherParty: User? = row.user.map { u in
                User(
                    username: u.username ?? "",
                    displayName: u.displayName ?? "",
                    avatarURL: u.profilePictureUrl
                )
            }
            let products: [OrderProductSummary] = (row.products ?? []).compactMap { p -> OrderProductSummary? in
                let pid = (p.id?.value as? Int).map { String($0) } ?? (p.id?.value as? String)
                guard let pid = pid else { return nil }
                var imgUrl: String?
                if let first = p.imagesUrl?.first,
                   let data = first.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let url = json["url"] as? String {
                    imgUrl = url
                }
                return OrderProductSummary(id: String(describing: pid), name: p.name ?? "", imageUrl: imgUrl, price: p.price)
            }
            let createdAt = Self.parseCreatedAt(row.createdAt) ?? Date()
            return Order(
                id: idStr,
                priceTotal: row.priceTotal ?? "0",
                status: row.status ?? "",
                createdAt: createdAt,
                otherParty: otherParty,
                products: products,
                shippingAddress: parseShippingAddress(row.shippingAddress)
            )
        }
        let total = response.userOrdersTotalNumber ?? 0
        return (orders, total)
    }

    /// Turn off all multi-buy discounts for the current user.
    func deactivateMultibuyDiscounts() async throws {
        let mutation = """
        mutation DeactivateMultibuyDiscounts {
          deactivateMultibuyDiscounts {
            success
          }
        }
        """
        struct Payload: Decodable {
            let deactivateMultibuyDiscounts: DeactivateResult?
        }
        struct DeactivateResult: Decodable {
            let success: Bool?
        }
        let response: Payload = try await client.execute(query: mutation, responseType: Payload.self)
        if response.deactivateMultibuyDiscounts?.success != true {
            throw NSError(domain: "DeactivateMultibuyDiscounts", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to turn off multi-buy discounts"])
        }
    }

    /// Parse shippingAddress from ViewMe (JSONString – JSON string from API).
    private func parseShippingAddress(_ value: String?) -> ShippingAddress? {
        guard let str = value, !str.isEmpty,
              let data = str.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return ShippingAddress(
            address: json["address"] as? String ?? "",
            city: json["city"] as? String ?? "",
            state: json["state"] as? String,
            country: json["country"] as? String ?? "GB",
            postcode: json["postcode"] as? String ?? ""
        )
    }

    private func extractLocationAbbreviation(from location: String?) -> String? {
        guard let location = location else { return nil }
        // Extract abbreviation (e.g., "London, United Kingdom" -> "LDN")
        let components = location.split(separator: ",")
        if let firstComponent = components.first {
            let words = firstComponent.split(separator: " ")
            if words.count > 1 {
                return words.compactMap { String($0.prefix(1)).uppercased() }.joined()
            }
            return String(firstComponent.prefix(3)).uppercased()
        }
        return nil
    }
    
    func getUserProducts(username: String? = nil) async throws -> [Item] {
        let query = """
        query UserProducts($username: String) {
          userProducts(username: $username) {
            id
            name
            description
            price
            discountPrice
            imagesUrl
            condition
            createdAt
            size {
              id
              name
            }
            brand {
              id
              name
            }
            customBrand
            likes
            views
            userLiked
            seller {
              id
              username
              displayName
              profilePictureUrl
            }
            category {
              id
              name
            }
          }
        }
        """
        
        var variables: [String: Any] = [:]
        if let username = username {
            variables["username"] = username
        }
        
        let response: UserProductsResponse = try await client.execute(
            query: query,
            variables: variables.isEmpty ? nil : variables,
            responseType: UserProductsResponse.self
        )
        
        guard let products = response.userProducts else {
            return []
        }
        
        return products.compactMap { product in
            // Convert id to string
            let idString: String
            if let anyCodable = product.id {
                if let intValue = anyCodable.value as? Int {
                    idString = String(intValue)
                } else if let stringValue = anyCodable.value as? String {
                    idString = stringValue
                } else {
                    idString = String(describing: anyCodable.value)
                }
            } else {
                return nil
            }
            
            // Extract image URLs from imagesUrl array
            let imageURLs = extractImageURLs(from: product.imagesUrl)
            
            // Extract seller id
            let sellerIdString: String
            if let sellerId = product.seller?.id {
                if let intValue = sellerId.value as? Int {
                    sellerIdString = String(intValue)
                } else if let stringValue = sellerId.value as? String {
                    sellerIdString = stringValue
                } else {
                    sellerIdString = String(describing: sellerId.value)
                }
            } else {
                sellerIdString = ""
            }
            
            // Parse discountPrice (it's a percentage string, e.g., "20" for 20% off)
            let originalPrice = product.price ?? 0.0
            let discountPercentage: Double? = {
                guard let discountPriceStr = product.discountPrice,
                      let discount = Double(discountPriceStr),
                      discount > 0 else {
                    return nil
                }
                return discount
            }()
            
            // Calculate final price: if discount exists, apply it; otherwise use original price
            let finalPrice: Double
            let itemOriginalPrice: Double?
            if let discount = discountPercentage {
                // Calculate discounted price: originalPrice - (originalPrice * discount / 100)
                finalPrice = originalPrice - (originalPrice * discount / 100)
                itemOriginalPrice = originalPrice
            } else {
                finalPrice = originalPrice
                itemOriginalPrice = nil
            }
            
            return Item(
                id: UUID(uuidString: idString) ?? UUID(),
                productId: idString,
                title: product.name ?? "",
                description: product.description ?? "",
                price: finalPrice,
                originalPrice: itemOriginalPrice,
                imageURLs: imageURLs,
                category: Category.fromName(product.category?.name ?? ""),
                categoryName: product.category?.name, // Store actual category name from API (subcategory)
                seller: User(
                    id: UUID(uuidString: sellerIdString) ?? UUID(),
                    username: product.seller?.username ?? "",
                    displayName: product.seller?.displayName ?? "",
                    avatarURL: product.seller?.profilePictureUrl
                ),
                condition: product.condition ?? "",
                size: product.size?.name,
                brand: product.brand?.name ?? product.customBrand,
                likeCount: product.likes ?? 0,
                views: product.views ?? 0,
                createdAt: Self.parseCreatedAt(product.createdAt) ?? Date(),
                isLiked: product.userLiked ?? false
            )
        }
    }
    
    private static func parseCreatedAt(_ iso8601: String?) -> Date? {
        guard let s = iso8601 else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: s) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)
    }
    
    private func extractImageURLs(from imagesUrl: [String]?) -> [String] {
        guard let imagesUrl = imagesUrl else { return [] }
        var urls: [String] = []
        for imageJson in imagesUrl {
            // imagesUrl contains JSON strings like '{"url":"...","thumbnail":"..."}'
            // Try to parse as JSON string
            if let data = imageJson.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let url = json["url"] as? String, !url.isEmpty {
                        urls.append(url)
                    }
                } catch {
                    // If JSON parsing fails, try using the string directly as URL (fallback)
                    // This handles cases where imagesUrl might already contain direct URLs
                    if !imageJson.isEmpty && (imageJson.hasPrefix("http://") || imageJson.hasPrefix("https://")) {
                        urls.append(imageJson)
                    }
                }
            } else {
                // If data conversion fails, try using the string directly as URL (fallback)
                if !imageJson.isEmpty && (imageJson.hasPrefix("http://") || imageJson.hasPrefix("https://")) {
                    urls.append(imageJson)
                }
            }
        }
        return urls
    }
}

struct GetUserResponse: Decodable {
    let viewMe: UserProfileData?
}

struct UserProfileData: Decodable {
    let id: AnyCodable?
    let username: String?
    let displayName: String?
    let fullName: String?
    let profilePictureUrl: String?
    let bio: String?
    let email: String?
    let gender: String?
    let dob: String?  // ISO date string from API
    let phone: UserPhoneData?
    let shippingAddress: String?  // JSONString from API (JSON string)
    let location: LocationData?
    let listing: Int?
    let noOfFollowing: Int?
    let noOfFollowers: Int?
    let isVacationMode: Bool?
    let isMultibuyEnabled: Bool?
    let isStaff: Bool?
    let reviewStats: ReviewStatsData?
}

struct UserPhoneData: Decodable {
    let countryCode: String?
    let number: String?
}

/// Shipping address (from ViewMe or for updateProfile). Backend input uses address, city, country, postcode only.
struct ShippingAddress: Hashable {
    var address: String
    var city: String
    var state: String?
    var country: String
    var postcode: String
}

struct LocationData: Decodable {
    let locationName: String?
}

struct ReviewStatsData: Decodable {
    let noOfReviews: Int?
    let rating: Double?
}

// Helper to decode Any type (for id which can be String or Int)
// Made public so it can be used in other services
public struct AnyCodable: Decodable {
    public let value: Any
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }
}

/// Decodes GraphQL Decimal as either String or number.
private struct DecimalStringOrNumber: Decodable {
    let stringValue: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            stringValue = s
        } else if let n = try? c.decode(Double.self) {
            stringValue = String(Int(n))
        } else if let n = try? c.decode(Int.self) {
            stringValue = String(n)
        } else {
            throw DecodingError.typeMismatch(DecimalStringOrNumber.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or number for Decimal"))
        }
    }
}

struct UserProductsResponse: Decodable {
    let userProducts: [ProductData]?
}

struct UserEarnings {
    let networth: Double
    let pendingPayments: QuantityValue
    let completedPayments: QuantityValue
    let earningsInMonth: QuantityValue
    let totalEarnings: QuantityValue
}

struct QuantityValue {
    let quantity: Int
    let value: Double
}

struct UserEarningsResponse: Decodable {
    let userEarnings: UserEarningsData?
}

struct UserEarningsData: Decodable {
    let networth: Double?
    let pendingPayments: QuantityValueData?
    let completedPayments: QuantityValueData?
    let earningsInMonth: QuantityValueData?
    let totalEarnings: QuantityValueData?
}

struct QuantityValueData: Decodable {
    let quantity: Int?
    let value: Double?
}

struct UpdateProfileResponse: Decodable {
    let updateProfile: UpdateProfilePayload?
}

struct UpdateProfilePayload: Decodable {
    let message: String?
}

struct ChangeEmailResponse: Decodable {
    let changeEmail: ChangeEmailPayload?
}

struct ChangeEmailPayload: Decodable {
    let message: String?
}

/// One multi-buy discount tier (minItems → discount %). Matches MultibuyDiscountType.
struct MultibuyDiscount {
    let id: Int?
    let minItems: Int
    let discountValue: String
    let isActive: Bool
}

/// Input for createMultibuyDiscount mutation. id = nil for create, non-nil for update.
struct MultibuyDiscountInput {
    let id: Int?
    let minItems: Int
    let discountPercentage: String
    let isActive: Bool
}

/// Order from userOrders query. Used in My Orders list and detail.
struct Order: Identifiable {
    let id: String
    let priceTotal: String
    let status: String
    let createdAt: Date
    let otherParty: User?
    let products: [OrderProductSummary]
    let shippingAddress: ShippingAddress?
}

/// Product summary inside an order.
struct OrderProductSummary: Identifiable {
    let id: String
    let name: String
    let imageUrl: String?
    let price: String?
}

/// Payment method from userPaymentMethods query.
struct PaymentMethod {
    let paymentMethodId: String
    let last4Digits: String
    let cardBrand: String
}

/// Blocked user from blockedUsers query.
struct BlockedUser: Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let profilePictureUrl: String?
    let thumbnailUrl: String?
}

struct BlockedUsersResponse: Decodable {
    let blockedUsers: [BlockedUserRow]?
    let blockedUsersTotalNumber: Int?
}

struct BlockedUserRow: Decodable {
    let id: Int?
    let username: String?
    let displayName: String?
    let profilePictureUrl: String?
    let thumbnailUrl: String?
}

// Reuse ProductData, SizeData, BrandData, SellerData, CategoryData from ProductService
// These are defined in ProductService.swift

enum UserError: Error, LocalizedError {
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        }
    }
}
