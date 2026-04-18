#!/usr/bin/env bash
# Called from .github/workflows/staging-seed.yml with STAGING_SEED_PASSWORD from Actions secrets.
# Replace the body with your real seed steps (API calls, remote SSH, etc.).
set -euo pipefail

if [[ -z "${STAGING_SEED_PASSWORD:-}" ]]; then
  echo "Missing STAGING_SEED_PASSWORD. Add repository secret STAGING_SEED_PASSWORD (GitHub → Settings → Secrets → Actions)."
  exit 1
fi

echo "STAGING_SEED_PASSWORD is present (${#STAGING_SEED_PASSWORD} chars). Edit scripts/gha-staging-seed.sh to run your seed logic."
exit 0
