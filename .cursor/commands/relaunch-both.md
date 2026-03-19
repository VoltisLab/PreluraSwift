# Relaunch on iPhone 14 and iPhone 16e

When the user runs `/relaunch-both`, follow these steps:

1. **Rebuild**
   - Always run a fresh build first so the running app is never an old build.
   - From the iOS project root: `xcodebuild -project Prelura-swift.xcodeproj -scheme Prelura-swift -destination 'platform=iOS Simulator,name=iPhone 14' -configuration Debug build`
   - Monitor build output until it completes. If the build fails, report the error and fix before continuing.

2. **Relaunch on iPhone 14**
   - Ensure iPhone 14 simulator is booted (e.g. `xcrun simctl list devices booted`); if not, boot it.
   - Terminate any running instance: `xcrun simctl terminate "iPhone 14" com.prelura.preloved`
   - Install the newly built .app: `xcrun simctl install "iPhone 14" <path-to-.app>` (DerivedData path: `~/Library/Developer/Xcode/DerivedData/Prelura-swift-<hash>/Build/Products/Debug-iphonesimulator/Prelura-swift.app`)
   - Launch: `xcrun simctl launch "iPhone 14" com.prelura.preloved`

3. **Relaunch on iPhone 16e**
   - Boot iPhone 16e if not already: `xcrun simctl boot "iPhone 16e"` (ignore if already booted).
   - Terminate any running instance: `xcrun simctl terminate "iPhone 16e" com.prelura.preloved`
   - Install the same .app: `xcrun simctl install "iPhone 16e" <path-to-.app>`
   - Launch: `xcrun simctl launch "iPhone 16e" com.prelura.preloved`

4. **Monitoring (required)**
   - Watch build, install, and launch output until they complete.
   - Confirm the app is running on both simulators (e.g. process IDs from launch output) or report any failure.

5. **Report**
   - Confirm the app is running on both iPhone 14 and iPhone 16e simulators and give the process IDs if printed. If anything failed, show the error and suggest a fix.
