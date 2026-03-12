# Prelura Swift

iOS app for Prelura (SwiftUI). Connects to the shared Prelura backend API.

## Backend

- **Repository:** https://github.com/VoltisLab/prelura-app  
- **API (this app uses):** `https://prelura.voltislabs.uk/graphql/`  
- **Lenny (AI assistant) system prompt:** `docs/lenny-system-prompt.txt` in this repo is the canonical instruction set for Lenny. The Swift app uses it when calling OpenAI for reply text.
- This client does not modify the backend; it only consumes the existing GraphQL API. See `.cursor/rules/backend-protection.mdc` and `Prelura-swift/Utilities/Constants.swift` for references.

## Lenny & OpenAI

Lenny’s reply text can come from **OpenAI** (when configured) or from the built-in **rule-based** replies. To use OpenAI:

1. Get an API key from [OpenAI](https://platform.openai.com/api-keys).
2. Open the file **`Prelura-swift/Secrets.plist`** in Xcode or TextEdit. (If it doesn’t exist, build the app once—it will be created from the example.)
3. Paste your key (e.g. `sk-…`) as the value for **`OPENAI_API_KEY`**: put it between the `<string>` and `</string>` tags so it looks like `<string>sk-your-key-here</string>`.
4. Save and run the app again.

Do not commit `Secrets.plist` (it’s in `.gitignore`). If no key is set, Lenny uses only the rule-based replies.

## Build & run

Open `Prelura-swift.xcodeproj` in Xcode. Build and run on simulator or device.  
For TestFlight: `./scripts/build-ipa-for-testflight.sh --upload`
