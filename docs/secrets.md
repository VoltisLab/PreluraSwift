# Secrets.plist — how to add your API keys

The app reads keys from **`Prelura-swift/Secrets.plist`**. (If the file doesn’t exist, build the app once; it’s created from `Secrets.plist.example`.)

## What the file looks like

Your `Secrets.plist` should look like this. You only need to **paste your key inside the `<string></string>`** for each one you use:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>OPENAI_API_KEY</key>
	<string></string>
	<key>GOOGLE_PLACES_API_KEY</key>
	<string></string>
</dict>
</plist>
```

## 1. Lenny (OpenAI)

- **Key name:** `OPENAI_API_KEY` (already in the file)
- **What to do:** Paste your OpenAI key **between** `<string>` and `</string>` on the line under `OPENAI_API_KEY`.
- **Before:** `<string></string>`
- **After:** `<string>sk-proj-xxxxx-your-openai-key-here</string>`

Get the key from [OpenAI API keys](https://platform.openai.com/api-keys).

## 2. Location suggestions (Google Places)

- **Key name:** `GOOGLE_PLACES_API_KEY` (already in the file)
- **What to do:** Paste your Google Places API key **between** `<string>` and `</string>` on the line under `GOOGLE_PLACES_API_KEY`.
- **Before:** `<string></string>`
- **After:** `<string>AIzaSyxxxx-your-google-places-key-here</string>`

Get the key from [Google Cloud Console](https://console.cloud.google.com/) → enable **Places API** → Credentials → Create API key.

## If `GOOGLE_PLACES_API_KEY` is missing from your file

Copy these two lines and paste them **inside** the `<dict>...</dict>` block (e.g. after the `OPENAI_API_KEY` block):

```xml
	<key>GOOGLE_PLACES_API_KEY</key>
	<string></string>
```

Then paste your Google key between `<string>` and `</string>`.

## Rules

- Do **not** put quotes around the key inside `<string>` — only the key, e.g. `<string>AIzaSyxxx</string>`.
- Do **not** commit `Secrets.plist` (it’s in `.gitignore`).
- You can leave a key empty if you don’t use that feature.
