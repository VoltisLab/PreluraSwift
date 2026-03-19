# Prelura Swift

iOS app for Prelura (SwiftUI). Connects to the shared Prelura backend API.

## Backend

- **Repository:** https://github.com/VoltisLab/prelura-app  
- **API (this app uses):** `https://prelura.voltislabs.uk/graphql/`  
- **Lenny (AI assistant) system prompt:** `docs/lenny-system-prompt.txt` in this repo is the canonical instruction set for Lenny. The Swift app uses it when calling OpenAI for reply text.
- This client consumes the existing GraphQL API. See `Prelura-swift/Utilities/Constants.swift` for endpoint references.

## API keys (Secrets.plist)

The app reads API keys from **`Prelura-swift/Secrets.plist`**. You only need to **paste each key between the `<string>` and `</string>`** for the key you use.

| Key in plist | Used for |
|--------------|----------|
| **OPENAI_API_KEY** | Lenny (AI chat). Get from [OpenAI](https://platform.openai.com/api-keys). |
| **GOOGLE_PLACES_API_KEY** | Profile location suggestions. Get from [Google Cloud](https://console.cloud.google.com/) (enable Places API, create API key). |

**Step-by-step:** See **[docs/secrets.md](docs/secrets.md)** for the exact plist layout and where to paste each key (and what to do if `GOOGLE_PLACES_API_KEY` is missing from your file).

Do not commit `Secrets.plist` (it’s in `.gitignore`).

## Build & run

Open `Prelura-swift.xcodeproj` in Xcode. Build and run on simulator or device.  
For TestFlight: `./scripts/build-ipa-for-testflight.sh --upload`
