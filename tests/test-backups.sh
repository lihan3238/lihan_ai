#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -m 700 "$TMP/fake-bin" "$TMP/state" "$TMP/runtime"

cat >"$TMP/fake-bin/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_DOCKER_LOG"
case " $* " in
  *' pg_dump '*)
    if [ "${FAKE_PG_DUMP_INVALID:-false}" = true ]; then
      printf 'not-a-custom-dump\n'
    else
      printf 'PGDMPsynthetic-custom-format\n'
    fi
    ;;
  *' pg_restore '*|*' psql '*)
    cat >"$FAKE_DB_STDIN"
    ;;
esac
SH
chmod 700 "$TMP/fake-bin/docker"

for binary in pg_dump pg_restore psql; do
  cat >"$TMP/fake-bin/$binary" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >>"$FAKE_DIRECT_PG_LOG"
cat >/dev/null || true
SH
  chmod 700 "$TMP/fake-bin/$binary"
done

cat >"$TMP/fake-bin/tar" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_TAR_LOG"
printf 'synthetic-tar-stream\n'
SH
chmod 700 "$TMP/fake-bin/tar"

cat >"$TMP/fake-bin/age" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_AGE_LOG"
output=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$output" ]
cat >"$output"
SH
chmod 700 "$TMP/fake-bin/age"

export PATH="$TMP/fake-bin:$PATH"
export FAKE_DOCKER_LOG="$TMP/state/docker.log"
export FAKE_DB_STDIN="$TMP/state/database.stdin"
export FAKE_DIRECT_PG_LOG="$TMP/state/direct-pg.log"
export FAKE_TAR_LOG="$TMP/state/tar.log"
export FAKE_AGE_LOG="$TMP/state/age.log"
: >"$FAKE_DOCKER_LOG"
: >"$FAKE_DIRECT_PG_LOG"
: >"$FAKE_TAR_LOG"
: >"$FAKE_AGE_LOG"

mkdir -m 700 "$TMP/runtime/cpa-auth" "$TMP/runtime/cloudflared"
printf 'opaque-cpa-config-sentinel\n' >"$TMP/runtime/cpa-auth/config.yaml"
printf 'opaque-cpa-auth-sentinel\n' >"$TMP/runtime/cpa-auth/account.json"
printf 'opaque-cloudflared-config-sentinel\n' >"$TMP/runtime/cloudflared/config.yml"
printf 'opaque-cloudflared-credentials-sentinel\n' >"$TMP/runtime/cloudflared/tunnel.json"
printf 'age1syntheticrecipient\n' >"$TMP/runtime/recipient.txt"
chmod 600 \
  "$TMP/runtime/cpa-auth/config.yaml" \
  "$TMP/runtime/cpa-auth/account.json" \
  "$TMP/runtime/cloudflared/config.yml" \
  "$TMP/runtime/cloudflared/tunnel.json" \
  "$TMP/runtime/recipient.txt"

ENV_FILE_PATH="$TMP/runtime/.env.production"
cat >"$ENV_FILE_PATH" <<EOF
POSTGRES_USER=newapi
POSTGRES_PASSWORD=synthetic-postgres-password
POSTGRES_DB=newapi
CPA_CONFIG_PATH=$TMP/runtime/cpa-auth/config.yaml
CPA_AUTH_PATH=$TMP/runtime/cpa-auth
CLOUDFLARED_CONFIG_PATH=$TMP/runtime/cloudflared/config.yml
CLOUDFLARED_CREDENTIALS_PATH=$TMP/runtime/cloudflared/tunnel.json
BACKUP_DIR=$TMP/backups
CONFIG_BACKUP_DIR=$TMP/config-backups
BACKUP_AGE_RECIPIENT_FILE=$TMP/runtime/recipient.txt
EOF
chmod 600 "$ENV_FILE_PATH"

BACKUP_ID=20260712T120000Z ENV_FILE="$ENV_FILE_PATH" \
  "$ROOT/ops/backup-postgres.sh" >"$TMP/state/backup-postgres.out"
dump="$(tail -n 1 "$TMP/state/backup-postgres.out")"
if [ "$dump" != "$TMP/backups/postgres/newapi-20260712T120000Z.dump" ]; then
  echo "backup did not create the required custom-format .dump artifact" >&2
  exit 1
fi
test "$(head -c 5 "$dump")" = PGDMP
test "$(stat -c %a "$dump")" = 600
test "$(stat -c %a "$dump.sha256")" = 600
(cd "$(dirname "$dump")" && sha256sum -c "$(basename "$dump").sha256" >/dev/null)
grep -F 'pg_dump -Fc' "$FAKE_DOCKER_LOG" >/dev/null

rm -f "$TMP/backups/postgres/newapi-20260712T120100Z.dump"*
if FAKE_PG_DUMP_INVALID=true BACKUP_ID=20260712T120100Z ENV_FILE="$ENV_FILE_PATH" \
  "$ROOT/ops/backup-postgres.sh" >/dev/null 2>&1; then
  echo 'backup unexpectedly accepted a non-custom PostgreSQL stream' >&2
  exit 1
