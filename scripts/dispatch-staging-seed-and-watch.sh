#!/usr/bin/env bash
# Same as “last night”: dispatch Staging seed on GitHub Actions, then stream logs until done.
#
# Requires ONE of:
#   gh auth login   (once per machine), or
#   export GH_TOKEN=ghp_…   (token with workflow scope)
#
# Usage (defaults match a full 500-user batch from index 1):
#   bash scripts/dispatch-staging-seed-and-watch.sh
#
# If you already registered indices 1–3 and want the next 500 without collisions:
#   SEED_START_INDEX=4 bash scripts/dispatch-staging-seed-and-watch.sh
#
set -euo pipefail
REPO="${REPO:-VoltisLab/PreluraSwift}"
WORKFLOW="${WORKFLOW:-staging-seed.yml}"
USER_COUNT="${USER_COUNT:-500}"
SEED_START_INDEX="${SEED_START_INDEX:-1}"
VERIFY="${VERIFY:-yes}"
SMOKE="${SMOKE:-0}"

export PATH="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

if ! command -v gh >/dev/null 2>&1; then
  echo "Install GitHub CLI: https://cli.github.com/  (e.g. brew install gh)"
  exit 1
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "Not logged in. Run: gh auth login -h github.com"
  echo "Or set GH_TOKEN (classic PAT with workflow scope) and re-run."
  exit 1
fi

echo "Dispatching ${WORKFLOW} on ${REPO} (user_count=${USER_COUNT} seed_start_index=${SEED_START_INDEX} verify=${VERIFY} smoke=${SMOKE})"
gh workflow run "$WORKFLOW" --repo "$REPO" \
  -f "user_count=${USER_COUNT}" \
  -f "seed_start_index=${SEED_START_INDEX}" \
  -f "verify_emails_after_seed=${VERIFY}" \
  -f "smoke_login_count=${SMOKE}"

echo "Waiting for run to appear..."
sleep 6
RUN_ID="$(gh run list --repo "$REPO" --workflow="$WORKFLOW" --limit 1 --json databaseId -q '.[0].databaseId')"
if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
  echo "Could not resolve run id. Open: https://github.com/${REPO}/actions/workflows/${WORKFLOW}"
  exit 1
fi

echo "Watching run $RUN_ID (live logs; Ctrl+C stops watching, run continues on GitHub)"
echo "https://github.com/${REPO}/actions/runs/${RUN_ID}"
exec gh run watch "$RUN_ID" --repo "$REPO" --exit-status
