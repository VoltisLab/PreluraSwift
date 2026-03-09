# TestFlight upload

## Credentials (Apple ID + 16-digit app-specific password)

The build script uses credentials in this order:

1. **Keychain** (after running `./scripts/setup-testflight-keychain.sh`)
2. **Project file** `scripts/testflight-credentials.json` (gitignored)

### Using the project file

Copy the example and fill in your details:

```bash
cp scripts/testflight-credentials.json.example scripts/testflight-credentials.json
```

Edit `scripts/testflight-credentials.json`:

- `apple_id`: your Apple ID email
- `app_specific_password`: the 16-character app-specific password from Apple (e.g. `xxxx-xxxx-xxxx-xxxx`)

Create the app-specific password at: [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords.

**Do not commit** `testflight-credentials.json`; it is listed in `.gitignore`.

### Build and upload

```bash
./scripts/build-ipa-for-testflight.sh --upload
```
