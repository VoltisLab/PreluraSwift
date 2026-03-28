# Firebase + FCM for the Swift app

**Signing / push in this repo:** The Xcode project already sets **Automatic** signing, **development team**, **APNs entitlements** (`Prelura-swift*.entitlements`), and **Background Modes → Remote notifications**. Command-line device build: `./scripts/ios-device-build.sh`.

## Critical: same Firebase project as your API

If **Flutter gets offer/chat pushes but the Swift app does not**, the usual cause is **two different Firebase projects**:

- The **backend** sends notifications with **one** Firebase Admin / FCM project (the one Flutter uses).
- The Swift app’s **`GoogleService-Info.plist`** must be from **that same project** (same `PROJECT_ID` / `GCM_SENDER_ID` as Flutter’s iOS app for this bundle ID).

FCM tokens are **scoped to the Firebase project** that generated them. A token from project A **cannot** receive messages sent with credentials for project B.

**Fix:** Add the iOS app (`com.prelura.preloved`) to the **same** Firebase project the server uses, download **`GoogleService-Info.plist`**, and place it at `Prelura-swift/GoogleService-Info.plist`. After a clean install, log in and check the Xcode console for `[Push] updateProfile(fcmToken:) succeeded.` and `[Push] Firebase PROJECT_ID=…` matching the server’s project.

You can still keep analytics or other tooling separate elsewhere; **push delivery for server-sent FCM requires plist + server to match.**

---

## Migrating off the legacy Flutter Firebase project (delete or abandon)

**If you no longer have access** to the old Firebase/Google Cloud project, you **cannot delete it yourself**. Only an owner (or someone with project delete rights) on that Google account can remove it. Options: recover that account, or ask whoever still has access to delete it or add you. Until then, treat the old project as **unreachable** and move forward with one you control.

**Do not delete (or shut down) the old project until the backend has cut over.** If the API still authenticates to Firebase Admin using the old project’s service account, deleting that project will **stop all server-driven pushes** until credentials are updated.

**Recommended order:**

