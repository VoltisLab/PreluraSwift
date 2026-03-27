# Push (PreluraSwift repo only)

To push **both** `prelura-app` and `PreluraSwift`, use the workspace command: **`prelura-workspace/.cursor/commands/push.md`** (run from the parent folder that contains both repos).

When the user runs `/push` from **this** repo only, follow these steps:

1. **Token**
   - Read the GitHub Personal Access Token from `scripts/github-token` (one line, no quotes or spaces).
   - If the file is missing or empty, report: "Create `scripts/github-token` with your GitHub PAT (one line). See `scripts/github-token.example`."

2. **Commit (if needed)**
   - If there are uncommitted changes (`git status` shows modified/untracked), stage and commit them: `git add -A` then `git commit -m "…"` with a short descriptive message (or ask the user for the message if they prefer).
   - If the working tree is clean, skip to push.

3. **Push**
   - Push the current branch to `origin` using the token for authentication:
     - `git -c credential.helper='!f() { echo "username=x-oauth-basic"; echo "password=$(cat scripts/github-token)"; }; f' push -u origin $(git branch --show-current)`
   - Use the project root as the working directory.

4. **Report**
   - On success: confirm branch and remote (e.g. "Pushed `main` to `origin`").
   - On failure: show the error and suggest fixes (e.g. invalid token, network, or create repo via API if 404).
