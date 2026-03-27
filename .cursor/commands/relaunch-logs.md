# Relaunch with Logs

When the user runs `/relaunch-logs`, follow these steps:

1. **Rebuild**
   - Always run a fresh build first so the running app is never an old build.
   - From the iOS project root: `xcodebuild -project Prelura-swift.xcodeproj -scheme Prelura-swift -destination 'platform=iOS Simulator,name=iPhone 14' -configuration Debug build`
   - Monitor build output until it completes. If the build fails, report the error and fix before continuing.

2. **Ensure iPhone 16e and resolve `.app`**
   - Same as `/relaunch`: if no iPhone 16e in `xcrun simctl list devices available`, create it (`simctl create` with `com.apple.CoreSimulator.SimDeviceType.iPhone-16e` and an available iOS runtime).
   - Find the built `.app`: `~/Library/Developer/Xcode/DerivedData/Prelura-swift-*/Build/Products/Debug-iphonesimulator/Prelura-swift.app` (most recent).

3. **Terminate, install, launch on iPhone 14**
   - Boot if needed; terminate: `xcrun simctl terminate "iPhone 14" com.prelura.preloved` (ignore if not running).
   - Install: `xcrun simctl install "iPhone 14" <path-to-.app>`
   - Launch: `xcrun simctl launch "iPhone 14" com.prelura.preloved` — capture PID.

4. **Terminate, install, launch on iPhone 16e**
   - Boot if needed; terminate: `xcrun simctl terminate "iPhone 16e" com.prelura.preloved` (ignore if not running).
   - Install same `.app`: `xcrun simctl install "iPhone 16e" <path-to-.app>`
   - Launch: `xcrun simctl launch "iPhone 16e" com.prelura.preloved` — capture PID.

5. **Stream logs (required)**
   - For **each** simulator where the app was launched, stream logs (run the **iPhone 14** stream in the foreground; run **iPhone 16e** in the background if both are used):  
     `xcrun simctl spawn "iPhone 14" log stream --predicate 'processImagePath contains "Prelura-swift" OR processImagePath contains "preloved"' --level debug --style compact`  
     `xcrun simctl spawn "iPhone 16e" log stream --predicate 'processImagePath contains "Prelura-swift" OR processImagePath contains "preloved"' --level debug --style compact`
   - Keep log stream(s) running so the user can see real-time app output.

6. **Monitoring (required)**
   - Watch build, install, and launch output until they complete.
   - Confirm the app is running on each simulator attempted (PIDs) or report any failure.

7. **Report**
   - Confirm the app is running on **iPhone 14** and **iPhone 16e** (when available) with process IDs.
   - Confirm that log streaming is active (both simulators if both launched).
   - If anything failed, show the error and suggest a fix.
