# Relaunch with Logs

When the user runs `/relaunch-logs`, follow these steps:

1. **Rebuild**
   - Always run a fresh build first so the running app is never an old build.
   - From the iOS project root: `xcodebuild -project Prelura-swift.xcodeproj -scheme Prelura-swift -destination 'platform=iOS Simulator,name=iPhone 14' -configuration Debug build`
   - Monitor build output until it completes. If the build fails, report the error and fix before continuing.

2. **Terminate, install, launch on iPhone 14**
   - Ensure iPhone 14 simulator is booted (e.g. `xcrun simctl list devices booted`); if not, boot it.
   - Terminate any running instance: `xcrun simctl terminate "iPhone 14" com.prelura.preloved`
   - Find the built .app: Look in `~/Library/Developer/Xcode/DerivedData/Prelura-swift-*/Build/Products/Debug-iphonesimulator/Prelura-swift.app` (find the most recent one)
   - Install the newly built .app: `xcrun simctl install "iPhone 14" <path-to-.app>`
   - Launch: `xcrun simctl launch "iPhone 14" com.prelura.preloved`
   - Capture the process ID from the launch output.

3. **Stream logs (required)**
   - Immediately after launch, start streaming logs: `xcrun simctl spawn "iPhone 14" log stream --predicate 'processImagePath contains "Prelura-swift" OR processImagePath contains "preloved"' --level debug --style compact`
   - Keep the log stream running and visible to the user.
   - The logs should show app startup, any errors, and runtime output.

4. **Monitoring (required)**
   - Watch build, install, and launch output until they complete.
   - Confirm the app is running (e.g. process ID from launch output) or report any failure.
   - Keep the log stream active so the user can see real-time app output.

5. **Report**
   - Confirm the app is running on the iPhone 14 simulator and give the process ID if printed.
   - Confirm that logs are streaming.
   - If anything failed, show the error and suggest a fix.
   - Monitoring and log streaming must be part of every run.
