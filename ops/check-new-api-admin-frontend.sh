#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WEB_DIR="$ROOT_DIR/vendor/new-api/web/default"

if [ -z "${NEW_API_ADMIN_USERNAME:-}" ] || [ -z "${NEW_API_ADMIN_PASSWORD:-}" ]; then
  echo "NEW_API_ADMIN_USERNAME and NEW_API_ADMIN_PASSWORD are required" >&2
  echo "Example:" >&2
  echo "  NEW_API_BASE_URL=https://api.lihan3238.com NEW_API_ADMIN_USERNAME=... NEW_API_ADMIN_PASSWORD=... bash ops/check-new-api-admin-frontend.sh" >&2
  exit 2
fi

cd "$ROOT_DIR"
npm run e2e:web:new-api-admin

if [ "${CHECK_LOCAL_NEW_API_PATCH:-0}" = "1" ]; then
  [ -f "$WEB_DIR/src/components/ui/dropdown-menu.test.tsx" ] || {
    echo "missing dropdown-menu.test.tsx in vendor/new-api; checkout the temporary dropdown onSelect patch first" >&2
    exit 1
  }
  grep -q "handleDropdownMenuItemSelect" "$WEB_DIR/src/components/ui/dropdown-menu.tsx" || {
    echo "vendor/new-api dropdown-menu.tsx does not reference handleDropdownMenuItemSelect" >&2
    exit 1
  }

  cd "$WEB_DIR"
  npm run typecheck
  npm run build
  echo "dropdown-menu.test.tsx is present; run the upstream PR test job when available before using the temporary image"
fi
