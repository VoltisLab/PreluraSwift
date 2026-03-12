# Check Flutter

When the user runs `/checkflutter` (optionally with a feature or topic, e.g. `/checkflutter profile photo` or `/checkflutter payment`), follow these steps:

1. **Identify the feature**
   - Use the topic or feature name the user provided with the command. If none was given, ask: "Which feature should I check in the Flutter app?"

2. **Locate the Prelura Flutter app**
   - The Flutter app lives at: `/Users/user/prelura-workspace/PreluraApp`
   - Search under that path only (do not search the whole workspace or home directory).

3. **Find the implementation**
   - Search the Flutter codebase for relevant files: widget names, route names, keywords (e.g. "profile picture", "payment", "report", "full screen image").
   - Prefer: `lib/views/`, `lib/controller/`, `lib/repo/`, and `lib/core/router/`.
   - Open the most relevant files and read the implementation (UI, callbacks, navigation, API calls).

4. **Summarize**
   - In your reply, give:
     - **Feature:** What was checked.
     - **Where:** File paths and, if useful, class/widget names and line ranges.
     - **How it works:** Short description (what the UI does, what happens on tap/submit, which APIs or routes are used).
     - **Relevant for Swift:** Notes that help implement or align the same behavior in the Prelura Swift app (e.g. "Flutter uses a dialog with a 250×250 image; Swift could use FullScreenImageViewer").

5. **Do not**
   - Modify the Flutter app or any backend/GraphQL schema.
   - Run Flutter build or `flutter run` unless the user explicitly asks.

**Example:** For `/checkflutter profile photo expand`, you might find `lib/views/widgets/profile_picture.dart`, `lib/views/pages/profile_details/view/user_wardrobe.dart`, describe the `onTap` behavior for own vs other user, and suggest how the Swift app can mirror it.