fi
test ! -e "$TMP/backups/postgres/newapi-20260712T120100Z.dump"

: >"$FAKE_DOCKER_LOG"
if ! CONFIRM_RESTORE=yes ENV_FILE="$ENV_FILE_PATH" \
  "$ROOT/ops/restore-postgres.sh" "$dump" >/dev/null 2>"$TMP/state/custom-restore.err"; then
  cat "$TMP/state/custom-restore.err" >&2
  exit 1
fi
grep -F 'pg_restore --clean --if-exists --no-owner' "$FAKE_DOCKER_LOG" >/dev/null
grep -F -- '--dbname newapi' "$FAKE_DOCKER_LOG" >/dev/null
test "$(head -c 5 "$FAKE_DB_STDIN")" = PGDMP

legacy="$TMP/backups/postgres/newapi-20260701T000000Z.sql"
printf 'BEGIN; SELECT 1; COMMIT;\n' >"$legacy"
chmod 600 "$legacy"
(cd "$(dirname "$legacy")" && sha256sum "$(basename "$legacy")" >"$(basename "$legacy").sha256")
chmod 600 "$legacy.sha256"
: >"$FAKE_DOCKER_LOG"
if ! CONFIRM_RESTORE=yes ENV_FILE="$ENV_FILE_PATH" \
  "$ROOT/ops/restore-postgres.sh" "$legacy" >/dev/null 2>"$TMP/state/legacy-restore.err"; then
  cat "$TMP/state/legacy-restore.err" >&2
  exit 1
fi
grep -F 'psql -v ON_ERROR_STOP=1' "$FAKE_DOCKER_LOG" >/dev/null
grep -F -- '-d newapi' "$FAKE_DOCKER_LOG" >/dev/null
grep -F 'BEGIN; SELECT 1; COMMIT;' "$FAKE_DB_STDIN" >/dev/null

: >"$FAKE_DOCKER_LOG"
if ENV_FILE="$ENV_FILE_PATH" "$ROOT/ops/restore-postgres.sh" "$dump" >/dev/null 2>&1; then
  echo 'restore unexpectedly skipped explicit confirmation' >&2
  exit 1
fi
test ! -s "$FAKE_DOCKER_LOG"

printf 'postgres backup and restore dispatch: ok\n'

if ! secret_output="$(BACKUP_ID=20260712T120000Z ENV_FILE="$ENV_FILE_PATH" \
  "$ROOT/ops/backup-secrets.sh" 2>"$TMP/state/backup-secrets.err")"; then
  cat "$TMP/state/backup-secrets.err" >&2
  exit 1
fi
test "$secret_output" = "$TMP/config-backups/lihan-ai-secrets-20260712T120000Z.tar.age"
test "$(stat -c %a "$secret_output")" = 600
test "$(stat -c %a "$secret_output.sha256")" = 600
(cd "$(dirname "$secret_output")" && sha256sum -c "$(basename "$secret_output").sha256" >/dev/null)
grep -F -- '-R' "$FAKE_AGE_LOG" >/dev/null
grep -F "$TMP/runtime/recipient.txt" "$FAKE_AGE_LOG" >/dev/null
grep -F -- '-cf - .' "$FAKE_TAR_LOG" >/dev/null
test ! -s "$TMP/state/backup-secrets.err"
if rg -F 'opaque-' "$TMP/state/backup-secrets.err" "$TMP/state/age.log" "$TMP/state/tar.log"; then
  echo 'opaque secret contents leaked to backup output' >&2
  exit 1
fi
test -z "$(find "$TMP/config-backups" -mindepth 1 -maxdepth 1 ! -name '*.age' ! -name '*.sha256' -print -quit)"

compat_output="$(BACKUP_ID=20260712T120100Z ENV_FILE="$ENV_FILE_PATH" \
  "$ROOT/ops/backup-config.sh")"
test "$compat_output" = "$TMP/config-backups/lihan-ai-secrets-20260712T120100Z.tar.age"

chmod 644 "$TMP/runtime/cloudflared/tunnel.json"
if BACKUP_ID=20260712T120200Z ENV_FILE="$ENV_FILE_PATH" \
  "$ROOT/ops/backup-secrets.sh" >/dev/null 2>&1; then
  echo 'secret backup unexpectedly accepted a permissive source' >&2
  exit 1
fi
chmod 600 "$TMP/runtime/cloudflared/tunnel.json"
ln -s "$TMP/runtime/cloudflared/tunnel.json" "$TMP/runtime/cpa-auth/link.json"
BACKUP_ID=20260712T120300Z ENV_FILE="$ENV_FILE_PATH" \
  "$ROOT/ops/backup-secrets.sh" >/dev/null 2>&1 && {
    echo 'secret backup unexpectedly accepted a symlink source' >&2
    exit 1
  }

printf 'encrypted opaque secret backup: ok\n'
