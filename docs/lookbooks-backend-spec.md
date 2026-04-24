# Lookbooks Backend Spec (prelura-app)

**Repository:** [github.com/VoltisLab/prelura-app](https://github.com/VoltisLab/prelura-app)

This document was written as an implementation checklist; the **`lookbooks`** app in that repo already includes `LookbookPost`, `createLookbook`, `lookbooks` / `lookbookPost` queries, likes, and comments. **Product tag pins and style pills are not stored server-side** (no models/fields yet)-only the iOS client keeps those locally.

This document describes the backend changes required in **prelura-app** so the Swift (and other) clients can store and fetch lookbooks on the server. The Swift app is already implemented to call this API and falls back to local-only when the API is not yet available.

---

## 1. Settings

**File:** `src/settings.py`

- Add upload type:
  ```python
  LOOKBOOK = "LOOKBOOK"
  ```
- Add `LOOKBOOK` to the list used by upload (see step 2).

---

## 2. File upload (existing mutation)

**File:** `non_modular_schema/enums/non_modular_enums.py`

- Add to `FileTypeEnum`:
  ```python
  LOOKBOOK = settings.LOOKBOOK
  ```

**File:** `non_modular_schema/mutations/non_modular_mutations.py`

- In `UploadPictures.mutate`, add `settings.LOOKBOOK` to `valid_filetypes`.

**File:** `utils/upload_utils.py`

- In `upload_file`, ensure `upload_type == settings.LOOKBOOK` is handled like PRODUCT (thumbnail, S3 key `lookbook/{folder}/{file_uuid}.jpeg`, etc.) so the upload returns the same shape (e.g. `image`, `thumbnail` in the response dict).

---

## 3. Django model

**App:** Create a new app `lookbooks` or add to an existing app (e.g. `products` or `non_modular`).

**Model:** `LookbookPost` (or `Lookbook`)

| Field         | Type              | Notes                          |
|---------------|-------------------|--------------------------------|
| id            | UUID (PK)         |                                |
| user          | ForeignKey(User)   | who posted                     |
| image_url     | URLField          | full image URL from upload     |
| thumbnail_url | URLField (null=True) | optional thumbnail           |
| caption       | TextField(blank=True) | optional caption            |
| created_at    | DateTimeField     | auto_now_add=True              |

- Optional: `likes_count`, `comments_count` if you want to support likes/comments on the server later (Swift currently uses local state for likes).

---

## 4. GraphQL

### 4.1 Type

**LookbookPostType** (or equivalent name):

- `id` (ID)
- `imageUrl` (String)
- `thumbnailUrl` (String, optional)
- `caption` (String, optional)
- `username` (String, from `user.username`)
- `createdAt` (DateTime)
- Optionally: `likesCount`, `commentsCount`, `userLiked` for future use.
- **`taggedProductCount`** (Int, optional, default `0`): number of **distinct** products tagged on the post. The iOS Lookbook **grid** shows a bag badge using this field so **all viewers** see it, not only the device that uploaded (local tag pins are not synced otherwise).
- **`productTags`**: list of pins - `productId`, `x`, `y` (0–1), `imageIndex`, `clientId` (optional). Persisted server-side so **all viewers** see tap targets.
- **`productSnapshots`**: list of `{ productId, title, imageUrl }` for pin thumbnails (also stored as JSON on the post).

### 4.2 Mutation: createLookbook

**Arguments:**

- `imageUrl`: String! (required) - URL returned from the existing `upload` mutation with `fileType: LOOKBOOK`.
- `caption`: String (optional).
- `tags`: optional list of `LookbookTagInput` (`productId`, `x`, `y`, `imageIndex`, `clientId`) - sent by current iOS on upload.
- `productSnapshots`: optional list of `LookbookProductSnapshotInput` (`productId`, `title`, `imageUrl`).

### 4.2.2 Mutation: updateLookbookPost

- `postId`: UUID!, `caption`: String (optional / null to clear) - caption edit for the post owner.

### 4.2.3 Mutation: setLookbookProductTags

- `postId`: UUID!, `tags`, optional `productSnapshots` - replace all pins on the author’s post (optional; iOS may use later for edit).

**Returns:** LookbookPostType (or a wrapper with `lookbookPost` and `success`/`message`).

**Behaviour:** Create a `LookbookPost` for the current user with the given `imageUrl` and `caption`. Use `@login_required` (or your auth decorator).

### 4.2.1 Mutation: updateLookbookPost (iOS caption edit)

**Arguments:**

- `postId`: UUID! - existing post owned by the current user.
- `caption`: String (optional) - set to `null` to clear the caption.

**Returns:** Same shape as `createLookbook` (`lookbookPost`, `success`, `message`).

**Behaviour:** Update only the caption; reject if the post does not belong to the caller.

### 4.3 Query: lookbooks

**Arguments (optional):**

- `first`: Int (e.g. 20)
- `after`: String (cursor for pagination)

**Returns:** A connection or list of LookbookPostType, ordered by `created_at` descending (newest first).

**Behaviour:** Return lookbooks for the current user and/or all users (depending on product decision). Swift expects a list of posts with `id`, `imageUrl`, `caption`, `username`, `createdAt`.

---

## 5. Swift client expectations

The Swift app will:

1. **Upload image:** Call existing `upload` mutation with `fileType: LOOKBOOK` (same multipart pattern as profile/product). Parse response to get the single image URL (same structure as existing upload response).
2. **Create lookbook:** Call `createLookbook(imageUrl: String!, caption: String)` with the URL from step 1.
3. **Fetch feed:** Call `lookbooks` query and map the result to the in-app feed model.

Until these exist, the app uses local-only storage and shows an empty server feed; once you deploy the backend per this spec, the Swift app will use the server without further client changes.

### 5.1 Upload flow (what actually hits the network)

1. **Multipart upload** - `POST` to the GraphQL upload endpoint (`Constants.graphQLUploadURL`) with `fileType: LOOKBOOK` and `operations` / `map` / file part `0` (see `LookbookService.uploadLookbookImage`). The app expects JSON in the upload payload with an `image` path and combines it with `baseUrl` into a full URL string.
2. **Create post** - GraphQL mutation `CreateLookbook` with variables `imageUrl` (required) and optional `caption` (string omitted when empty). The mutation selection set asks for `lookbookPost { id imageUrl thumbnailUrl caption … }`.
3. **Local-only today (not in GraphQL)** - **Style pills** and **product tags** (pin positions + product ids + thumbnails) are saved in app `UserDefaults` via `LookbookFeedStore` after upload. They are **not** sent in `createLookbook`. Other devices or a fresh install will not see tags/styles until the API stores them. **Captions** must be returned on `lookbookPost` and on each node in the `lookbooks` query or the feed will only show caption when the same device still has a matching local record.

### 5.2 Verifying a deployment

- After posting, inspect the `createLookbook` response: `lookbookPost.caption` should echo the submitted caption.
- Call `lookbooks` (or equivalent) and confirm each `LookbookPost` includes `caption` when set.
- If captions are always `null` in responses, the resolver is not persisting or not exposing the field even if the mutation accepts it.

---

## 6. Checklist

- [ ] `LOOKBOOK` in settings and FileTypeEnum
- [ ] Upload mutation and upload_utils accept LOOKBOOK
- [ ] LookbookPost model and migrations
- [ ] LookbookPostType and createLookbook mutation
- [ ] lookbooks query
- [ ] Register mutation/query in main schema (e.g. `src/schemas.py` or your schema root)
