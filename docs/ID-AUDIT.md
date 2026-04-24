# ID types across the app

Audit of all ID-like fields and `Identifiable` types: type (String / Int / UUID), where they come from (backend vs local), and an example value.

---

## 1. Product / item IDs

| Name | Type | Where used | Backend / local | Example |
|------|------|------------|-----------------|--------|
| **Item.id** | `UUID` | SwiftUI `Identifiable`, navigation, grids | **Local (derived)** | `00000000-0000-0000-0000-000000000001` |
| | | Built from `productId` via `Item.id(fromProductId:)` so the same product always has the same UUID. | | |
| **Item.productId** | `String?` | API calls (toggleLike, getProduct, delete, report), deep links, URLs | **Backend** | `"12345"` |
| | | Backend GraphQL uses **Int** for product; app keeps it as **String** (e.g. `"12345"`) and parses to `Int` when calling API. | | |
| **ProductService.getProduct(id:)** | `Int` | Fetch single product (deep link, notification) | **Backend** | `12345` |
| **ProductService.deleteProduct(productId:)** | `Int` | Delete listing | **Backend** | `12345` |
| **ProductService.updateProductStatus(productId:, status:)** | `Int` | Mark as sold | **Backend** | `12345` |
| **ProductService.likeProduct(productId:)** | `Int` | Like product | **Backend** | `12345` |
| **ProductService.toggleLike(productId:, isLiked:)** | `productId: String` | Toggle like; converted to Int for API | **Backend (String in app)** | `"12345"` |
| **ProductService.reportProduct(productId:, reason:, content:)** | `productId: String` | Report product | **Backend** | `"12345"` |
| **ProductService.addToRecentlyViewed(productId:)** | `Int` | Recently viewed | **Backend** | `12345` |
| **ProductService.getSimilarProducts(productId:, categoryId:, ...)** | `productId: String` | Similar products; API expects Int in variables | **Backend** | `"12345"` |
| **ProductService.createOffer(..., productIds:)** | `[Int]` | Create offer (multi-buy) | **Backend** | `[12345, 67890]` |
| **ProductService.createOrder(productId:, productIds:, ...)** | `productId: Int?`, `productIds: [Int]?` | Create order | **Backend** | `12345` or `[12345, 67890]` |
| **LookbookTagData.productId** | `String` | Tag on lookbook image; used to resolve Item and call getProduct(id: Int) | **Backend (String)** | `"12345"` |
| **LookbookTagData.id** | `String` (computed) | `Identifiable` | **Local** | `"12345_0.5_0.3"` (`productId_x_y`) |

---

## 2. User IDs

| Name | Type | Where used | Backend / local | Example |
|------|------|------------|-----------------|--------|
| **User.id** | `UUID` | SwiftUI `Identifiable`, equality | **Local (from backend string)** | `550e8400-e29b-41d4-a716-446655440000` |
| | | Built from backend `id` (Int or String) via `UUID(uuidString: idString) ?? UUID()`. | | |
| **User.userId** | `Int?` | rateUser, blockUnblock, getMultibuyDiscounts, order.otherParty | **Backend** | `42` |
| **UserService.followUser(followedId:)** | `Int` | Follow user | **Backend** | `42` |
| **UserService.unfollowUser(followedId:)** | `Int` | Unfollow | **Backend** | `42` |
| **UserService.unblockUser(userId:)** | `Int` | Unblock | **Backend** | `42` |
| **UserService.rateUser(..., orderId:, rating:, userId:)** | `userId: Int` | Rate seller/buyer | **Backend** | `42` |
| **BlockedUser.id** | `Int` | Blocked users list | **Backend** | `42` |

---

## 3. Order IDs

| Name | Type | Where used | Backend / local | Example |
|------|------|------------|-----------------|--------|
| **Order.id** | `String` | Order list/detail, cancelOrder, generateShippingLabel, confirmShipping, createPaymentIntent, rateUser | **Backend** | `"98765"` |
| | | API uses **Int** (e.g. cancelOrder(orderId: Int)); app stores as **String** and parses `Int(order.id)` when calling. | | |
| **CreateOrderResult.orderId** | `String` | Returned after createOrder; then parsed to Int for payment | **Backend** | `"98765"` |
| **CreateOrderDeliveryDetails** | (N/A) | Order creation payload | - | - |
| **Message.orderID** | `String?` | Order reference in chat message | **Backend** | `"98765"` |
| **Message.SoldConfirmationData.orderId** | `Int?` | Parsed from JSON in message content | **Backend** | `98765` |
| **UserService.cancelOrder(orderId:, ...)** | `Int` | Cancel order | **Backend** | `98765` |
| **UserService.createPaymentIntent(orderId:, paymentMethodId:)** | `orderId: Int`, `paymentMethodId: String` | Payment | **Backend** | `98765`, `"pm_xxx"` |
| **UserService.generateShippingLabel(orderId:)** | `Int` | Shipping label | **Backend** | `98765` |
| **UserService.confirmShipping(orderId:, ...)** | `Int` | Confirm shipping | **Backend** | `98765` |
| **ChatService.createSoldConfirmationMessage(orderId:)** | `Int` | Sold confirmation in chat | **Backend** | `98765` |

---

## 4. Offer / conversation / chat IDs

