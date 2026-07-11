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

BACKUP_ID="${BACKUP_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
[[ "$BACKUP_ID" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "invalid backup id" >&2; exit 2; }
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-relay-postgres}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
OUT_DIR="$BACKUP_DIR/postgres"
OUT="$OUT_DIR/newapi-$BACKUP_ID.dump"
TMP="$OUT.tmp.$$"

mkdir -p "$OUT_DIR"
chmod 700 "$BACKUP_DIR" "$OUT_DIR"
[ ! -e "$OUT" ] && [ ! -e "$OUT.sha256" ] || { echo "backup already exists" >&2; exit 2; }
trap 'rm -f "$TMP" "$TMP.sha256"' EXIT

"$DOCKER_BIN" exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$POSTGRES_CONTAINER" \
  pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB" >"$TMP"
chmod 600 "$TMP"
[ "$(head -c 5 "$TMP")" = PGDMP ] || { echo "invalid PostgreSQL custom-format stream" >&2; exit 1; }

(
  cd "$OUT_DIR"
  sha256sum "$(basename "$TMP")" >"$(basename "$TMP").sha256"
  sha256sum -c "$(basename "$TMP").sha256" >/dev/null
)
chmod 600 "$TMP.sha256"
mv "$TMP" "$OUT"
sed "s/$(basename "$TMP")/$(basename "$OUT")/" "$TMP.sha256" >"$OUT.sha256"
chmod 600 "$OUT.sha256"
rm -f "$TMP.sha256"
(cd "$OUT_DIR" && sha256sum -c "$(basename "$OUT").sha256" >/dev/null)
trap - EXIT
printf '%s\n' "$OUT"
