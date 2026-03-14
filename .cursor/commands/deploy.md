# Deploy

When the user runs `/deploy`, follow these steps. **Deploy means: deploy the backend (prelura-app), monitor until successful, then rebuild and relaunch the iOS app.**

1. **Deploy the backend**
   - Backend repo: **prelura-app** (e.g. `~/prelura-workspace/prelura-app` or `../prelura-app`). The backend deploys via GitHub Actions workflow **"Deploy to Server"** on push to `main`.
   - From the **backend repo root** (prelura-app):
     - If there are uncommitted changes the user cares about: commit them, then push to `main` (e.g. `git push origin main`). If the user does not want to push uncommitted changes, report status and ask or skip push.
     - If the branch is not `main`: push to `main` (e.g. `git push origin HEAD:main`) or push the current branch and merge to main per team workflow.
     - Run: `git push origin main` (or equivalent) to trigger the workflow.
   - The workflow builds Docker, runs migrations, runs `add_categories`, and updates the server.

2. **Monitor the deployment**
   - Use GitHub CLI for monitoring. Ensure `gh` is on PATH (e.g. `export PATH="$HOME/.local/bin:$PATH"`) and **set auth from the shared token**: from the iOS project root (Prelura-swift), `export GH_TOKEN=$(cat scripts/github-token)` (or `export GH_TOKEN=$(cat /path/to/Prelura-swift/scripts/github-token)`). If `scripts/github-token` is missing, report and ask for it.
   - From the **prelura-app** repo: `gh run list --workflow="Deploy to Server" --limit 1`, then `gh run watch <run-id>` (or `gh run watch` for the latest run). If `gh` is not in PATH, use `$HOME/.local/bin/gh`.
   - Alternatively poll: `gh run list --workflow="Deploy to Server" --limit 1` until status is `completed` and conclusion is `success`.
   - If `gh` is not installed or auth fails: report and suggest installing gh or checking the Actions page for the prelura-app repo.
   - If the deploy **fails**, report the failure (logs, error message) and do **not** proceed to relaunch. Suggest fixes.
   - If the deploy **succeeds**, proceed to step 3.

3. **Rebuild and relaunch the iOS app (after backend deploy success)**
   - From the **iOS project root** (Prelura-swift, this repo):
     - Build: `xcodebuild -project Prelura-swift.xcodeproj -scheme Prelura-swift -destination 'platform=iOS Simulator,name=iPhone 14' -configuration Debug build`
     - Ensure iPhone 14 simulator is booted; terminate any running instance: `xcrun simctl terminate "iPhone 14" com.prelura.preloved`
     - Install the built .app: `xcrun simctl install "iPhone 14" <path-to-.app>` (DerivedData path: `~/Library/Developer/Xcode/DerivedData/Prelura-swift-<hash>/Build/Products/Debug-iphonesimulator/Prelura-swift.app`)
     - Launch: `xcrun simctl launch "iPhone 14" com.prelura.preloved`
   - Confirm the app is running and report the process ID.

4. **Report**
   - Confirm backend deploy result: success (workflow completed) or failure (with error/details).
   - Confirm the app is running on the iPhone 14 simulator with the latest build and give the process ID.
   - Mention that the app is now talking to the newly deployed backend.