| Name | Type | Where used | Backend / local | Example |
|------|------|------------|-----------------|--------|
| **ProductService.respondToOffer(action:, offerId:, offerPrice:)** | `offerId: Int` | Accept/reject offer | **Backend** | `111` |
| **ProductService.createOffer(...)** returns | `conversationId: Int?` | Open chat after offer | **Backend** | `222` |
| **Conversation.id** | `String` | Chat list, getMessages, sendMessage, deleteConversation, WebSocket URL | **Backend** | `"222"` |
| | | Backend expects **Int**; app keeps **String** and passes `Int(conversationId)` to API. | | |
| **ChatService.getMessages(conversationId:)** | `String` | Load messages | **Backend (String in app)** | `"222"` |
| **ChatService.sendMessage(conversationId:, message:, messageUuid:)** | `conversationId: String` (converted to Int for API) | Send message | **Backend** | `"222"` |
| **ChatService.deleteConversation(conversationId:)** | `Int` | Delete conversation | **Backend** | `222` |
| **ChatWebSocketService(conversationId:, token:)** | `String` | WebSocket path | **Backend** | `"222"` |

---

## 5. Message IDs

| Name | Type | Where used | Backend / local | Example |
|------|------|------------|-----------------|--------|
| **Message.id** | `UUID` | SwiftUI `Identifiable`, list | **Local (or from backend)** | `UUID()` |
| **Message.backendId** | `Int?` | Mark-as-read API | **Backend** | `333` |
| **MessageData.id** (Decodable) | `AnyCodable?` | GraphQL response | **Backend** | (Int or String) |

---

## 6. Category IDs

| Name | Type | Where used | Backend / local | Example |
|------|------|------------|-----------------|--------|
| **Category.id** (app model) | `UUID` | Home/Discover category pills (static list) | **Local** | `UUID()` |
| **APICategory.id** | `String` | categories(parentId) response; decoded from Int or String | **Backend** | `"10"` or `"Men"` |
| **CategoriesService.fetchCategories(parentId:)** | `parentId: Int?` | Root or children | **Backend** | `nil` or `10` |
| **SellCategory.id** | `String` | Sell flow category selection; full path via pathIds | **Backend** | `"123"` |
| **CategoryPathEntry.id** | `String` | Category path for search/sell | **Backend** | `"123"` |
| **CategoryGroup.id** | `Int` | User product grouping (by category/brand) | **Backend** | `5` |
| **FilteredProductsViewModel.selectedCategoryId** | `Int?` | Shop All filter | **Backend** | `10` |

---

## 7. Search history IDs

| Name | Type | Where used | Backend / local | Example |
|------|------|------------|-----------------|--------|
| **SearchHistoryItem.id** | `String` | Identifiable, deleteSearchHistory | **Backend** | `"sh_abc123"` (opaque from API) |
| **SearchHistoryService.deleteSearchHistory(searchId:, clearAll:)** | `searchId: String` | Delete one or all | **Backend** | `"sh_abc123"` |

---

## 8. Notification / review IDs

| Name | Type | Where used | Backend / local | Example |
|------|------|------------|-----------------|--------|
| **AppNotification.id** | `String` | Identifiable, list | **Backend** | `"notif_xyz"` |
| **AppNotification.modelId** | `String?` | Link to product/order/etc. | **Backend** | `"12345"` |
| **UserReview.id** | `String` | Identifiable | **Backend** | `"rev_1"` |

---

## 9. Payment / other

| Name | Type | Where used | Backend / local | Example |
|------|------|------------|-----------------|--------|
| **PaymentMethod.paymentMethodId** | `String` | Create payment intent, confirm payment | **Backend (Stripe-like)** | `"pm_1234567890"` |
| **OrderProductSummary.id** | `String` | Product line in order | **Backend** | `"12345"` (product id as string) |
| **CreateOrderResult.orderId** | `String` | After createOrder | **Backend** | `"98765"` |

---

## 10. Local-only / UI IDs

| Name | Type | Where used | Example |
|------|------|------------|--------|
| **LookbookEntry.id** | `UUID` | Identifiable, z-order in lookbook grid | `UUID()` |
| **LookbookUploadRecord.id** | `String` | Draft/upload record; UUID().uuidString when creating | `"A1B2C3D4-E5F6-..."` |
| **LookbookTagProductsView.imageId** | `String` | Key for tags store; same as record id or `"draft"` | `"A1B2C3D4-..."` or `"draft"` |
| **ThemeBackground.id** | `String` | Theme key (white, grey, mint, …) | `"mint"`, `"lavender"` |
| **ShopInfo.id** | `UUID` | Identifiable (Discover) | `UUID()` |
| **ChatMessage.id** (AIChatView) | `UUID` | Identifiable | `UUID()` |
| **MeasurementRow.id** (SellView) | `UUID` | Identifiable | `UUID()` |

---

## Summary table (backend-facing IDs)

| ID kind | App type (typical) | GraphQL / API type | Example |
|--------|--------------------|--------------------|--------|
| Product | `String` (then `Int` for API) | Int | `"12345"` → `12345` |
| User | `Int` (userId), `UUID` (id from backend string) | Int | `42`, UUID from `"42"` or backend UUID |
| Order | `String` (then `Int` for API) | Int | `"98765"` → `98765` |
| Offer | `Int` | Int | `111` |
| Conversation | `String` (then `Int` for API) | Int | `"222"` → `222` |
| Category (API) | `String` (APICategory.id) or `Int` (parentId) | Int or String | `"10"`, `10` |
| Search history | `String` | String | `"sh_abc123"` |
| Notification | `String` | String | `"notif_xyz"` |
| Payment method | `String` | String | `"pm_xxx"` |

---

*Generated from codebase audit. Backend is read-only; IDs match existing GraphQL schema and Flutter app usage.*
