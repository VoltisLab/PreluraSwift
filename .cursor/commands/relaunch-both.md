# Relaunch both (iPhone 14 + iPhone 14 Alt)

**Use this command after tasks that touch the iOS app** so both simulators always run the latest build.

When the user runs `/relaunch-both`, follow these steps:

**Build:** Use `-destination 'generic/platform=iOS Simulator'` so the build does not depend on a specific simulator OS matching “latest” (see workspace `relaunch-both` in `~/.cursor/commands` for full notes).

1. **Rebuild (once)**
   - From the iOS project root (folder containing `Prelura-swift.xcodeproj`):  
     `xcodebuild -project Prelura-swift.xcodeproj -scheme Prelura-swift -destination 'generic/platform=iOS Simulator' -configuration Debug build`
   - Monitor until **BUILD SUCCEEDED** or fix errors. Resolve `<path-to-.app>` from the log or:  
     `~/Library/Developer/Xcode/DerivedData/Prelura-swift-<hash>/Build/Products/Debug-iphonesimulator/Prelura-swift.app`

2. **Ensure iPhone 14 Alt exists**
   - If `xcrun simctl list devices available | grep -F "iPhone 14 Alt"` is empty, create a second iPhone 14–class simulator with that name using an available runtime (or report and continue with iPhone 14 only).

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
   - Watch build, install, and launch for both sims; report any failure with the error text.

6. **Report**  
   - Confirm both simulators ran the new build and give **both** process IDs (or explain if iPhone 14 Alt was skipped).
