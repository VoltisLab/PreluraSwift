# Menu & Settings – Flutter vs Swift integration gaps

This document lists the full menu/settings structure from the Flutter app and what is integrated (or still placeholder) in Swift. **Children and children-of-children** are included.

---

## 1. Top-level Menu (from Profile)

| Item | Flutter | Swift | Integration status |
|------|--------|--------|--------------------|
| Shop Value | `userEarningsProvider`, `userProvider.listing` | `UserService.getUserEarnings()`, `listingCount` from user | ✅ **Done** – earnings API + listing |
| Orders | `MyOrderRoute` → orders API | `MyOrdersView` | ⚠️ Verify orders API wired |
| Favourites | `MyFavouriteRoute` → favourites API | `MyFavouritesView` | ⚠️ Verify favourites API wired |
| Multi-buy discounts | `userMultiBuyDiscountProvider`, update mutation | `MultiBuyDiscountView` | ❌ **Placeholder** – UI only; need fetch + update API |
| Vacation Mode | `userProvider.isVacationMode`, `updateProfile(isVacationMode)` | `VacationModeView(initialIsOn:)` + `UserService.updateProfile(isVacationMode:)` | ✅ **Done** |
| Invite Friend | `InviteFriend` | `InviteFriendView` | ⚠️ Verify share/contacts if Flutter uses API |
| Help Centre | `HelpCentre` → FAQ + “Start a conversation” → `HelpChatView` | `HelpCentreView` → `HelpChatView` | ⚠️ FAQ/help content static; help chat may need backend |
| About Prelura | `AboutPreluraMenuRoute` | `AboutPreluraMenuView` | ✅ Structure done |
| Settings | `SettingRoute` | `SettingsMenuView` | ✅ Structure done |
| Logout | `authProvider.logout()` | `authService.logout()` | ✅ Done |

**Menu state from backend:**  
- `listingCount`, `isMultibuyEnabled`, `isVacationMode`, `isStaff` now come from `viewMe` (User) and are passed into `MenuView`.  
- Profile syncs `isMultiBuyEnabled` and `isVacationMode` from `viewModel.user` when user loads.

---

## 2. About Prelura (children)

| Item | Flutter | Swift | Integration status |
|------|--------|--------|--------------------|
| How to use Prelura | `onTap: () {}` (no route) | `HowToUsePreluraView` | ✅ Screen exists; content static |
| Legal Information | `LegalInformationRoute` | `LegalInformationView` | ✅ Done |
| (Push/Email in About – Flutter has duplicate items, not in Swift About) | - | - | - |

---

## 3. Legal Information (children of About)

| Item | Flutter | Swift | Integration status |
|------|--------|--------|--------------------|
| Terms & Conditions | `onTap: () {}` | `TermsAndConditionsView` | ⚠️ Static/Web |
| Privacy Policy | `onTap: () {}` | `PrivacyPolicyView` | ⚠️ Static/Web |
| Acknowledgements | `onTap: () {}` | `AcknowledgementsView` | ⚠️ Static/Web |
| HMRC reporting centre | `onTap: () {}` | `HMRCReportingView` | ⚠️ Static/Web |

---

## 4. Settings (children)

