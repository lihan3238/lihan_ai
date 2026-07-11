#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [ -f "$ROOT_DIR/$1" ] || fail "missing required file: $1"
}

assert_not_path() {
  [ ! -e "$ROOT_DIR/$1" ] || fail "removed path still exists: $1"
}

assert_not_nonempty_path() {
  [ ! -e "$ROOT_DIR/$1" ] && return 0
  [ -d "$ROOT_DIR/$1" ] || fail "removed path still exists: $1"
  [ -z "$(find "$ROOT_DIR/$1" -mindepth 1 -print -quit)" ] ||
    fail "removed path still has contents: $1"
}

assert_contains() {
  grep -Eq -- "$2" "$ROOT_DIR/$1" || fail "$1 missing: $3"
}

for path in \
  README.md README.zh-CN.md AGENTS.md .env.example .env.production.example .gitignore \
  docker-compose.yml docker-compose.prod.yml docker-compose.cpa.yml \
  docker-compose.cpa.ui.yml docker-compose.cloudflare-tunnel.yml \
  ops/compose.sh ops/check-runtime.sh ops/backup-postgres.sh \
  ops/restore-postgres.sh ops/backup-config.sh ops/backup-secrets.sh ops/cpa-ui.sh \
  tests/test-backups.sh \
  docs/operations-runbook.md docs/backup-strategy.md \
  docs/migration-runbook.md docs/komodo-runbook.md; do
  assert_file "$path"
done

for path in vendor .specify e2e package.json playwright.config.ts \
  Caddyfile Caddyfile.edge.example docker-compose.local-build.yml docker-compose.edge.yml; do
  assert_not_path "$path"
done

assert_not_nonempty_path .agents

assert_contains docker-compose.yml 'calciumion/new-api' "official New API image"
assert_contains docker-compose.cpa.yml 'eceasy/cli-proxy-api' "official CLIProxyAPI image"
assert_contains docker-compose.cloudflare-tunnel.yml 'cloudflare/cloudflared' "official cloudflared image"
assert_contains ops/backup-postgres.sh 'pg_dump -Fc' "PostgreSQL custom-format backup"
assert_contains ops/restore-postgres.sh 'PGDMP' "PostgreSQL format dispatch"
assert_contains ops/restore-postgres.sh 'pg_restore --clean --if-exists --no-owner' "custom-format restore"
assert_contains ops/backup-secrets.sh 'age -R' "encrypted secret artifact"

bash -n \
  "$ROOT_DIR/ops/backup-postgres.sh" \
  "$ROOT_DIR/ops/restore-postgres.sh" \
  "$ROOT_DIR/ops/backup-config.sh" \
  "$ROOT_DIR/ops/backup-secrets.sh" \
  "$ROOT_DIR/tests/test-backups.sh"
bash "$ROOT_DIR/tests/test-backups.sh"

docker compose --env-file "$ROOT_DIR/.env.production.example" \
  -f "$ROOT_DIR/docker-compose.yml" \
  -f "$ROOT_DIR/docker-compose.prod.yml" \
  -f "$ROOT_DIR/docker-compose.cpa.yml" \
  config >/dev/null

echo "repo verification ok"
