#!/usr/bin/env bash
# Make Testuser a superuser in the prelura-app backend.
# Run from a place where the backend has env (e.g. on the deployment server, or locally with .env in prelura-app).
#
# Usage:
#   PRELURA_APP=/path/to/prelura-app ./scripts/make-testuser-superuser.sh
#   Or from prelura-app root: ./venv/bin/python manage.py shell -c "..." (see docs/admin-user.md)

set -e
PRELURA_APP="${PRELURA_APP:-$(cd "$(dirname "$0")/.." && cd ../prelura-app 2>/dev/null && pwd)}"
if [[ -z "$PRELURA_APP" || ! -d "$PRELURA_APP" ]]; then
  echo "PRELURA_APP not set or not a directory. Set it to the prelura-app repo root, e.g.:"
  echo "  export PRELURA_APP=/path/to/prelura-app"
  echo "  $0"
  exit 1
fi
if [[ ! -f "$PRELURA_APP/manage.py" ]]; then
  echo "Not a Django project: $PRELURA_APP (no manage.py)"
  exit 1
fi
# Load .env if present (so DJANGO_SECRET_KEY etc. are set)
if [[ -f "$PRELURA_APP/.env" ]]; then
  set -a
  source "$PRELURA_APP/.env"
  set +a
fi
cd "$PRELURA_APP"
PYTHON="${PRELURA_APP}/venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  PYTHON=python3
fi
if ! "$PYTHON" manage.py shell -c "
from accounts.models import User
u = User.objects.filter(username__iexact='Testuser').first()
if u:
    u.is_superuser = True
    u.is_staff = True
    u.save()
    print('Testuser is now superuser and staff.')
else:
    print('User Testuser not found.')
"; then
  echo ""
  echo "Django failed (often due to missing .env). Run this script on the deployment server"
  echo "where the backend has .env, or add .env to $PRELURA_APP and run again."
  exit 1
fi