| Item | Flutter | Swift | Integration status |
|------|--------|--------|--------------------|
| Account Settings | `userProvider`, `updateProfile` (name, email, phone, dob, gender, bio), verify email | `AccountSettingsView` | ❌ **Needs** – load user + updateProfile mutation (and verify email if used) |
| Shipping Address | Shipping address API | `ShippingAddressView` | ❌ **Needs** – load/save shipping address API |
| Appearance | Appearance/theme | `AppearanceMenuView` | ⚠️ Likely local-only (theme) |
| Profile details | Profile settings (similar to account) | `ProfileSettingsView` | ❌ **Needs** – same as account or dedicated API |
| Payments | Payment methods API, Add card, Add bank | `PaymentSettingsView`, `AddPaymentCardView`, `AddBankAccountView` | ❌ **Needs** – list + add payment methods |
| Postage | Postage settings API | `PostageSettingsView` | ❌ **Needs** – postage API |
| Security & Privacy | Submenu | `SecurityMenuView` | ✅ Structure done |
| Identity verification | Verify flow (record video, etc.) | `VerifyIdentityView` | ❌ **Needs** – verification flow/API |
| Admin Actions (staff) | `AdminMenuRoute` | `AdminMenuView` | ✅ Shown when `isStaff`; actions may need APIs |
| Push notifications | `NotificationSettingRoute(title: "Push")` | `NotificationSettingsView(title: "Push")` | ❌ **Needs** – notification preferences API |
| Email notifications | `NotificationSettingRoute(title: "Email")` | `NotificationSettingsView(title: "Email")` | ❌ **Needs** – notification preferences API |
| Invite Friend | Same as menu | `InviteFriendView` | Same as menu |
| Log out | `authProvider.logout()` | Alert + `authService.logout()` | ✅ Done |

---

## 5. Security & Privacy (children of Settings)

| Item | Flutter | Swift | Integration status |
|------|--------|--------|--------------------|
| Blocklist | `BlockedUsersSettingsRoute` → blocked users API | `BlocklistView` | ❌ **Needs** – blocked users list + unblock API |
| Reset Password | `ResetPasswordRoute` | `ResetPasswordView` | ❌ **Needs** – reset password API |
| Delete Account | `DeleteAccount` | `DeleteAccountView` | ❌ **Needs** – delete account API |
| Pause Account | `PauseAccount` | `PauseAccountView` | ❌ **Needs** – pause account API |

---

## 6. Help Centre

| Item | Flutter | Swift | Integration status |
|------|--------|--------|--------------------|
| Search / FAQ cards | Static content, `onTap: () {}` | `HelpCentreView` (search + topics) | ⚠️ Static; can add deep links later |
| Start a conversation | `HelpChatView` | `HelpChatView` | ⚠️ Placeholder; may need support chat API |

---

## 7. Implemented in this pass

1. **ViewMe (getUser)**  
   - Added `isVacationMode`, `isMultibuyEnabled` to query.  
   - Added `isStaff` to response decoding (optional; backend may not send on `UserType`).  
   - `User` model extended with `isVacationMode`, `isMultibuyEnabled`.

2. **Shop Value**  
   - `UserService.getUserEarnings()` added (query `userEarnings`: networth, pendingPayments, completedPayments, earningsInMonth, totalEarnings).  
   - `ShopValueView` loads earnings on appear and refresh; shows listing count from parent.

3. **Vacation Mode**  
   - `UserService.updateProfile(isVacationMode:)` added.  
   - `VacationModeView` takes `initialIsOn`, calls API on toggle, shows error and reverts on failure.

4. **Profile → Menu state**  
   - `MenuView` receives `listingCount`, `isMultiBuyEnabled`, `isVacationMode`, `isStaff` from Profile.  
   - Profile syncs `isMultiBuyEnabled` and `isVacationMode` from `viewModel.user` when user loads.

---

## 8. Suggested next integrations (priority)

1. **Multi-buy discounts** – Fetch tiers (e.g. userMultiBuyDiscountProvider), update mutation; wire `MultiBuyDiscountView`.  
2. **Account Settings** – Load user (already have ViewMe), add updateProfile mutation for name, email, phone, dob, gender, bio; verify email if used.  
3. **Notification settings** – Load/save notification preferences API for Push and Email.  
4. **Blocklist** – Blocked users list + unblock API.  
5. **Orders / Favourites** – Confirm orders and favourites screens use the same APIs as Flutter.  
6. **Security actions** – Reset password, delete account, pause account APIs.  
7. **Payments / Postage** – List and add payment methods; postage settings API.

---

*Backend is shared; do not change GraphQL schema or API contracts. Add or use existing queries/mutations from the Flutter app.*