1. **Pick the canonical Firebase project** — the one your team controls (e.g. the Swift app’s project). Same place you already put `GoogleService-Info.plist` for `com.prelura.preloved`.
2. **In that project:** register the iOS app (if needed), upload the **APNs `.p8`** key under **Project settings → Cloud Messaging** (see §3 below).
3. **On the server:** switch Firebase Admin / FCM to a **service account JSON from this canonical project** (replace env vars, secrets, or key file). Deploy. Until this is done, Swift tokens from the new project will not receive API-sent notifications.
4. **Apps:** Swift already uses the canonical plist. Any **remaining Flutter** builds must use **`google-services.json` / plist from the same canonical project** if you still ship Flutter; if Swift-only, only the Swift plist matters.
5. **Users:** stored `fcmToken` rows from the **old** project are useless to the **new** sender. After cutover, users need to **open the app once** (logged in) so `updateProfile(fcmToken:)` registers a new token. Plan a short window where pushes may be missed until clients refresh.
6. **Then:** delete the legacy project in [Firebase Console](https://console.firebase.google.com/) → project settings → *Delete project* (if you have access), or simply **leave it unused**. Deletion is optional once nothing production depends on it.

This repo has no server code; whoever runs your API must perform step 3.

---

## 1. Optional: separate Firebase project (analytics only)

Only use a **second** Firebase project if you do **not** rely on it for **server-driven** push. For a standalone analytics experiment:

1. Open [Firebase Console](https://console.firebase.google.com/) and sign in.
2. **Add project** → choose a name.
3. Disable Google Analytics if you do not need it (matches current plist flags).

## 2. Register the iOS app

1. In the project overview, click **Add app** → **iOS**.
2. **Apple bundle ID** must match Xcode exactly:

   `com.prelura.preloved`

   (Bundle ID is fixed in the project as `com.prelura.preloved`.)

3. App nickname optional (e.g. `Prelura Swift`).
4. Download **`GoogleService-Info.plist`** and place it at:

   `Prelura-swift/GoogleService-Info.plist`

5. Replace any old plist. **Do not commit** this file (it is gitignored; use `GoogleService-Info.plist.example` as a reference).

## 3. Enable Cloud Messaging (FCM) — upload APNs key

The Swift app uses **Firebase Cloud Messaging** for device tokens (`AppDelegate` + `FirebaseMessaging`).

APNs upload lives under **Project settings**, not the left “Build” menu.

1. Open [Firebase Console](https://console.firebase.google.com/) and select your project (e.g. `marketplace-5e657`).
2. Click the **gear icon** next to **Project Overview** → **Project settings**.
3. Open the **Cloud Messaging** tab (top row of tabs: General, Cloud Messaging, …).
4. Scroll to **Apple app configuration** → **APNs authentication key** → **Upload** your **`.p8`** key (development and/or production). You need at least one.

**Direct link** (replace if your project id differs):  
`https://console.firebase.google.com/project/marketplace-5e657/settings/cloudmessaging`

Create the key in [Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list) if you don’t have one (enable **Apple Push Notifications service (APNs)**). Use an **APNs Auth Key** (`.p8`) plus Key ID and Team ID in Firebase.

Without this step, the app may still run, but **FCM tokens / push from Firebase** will not work reliably.

## 4. Quick test: “does push work?” (ignore campaigns)

**Publishing a campaign** targets an *audience* (often tied to Analytics). That is **not** the same as checking your own phone once.

Do only this:

1. **Run the app** from Xcode (Debug). Tap **Allow** when iOS asks for notifications.
2. In the **Xcode console**, find the line: **`[FCM TEST] Copy this token into Firebase…`** — copy the **long token** (one line, no spaces).
3. In Firebase: open **[Notifications composer](https://console.firebase.google.com/project/marketplace-5e657/notification)** → **New notification** → enter title + body → find **Send test message** (usually on the **right** / preview area, *before* you fully publish to everyone) → paste the token → **Test**.

Then **background the app** (home button / swipe up) so the banner can show.

If you never see **Send test message**, try **Engage → Messaging** in the left nav and look for test / preview options on the compose screen.

## 5. Backend / server (if you send pushes from your API)

- Your **backend** must use the **same** FCM project when it calls Firebase Admin to send notifications to iOS devices (or you map tokens per environment).
- If the API still points at the **old** Flutter Firebase project, either:
  - migrate sending logic to the new project’s service account, or  
  - run **two** environments (staging Swift vs production Flutter) until you cut over.

This repo does not contain server code; coordinate with whoever owns the GraphQL / notification service.

### GitHub secrets: do you need to change them?

| Where | Firebase-related secrets? |
|-------|---------------------------|
| **This repo (`PreluraIOS`)** | **No** — there are no `.github/workflows` in this project, and `GoogleService-Info.plist` is not committed. Local/Xcode builds use the plist on disk. **Only if you add CI** (e.g. GitHub Actions) that builds the app would you optionally add a secret such as a base64-encoded `GoogleService-Info.plist` and write it during the job. |
| **Backend repo** (`VoltisLab/prelura-app`) | **Yes, when you cut over.** FCM is wired in `utils/firebase_service.py` via **python-decouple** env vars (not a single JSON file in repo). Deploy workflow **`.github/workflows/deploy-to-uat.yml`** injects these **GitHub Actions secrets** into `.env` on the server: |

**GitHub secrets to refresh from the new Firebase service account JSON**

| Secret | JSON field |
|--------|------------|
| `GOOGLE_CRED_TYPE` | `type` (usually `service_account`) |
| `GOOGLE_CRED_PROJECT_ID` | `project_id` |
| `GOOGLE_CRED_PRIVATE_KEY_ID` | `private_key_id` |
| `GOOGLE_CRED_PRIVATE_KEY` | `private_key` — paste **verbatim**; newlines often stored as `\n` in GitHub (code does `.replace("\\n", "\n")`) |
| `GOOGLE_CRED_CLIENT_MAIL` | `client_email` |
| `GOOGLE_CRED_CLIENT_ID` | `client_id` |
| `GOOGLE_CRED_AUTH_URI` | `auth_uri` |
| `GOOGLE_CRED_TOKEN_URI` | `token_uri` |
| `GOOGLE_CRED_AUTH_CERT` | `auth_provider_x509_cert_url` |
| `GOOGLE_CRED_CLIENT_CERT` | `client_x509_cert_url` |
| `GOOGLE_CRED_UNIVERSE_DOMAIN` | `universe_domain` (often `googleapis.com`) |

If any of these are missing or still `placeholder_*`, logs show *Firebase credentials not configured* or *Firebase not initialized - skipping notification* and **no push is sent**. After updating secrets, redeploy (`main` → self-hosted workflow).

**Places:** Firebase Console → Project settings → **Service accounts** → Generate new private key → map fields into the secrets above. Upload **APNs `.p8`** in the **same** Firebase project (Cloud Messaging tab).

## 6. Run the app

1. `GoogleService-Info.plist` is inside the `Prelura-swift` folder (file-system synced with the target).
2. **Xcode:** open the project and run (⌘R). **Terminal:** `./scripts/ios-device-build.sh` then install/run from Xcode, or pass a device destination if you use `xcodebuild` + `devicectl`.
3. Invalid plist or bundle mismatch usually crashes immediately at `FirebaseApp.configure()` — check the console.

## 7. Common mistakes

| Issue | Fix |
|--------|-----|
| `BUNDLE_ID` in plist ≠ Xcode bundle ID | Re-download plist after registering the correct bundle ID in Firebase. |
| Push works on Android/old app but not Swift | Server or Firebase project mismatch; use new FCM credentials for the new project. |
| Lost access to old Firebase | Creating a **new** project (this doc) is correct; you cannot recover plist from the repo if it was never committed. |

## 8. Push troubleshooting checklist (Swift vs Flutter)

1. **Firebase → Project settings → General (PreluraSwift / `com.prelura.preloved`)**  
   Add **Team ID** (same as Apple Developer team, e.g. from your distribution profile). Optional but recommended.

2. **Firebase → Cloud Messaging**  
   Confirm **APNs authentication key (.p8)** is uploaded for the project (one key covers all iOS apps under your Apple team).

3. **Apple Developer → Identifiers**  
   App ID **`com.prelura.preloved`** must have **Push Notifications** enabled (separate from Flutter’s `com.prelura.app`).

4. **Same FCM project as the API**  
   Server `GOOGLE_CRED_PROJECT_ID` must be **`prelura-app`** (same as `PROJECT_ID` in `GoogleService-Info.plist`). In Django admin, confirm the user has **FCM tokens** listed after login on the Swift app (`updateProfile(fcmToken:)` success in logs).

5. **Isolate Firebase vs API**  
   Copy the FCM token from Xcode (`[FCM TEST]` in Debug) or Menu → Debug → Push diagnostics, then **Firebase → send test message** with the app **backgrounded**. If the test fails, fix Apple/Firebase/signing first.

6. **Chat messages and “presence”**  
   The API skips chat FCM when the receiver appears in the WebSocket room cache `chat_<conversationId>`. The Swift app now **disconnects the chat socket when the app backgrounds** so you are not stuck “in the room” after leaving the thread. Server logs: `Skipping chat push: receiver_id=…` means this path fired. To **always** send chat FCM regardless of presence, set env **`CHAT_SUPPRESS_PUSH_IF_RECEIVER_IN_ROOM=false`** (Django) and redeploy.

7. **Shared cache in production**  
   Use **Redis** for `CACHES` (not LocMem) so GraphQL workers and Channels see the same `chat_*` presence keys.

## Related files in this repo

| File | Purpose |
|------|--------|
| `Prelura-swift/AppDelegate.swift` | `FirebaseApp.configure()`, FCM delegate |
| `Prelura-swift/GoogleService-Info.plist` | **Local only** — from Firebase Console |
| `Prelura-swift/GoogleService-Info.plist.example` | Template / keys reference (no secrets) |

If you still maintain a Flutter app, its Firebase config must use the **same canonical project** as the API (see migration section above). If Prelura is **Swift-only**, ignore Flutter config; only `Prelura-swift/GoogleService-Info.plist` needs to match the server.
