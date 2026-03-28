# Flutter vs Swift: Pages and Integrations Gap List

Reference: plan audit. No backend/GraphQL changes; client-only.

## 1. Tab structure

- [ ] Decide: Search tab vs Discover (Flutter has Search tab; Swift has Discover)

## 2. Auth and onboarding

- [x] OnboardingRoute – OnboardingView (welcome flow)
- [x] VerifyUserRoute (`/verify/:token`) – VerifyUserView
- [x] LoginRoute, SignUpRoute – LoginView, SignupView
- [x] ForgotPasswordRoute – ForgotPasswordView
- [x] EmailSentRoute – EmailSentView (and inline in ForgotPasswordView)
- [x] NewPasswordRoute – NewPasswordView
- [x] ResetPasswordRoute (logged-in) – ResetPasswordView

## 3. Sell flow

- [x] Sell item + Category, Brand, Condition, Colours, etc. – SellView + sub-views
- [ ] DraftsRoute – upload from drafts / standalone drafts list parity
- [ ] DiscountRoute – confirm parity with DiscountPriceInputView

## 4. Product and listing

- [x] ProductDetailRoute – ItemDetailView
- [x] Filter/product list routes – FilteredProductsView
- [ ] ProductByHashtagRoute, Vintage/Party/Christmas filtered – themed/hashtag screens
- [ ] ProductsByStatusRoute – products by status (draft/active)
- [ ] OfferMuiltibuyView – full offer multi-buy screen (Swift has SendOfferSheet only)

## 5. Chat and inbox

- [x] InboxRoute – ChatListView (search added)
- [x] ChatRoute – human-readable preview for order/offer/order_issue in list
- [x] OrderHelpRoute – OrderHelpView (from chat ? button)
- [x] ItemNotAsDescribedHelpRoute – ItemNotAsDescribedHelpView
- [x] SellerOrderIssueDetailsRoute – SellerOrderIssueDetailsView
- [ ] DisputeDetailsRoute – confirm or add if missing
- [x] OrderDetailsRoute, CancelAnOrderRoute, RefundOrderRoute – OrderDetailView, CancelOrderView, RefundOrderView

## 6. Profile and user

- [x] ProfileDetailsRoute, UserProfileDetailsRoute – UserProfileView
- [x] MenuRoute – MenuView
- [x] FollowersRoute, FollowingRoute – FollowersListView, FollowingListView
- [ ] ReviewRoute – leave review after transaction
- [ ] FavouriteBrandsProductsRoute – favourite brands products list

## 7. Payments and checkout

- [x] PaymentRoute – PaymentView (checkout)
- [x] PaymentSuccessfulRoute – PaymentSuccessfulView
- [x] PaymentSettings, AddPaymentCard, AddBankAccount – present

## 8. Settings and account

- [x] SettingRoute, Account, Shipping, Legal, Holiday, NotificationSetting – present
- [x] NotificationsRoute – NotificationsListView
- [x] BlockedUsers, Security, ResetPassword, Pause, Delete – present
- [x] CurrencySettingRoute – CurrencySettingsView
- [x] PrivacySettingRoute – PrivacySettingsView
- [ ] VerifyEmailRoute – verify email screen (separate from VerifyUserView if needed)
- [x] BalanceRoute – ShopValueView (earnings/balance)
- [ ] DraftsRoute – standalone drafts list (if different from sell)

## 9. Help and support

- [x] HelpCentre, HelpChatView – present
- [x] ReportAccountHomepage, ReportAccountOptionsRoute – ReportUserView (from profile flag)

## 10. Verification and identity

- [x] VerifyYourIdentity entry – VerifyIdentityView
- [ ] UploadIdentityDocument, DisplayCapturedDocument – document upload/capture
- [ ] CountryRegionsView – country/region selection for verification
- [ ] VerifyVideo, RecordVideo, SubmitVideo – video verification flow

## 11. Integration / UX alignment

- [x] Chat list: human-readable message previews for order/offer/order_issue
- [ ] Item detail: Send offer API and success/error handling
- [ ] Sell page: photo empty state, Colours row styling (see SELL_PAGE_INTEGRATION_LIST.md)
- [ ] Theme/design consistency (primary colour, typography, components)
