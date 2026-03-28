# Relaunch with Logs

Run every shell command in **Cursor’s integrated terminal** (not Terminal.app).

**Simulators:** **iPhone 14** and **iPhone 14 Alt** (same as `/relaunch`). Do **not** use iPhone 16e for this project.

When the user runs `/relaunchlogs`, follow these steps:

1. **Rebuild**
   - Always run a fresh build first so the running app is never an old build.
   - From the iOS project root:  
     `xcodebuild -project Prelura-swift.xcodeproj -scheme Prelura-swift -destination 'generic/platform=iOS Simulator' -configuration Debug build`  
     (Use `generic/platform=iOS Simulator` so the build succeeds when `name=iPhone 14` would pick the wrong OS.)

2. **Ensure iPhone 14 Alt (optional but usual)**
   - If `xcrun simctl list devices available | grep -F "iPhone 14 Alt"` is empty, create a second iPhone 14–class simulator with that name, or continue with iPhone 14 only and say Alt was skipped.

3. **Resolve `.app`**
   - `~/Library/Developer/Xcode/DerivedData/Prelura-swift-*/Build/Products/Debug-iphonesimulator/Prelura-swift.app` (most recent).

4. **Terminate, install, launch on iPhone 14**  
   - Boot if needed; terminate: `xcrun simctl terminate "iPhone 14" com.prelura.preloved` (ignore if not running).  
   - Install and launch; capture PID.

5. **Terminate, install, launch on iPhone 14 Alt** (when that device exists)  
   - Same for `"iPhone 14 Alt"`.

6. **Stream logs for both simulators (required)**  
   - The user must see **live logs from both** devices in Cursor, not only iPhone 14.  
   - Prefer **focused** predicates (see `./scripts/stream-prelura-simulator-logs.sh`): matching `process == "Prelura-swift"` alone floods the terminal with UIKit/CFNetwork/defaults noise and hides `[Auth]` / `[Push]`.  
   - Run **iPhone 14 Alt** in the **background** and **iPhone 14** in the **foreground**, with prefixes, e.g.:  
     ```bash
     PRED='(subsystem == "com.prelura.preloved") OR (eventMessage CONTAINS[c] "[Push]") OR (eventMessage CONTAINS[c] "[Auth]") OR (eventMessage CONTAINS[c] "[FCM TEST]")'
     xcrun simctl spawn "iPhone 14 Alt" log stream --predicate "$PRED" --level debug --style compact 2>&1 | sed 's/^/[14 Alt] /' &
     xcrun simctl spawn "iPhone 14" log stream --predicate "$PRED" --level debug --style compact 2>&1 | sed 's/^/[14] /'
     ```  
   - Full firehose: set `PRELURA_LOG_VERBOSE=1` when running `./scripts/stream-prelura-simulator-logs.sh`.  
   - If Alt was skipped, stream iPhone 14 only and state that clearly.

7. **Monitoring (required)**  
   - Watch build, install, and launch until they complete.

8. **Report**  
   - PIDs for each launched simulator.  
   - Confirm **both** log streams are active when both sims were launched.
