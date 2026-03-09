# Testflight

When the user runs `/testflight`, follow these steps:

1. **Build for archive**
   - From the iOS project root: Use the build script `./scripts/build-ipa-for-testflight.sh --upload`
   - This script handles: archiving, exporting IPA, and uploading to TestFlight in one go.
   - Alternative: If you need to build without uploading, use `./scripts/build-ipa-for-testflight.sh` (without --upload flag).
   - Monitor build output until it completes. If the build fails, report the error and fix before continuing.

2. **Export and upload**
   - The build script automatically exports the IPA from the archive and uploads it when `--upload` flag is used.
   - The upload uses credentials in this order: (1) keychain (AC_PASSWORD from `./scripts/setup-testflight-keychain.sh`), (2) project file `scripts/testflight-credentials.json` (gitignored).
   - If credentials are missing, the script will report an error. Either run `./scripts/setup-testflight-keychain.sh` or create `scripts/testflight-credentials.json` (see `scripts/testflight-credentials.json.example`).

3. **Monitoring (required)**
   - Stream or watch the upload output until it completes.
   - Monitor the upload process for success/failure messages.
   - Check for any validation errors (e.g., missing icons, bundle issues, signing problems).
   - The upload script prints status messages and saves a log to `/tmp/testflight_upload.log`
   - Watch for "UPLOAD SUCCEEDED" or "UPLOAD FAILED" messages.
   - If successful, note the Delivery UUID for tracking.

4. **Report**
   - Confirm upload success with the Delivery UUID if provided.
   - Report any errors and suggest fixes (e.g., missing app icons, signing issues, validation failures).
   - Mention that the build will be available in TestFlight after App Store Connect processing completes (usually takes a few minutes).
   - Monitoring must be part of every run.
