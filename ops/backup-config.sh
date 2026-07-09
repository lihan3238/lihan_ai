#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

if [[ "$ENV_FILE" != /* ]]; then
  ENV_FILE="$ROOT_DIR/$ENV_FILE"
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

CONFIG_BACKUP_DIR="${CONFIG_BACKUP_DIR:-$ROOT_DIR/snapshots/config}"
OUT_DIR="$CONFIG_BACKUP_DIR/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT_DIR"

cp "$ENV_FILE" "$OUT_DIR/env.production"
for path in "$CPA_CONFIG_PATH" "$CLOUDFLARED_CONFIG_PATH"; do
  if [[ -f "$path" ]]; then
    cp "$path" "$OUT_DIR/$(basename "$path")"
  fi
done

tar -C "$OUT_DIR/.." -czf "$OUT_DIR.tar.gz" "$(basename "$OUT_DIR")"
sha256sum "$OUT_DIR.tar.gz" > "$OUT_DIR.tar.gz.sha256"
echo "$OUT_DIR.tar.gz"
