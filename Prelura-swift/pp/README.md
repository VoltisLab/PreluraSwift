# iPad & Mac (iOS app on Mac) — UI design checklist

**Always consider iPad and the Mac (iOS app on Mac) when designing UI features** — not only iPhone portrait. Treat wide windows, split view, and Finder-based file access as first-class, not an afterthought.

The app ships as an **iPhone** binary and is also run on **iPad** and as an **iOS app on macOS** (“Designed for iPad” on Mac). New features should be validated on **all three** surfaces, not only a narrow phone portrait window.

## Layout & breakpoints

- **Do not rely on `horizontalSizeClass == .regular` alone** for “tablet” rules. Sheets, popovers, and some nested flows often report **compact** width on iPad or on Mac even when the window is wide.
- Prefer **`UIDevice` idiom** and **`ProcessInfo.processInfo.isiOSAppOnMac`** where we need consistent grids or sheet body width. See `WearhouseLayoutMetrics.swift`:
  - Centered root column on wide layouts
  - `wearhouseSheetContentColumnIfWide()` for modal/sheet **content** so forms do not stretch edge-to-edge
  - `wearhouseChatThreadReadableWidthIfPadMac()` for chat-style columns
  - Product / lookbook **grid column counts** driven by idiom (and Mac), not only size class

## Images: Photos vs Finder on Mac

- On **iPhone and iPad**, `PhotosPicker` / `.photosPicker` are appropriate.
- On **Mac (iOS app on Mac)**, the system often steers users toward the **Photos** library only. For flows where users expect **files from disk** (Finder), use:
  - `IOSAppOnMacImageImport` and `.macOnlyImageFileImporter(...)` in `IOSAppOnMacImageImport.swift`
- **Only attach** the Finder/`fileImporter` path when `ProcessInfo.processInfo.isiOSAppOnMac` is true (handled inside `macOnlyImageFileImporter`). Do not show that path on iPhone/iPad.

When adding **any new** “choose photo / attachment” flow, copy an existing pattern (e.g. Sell listing photos, profile photo, lookbook upload, reports) or extend the helper so Mac users always get Finder where we’ve standardized on it.

## Practical QA

- **iPad**: portrait, landscape, split view / Stage Manager (if available), and sheets over split content.
- **Mac**: resizable window; confirm sheets and forms stay readable; confirm image picking uses Finder where implemented.

Keeping this in mind upfront avoids shipping phone-only layouts and Mac-hostile pickers.

## What’s already wired in the codebase

- **Readable columns & sheets**: `WearhouseLayoutMetrics.swift` and modifiers on major tabs, sheets, chat, and checkout.
- **Mac image picking from Finder**: `IOSAppOnMacImageImport.swift` on sell, profile, lookbook upload, background replacer, and order/report help flows (iPhone/iPad still use Photos).

New screens should **reuse these patterns** instead of introducing unconstrained full-width phone layouts or Photos-only pickers on Mac.
