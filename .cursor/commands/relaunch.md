# Relaunch (iPhone 14 + iPhone 14 Alt)

**`/relaunch` and `/relaunch-both` are the same flow:** one Debug build, then install and launch on **iPhone 14** and **iPhone 14 Alt** (create **iPhone 14 Alt** if missing and your workflow needs both).

**Build:** Use `-destination 'generic/platform=iOS Simulator'` so the build succeeds even when named simulators use different iOS versions than `OS:latest`.

When the user runs `/relaunch`, follow these steps:

1. **Rebuild (once for both simulators)**
   - Always run a fresh build first so neither simulator runs an old build.
   - From the iOS project root (folder containing `Prelura-swift.xcodeproj`):  
     `xcodebuild -project Prelura-swift.xcodeproj -scheme Prelura-swift -destination 'generic/platform=iOS Simulator' -configuration Debug build`
   - Monitor build output until **BUILD SUCCEEDED** or fix errors.
   - Resolve `<path-to-.app>` from the log or:  
     `~/Library/Developer/Xcode/DerivedData/Prelura-swift-<hash>/Build/Products/Debug-iphonesimulator/Prelura-swift.app`

2. **Ensure iPhone 14 Alt exists (optional but recommended for `/relaunch-both`)**
   - If `xcrun simctl list devices available | grep -F "iPhone 14 Alt"` is empty, create a second iPhone 14–class device with that name using an available iOS runtime, or report and still complete iPhone 14 below.

3. **iPhone 14** — boot, terminate, install, launch  
   - `xcrun simctl boot "iPhone 14" 2>/dev/null || true`  
   - `xcrun simctl terminate "iPhone 14" com.prelura.preloved 2>/dev/null || true`  
   - `xcrun simctl install "iPhone 14" <path-to-.app>`  
   - `xcrun simctl launch "iPhone 14" com.prelura.preloved` → note PID.

4. **iPhone 14 Alt** — boot, terminate, install, launch  
   - `xcrun simctl boot "iPhone 14 Alt" 2>/dev/null || true`  
   - `xcrun simctl terminate "iPhone 14 Alt" com.prelura.preloved 2>/dev/null || true`  
   - `xcrun simctl install "iPhone 14 Alt" <path-to-.app>`  
   - `xcrun simctl launch "iPhone 14 Alt" com.prelura.preloved` → note PID.

5. **Monitoring (required)**  
   - Watch build, install, and launch for **both** sims until they complete; report any failure with the error text.

6. **Report**  
   - Confirm the new build is running on **iPhone 14** with the process ID from launch output.  
   - Confirm the same on **iPhone 14 Alt** when that simulator was available; if Alt was skipped, say so clearly.  
   - If anything failed, show the error and suggest a fix.
