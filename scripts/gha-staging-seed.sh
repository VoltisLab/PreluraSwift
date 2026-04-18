#!/usr/bin/env bash
# GitHub Actions entry: bulk register users (scripts/seed-register-users.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${STAGING_SEED_PASSWORD:-}" ]]; then
  echo "Missing STAGING_SEED_PASSWORD. Add repository secret STAGING_SEED_PASSWORD."
  exit 1
fi

bash scripts/seed-register-users.sh
