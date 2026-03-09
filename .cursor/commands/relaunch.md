# Relaunch

When the user runs `/relaunch`, follow these steps:

1. **Rebuild**
   - Always run a fresh build first so the running app is never an old build.
   - From the iOS project root: `xcodebuild -project Prelura-swift.xcodeproj -scheme Prelura-swift -destination 'platform=iOS Simulator,name=iPhone 14' -configuration Debug build`
   - Monitor build output until it completes. If the build fails, report the error and fix before continuing.

2. **Terminate, install, launch on iPhone 14**
   - Ensure iPhone 14 simulator is booted (e.g. `xcrun simctl list devices booted`); if not, boot it.
   - Terminate any running instance: `xcrun simctl terminate "iPhone 14" com.prelura.preloved`
   - Install the newly built .app: `xcrun simctl install "iPhone 14" <path-to-.app>` (DerivedData path: `~/Library/Developer/Xcode/DerivedData/Prelura-swift-<hash>/Build/Products/Debug-iphonesimulator/Prelura-swift.app`)
   - Launch: `xcrun simctl launch "iPhone 14" com.prelura.preloved`

3. **Monitoring (required)**
   - Watch build, install, and launch output until they complete.
   - Confirm the app is running (e.g. process ID from launch output) or report any failure.

4. **Report**
   - Confirm the app is running on the iPhone 14 simulator and give the process ID if printed. If anything failed, show the error and suggest a fix. Monitoring must be part of every run.
