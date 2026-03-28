# Stream Prelura simulator logs

After the app is running on a simulator, stream logs in **Cursor’s terminal** (⌃` → new tab if you want build output elsewhere):

```bash
cd PreluraSwift   # if your workspace root is the monorepo
./scripts/stream-prelura-simulator-logs.sh
# or: ./scripts/stream-prelura-simulator-logs.sh "iPhone 14 Alt"
```

**Default = focused stream** (not the whole app): `subsystem == com.prelura.preloved` plus lines containing `[Auth]`, `[Push]`, or `[FCM TEST]`. You will **not** see every UIKit/CFNetwork/User Defaults line.

**Full firehose** (old behavior, very noisy):

```bash
PRELURA_LOG_VERBOSE=1 ./scripts/stream-prelura-simulator-logs.sh
```

**Realtime:** `log stream` only emits **new** events after the command starts. Restart the script after a fresh install if you want to be sure you’re attached; scrolling old terminal output is not live.

**Physical device (USB):**

```bash
log stream --device --style compact --predicate 'subsystem == "com.prelura.preloved" OR processImagePath CONTAINS[c] "Prelura"'
```
