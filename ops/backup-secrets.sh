#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"
[[ "$ENV_FILE" = /* ]] || ENV_FILE="$ROOT_DIR/$ENV_FILE"
[ -f "$ENV_FILE" ] && [ ! -L "$ENV_FILE" ] || { echo "environment file not found" >&2; exit 2; }

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

assert_private_tree() {
  local root="$1" path mode
  [ -e "$root" ] && [ ! -L "$root" ] || return 2
  while IFS= read -r -d '' path; do
    [ ! -L "$path" ] || return 1
    [ -f "$path" ] || [ -d "$path" ] || return 1
    mode="$(stat -c %a "$path")"
    ((8#$mode & 077)) && return 1
  done < <(find "$root" -mindepth 0 -print0)
  return 0
}

copy_opaque_if_present() {
  local source="$1" target="$2"
  [ -n "$source" ] || return 0
  [ -e "$source" ] || return 0
  assert_private_tree "$source" || { echo "configured secret path is unsafe" >&2; return 1; }
  mkdir -p "$(dirname "$target")"
  cp -a "$source" "$target"
}

BACKUP_ID="${BACKUP_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
[[ "$BACKUP_ID" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "invalid backup id" >&2; exit 2; }
OUTPUT_DIR="${SECRET_BACKUP_DIR:-${CONFIG_BACKUP_DIR:-$ROOT_DIR/snapshots/config}}"
RECIPIENT_FILE="${BACKUP_AGE_RECIPIENT_FILE:-$ROOT_DIR/backup-age-recipient.txt}"
[ -f "$RECIPIENT_FILE" ] && [ ! -L "$RECIPIENT_FILE" ] && [ -s "$RECIPIENT_FILE" ] || {
  echo "age recipient file not found" >&2
  exit 2
}

mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"
OUT="$OUTPUT_DIR/lihan-ai-secrets-$BACKUP_ID.tar.age"
[ ! -e "$OUT" ] && [ ! -e "$OUT.sha256" ] || { echo "backup already exists" >&2; exit 2; }
WORK="$(mktemp -d "$OUTPUT_DIR/.secret-stage-${BACKUP_ID}.XXXXXX")"
STAGE="$WORK/stage"
TMP_OUT="$WORK/$(basename "$OUT")"
trap 'rm -rf "$WORK"' EXIT
mkdir -m 700 "$STAGE"

assert_private_tree "$ENV_FILE" || { echo "environment file permissions are too broad" >&2; exit 1; }
mkdir -m 700 "$STAGE/environment"
cp -a "$ENV_FILE" "$STAGE/environment/.env.production"
copy_opaque_if_present "${CPA_CONFIG_PATH:-}" "$STAGE/cpa/config"
copy_opaque_if_present "${CPA_AUTH_PATH:-}" "$STAGE/cpa/auth"
copy_opaque_if_present "${CLOUDFLARED_CONFIG_PATH:-}" "$STAGE/cloudflared/config"
copy_opaque_if_present "${CLOUDFLARED_CREDENTIALS_PATH:-}" "$STAGE/cloudflared/credentials"
{
  printf 'BACKUP_SCHEMA=1\n'
  printf 'BACKUP_ID=%s\n' "$BACKUP_ID"
  printf 'SOURCE=lihan_ai\n'
} >"$STAGE/MANIFEST.env"
chmod -R go-rwx "$STAGE"
assert_private_tree "$STAGE"

(cd "$STAGE" && tar -cf - .) | age -R "$RECIPIENT_FILE" -o "$TMP_OUT"
chmod 600 "$TMP_OUT"
[ -s "$TMP_OUT" ] || { echo "encrypted artifact is empty" >&2; exit 1; }
mv "$TMP_OUT" "$OUT"
(
  cd "$OUTPUT_DIR"
  sha256sum "$(basename "$OUT")" >"$(basename "$OUT").sha256"
  sha256sum -c "$(basename "$OUT").sha256" >/dev/null
)
chmod 600 "$OUT.sha256"
trap - EXIT
rm -rf "$WORK"
printf '%s\n' "$OUT"
