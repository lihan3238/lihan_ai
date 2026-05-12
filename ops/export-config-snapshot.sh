#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
SNAPSHOT_DIR="${CONFIG_SNAPSHOT_DIR:-$ROOT_DIR/snapshots/config}"
MODE="redacted"

if [ "${1:-}" = "--private" ]; then
  MODE="private"
elif [ "${1:-}" != "" ]; then
  echo "usage: $0 [--private]" >&2
  exit 1
fi

if [ "$MODE" = "private" ] && [ -z "${CONFIG_SNAPSHOT_GPG_RECIPIENT:-}" ]; then
  echo "CONFIG_SNAPSHOT_GPG_RECIPIENT is not set" >&2
  exit 2
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

POSTGRES_USER="${POSTGRES_USER:-newapi}"
POSTGRES_DB="${POSTGRES_DB:-newapi}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-${DEPLOY_COMPOSE_PROJECT:-}}"
mkdir -p "$SNAPSHOT_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

compose() {
  if [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
    docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.dev.yml" "$@"
  else
    docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.dev.yml" "$@"
  fi
}

compose_psql_json() {
  sql="$1"
  compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "$sql"
}

redacted_sql="
with snapshot as (
  select json_build_object(
    'channels', coalesce((select json_agg(row_to_json(t)) from (
      select id, name, type, status, \"group\", models, model_mapping, test_model, base_url,
        priority, weight, auto_ban, used_quota, balance,
        case when key is null or key = '' then null else 'sha256:' || encode(sha256(key::bytea), 'hex') end as key_fingerprint,
        length(coalesce(key,'')) as key_length
      from channels order by id
    ) t), '[]'::json),
    'abilities', coalesce((select json_agg(row_to_json(t)) from (
      select channel_id, model, \"group\", enabled, priority, weight
      from abilities order by channel_id, model, \"group\"
    ) t), '[]'::json),
    'users', coalesce((select json_agg(row_to_json(t)) from (
      select id, username, display_name, role, status, quota, used_quota, request_count, \"group\", inviter_id, created_at, last_login_at
      from users where deleted_at is null order by id
    ) t), '[]'::json),
    'tokens', coalesce((select json_agg(row_to_json(t)) from (
      select id, user_id, status, name, expired_time, remain_quota, unlimited_quota, model_limits_enabled, model_limits,
        used_quota, \"group\", cross_group_retry,
        case when key is null or key = '' then null else 'sha256:' || encode(sha256(key::bytea), 'hex') end as key_fingerprint,
        length(coalesce(key,'')) as key_length
      from tokens where deleted_at is null order by id
    ) t), '[]'::json),
    'options', coalesce((select json_agg(row_to_json(t)) from (
      select key as option_key,
        true as value_redacted,
        length(coalesce(value,'')) as value_length,
        case when value is null or value = '' then null else 'sha256:' || encode(sha256(value::bytea), 'hex') end as value_fingerprint
      from options order by key
    ) t), '[]'::json),
    'subscription_plans', coalesce((select json_agg(row_to_json(t)) from (
      select * from subscription_plans order by id
    ) t), '[]'::json),
    'models', coalesce((select json_agg(row_to_json(t)) from (
      select * from models order by id
    ) t), '[]'::json),
    'vendors', coalesce((select json_agg(row_to_json(t)) from (
      select * from vendors order by id
    ) t), '[]'::json),
    'recent_logs', coalesce((select json_agg(row_to_json(t)) from (
      select model_name, channel_id, channel_name, \"group\", count(*) as request_count,
        coalesce(sum(quota),0) as quota_sum,
        coalesce(sum(prompt_tokens),0) as prompt_tokens_sum,
        coalesce(sum(completion_tokens),0) as completion_tokens_sum,
        coalesce(sum(case when is_stream then 1 else 0 end),0) as stream_count,
        min(created_at) as first_created_at,
        max(created_at) as last_created_at
      from logs where created_at >= extract(epoch from now())::bigint - 86400
      group by model_name, channel_id, channel_name, \"group\"
      order by quota_sum desc
    ) t), '[]'::json)
  ) as data
)
select json_build_object(
  'snapshot_kind', 'redacted',
  'generated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
  'database', current_database(),
  'data', data
)::text from snapshot;
"

private_sql="
select json_build_object(
  'snapshot_kind', 'private',
  'generated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
  'database', current_database(),
  'channels', coalesce((select json_agg(row_to_json(channels)) from channels), '[]'::json),
  'abilities', coalesce((select json_agg(row_to_json(abilities)) from abilities), '[]'::json),
  'users', coalesce((select json_agg(row_to_json(users)) from users), '[]'::json),
  'tokens', coalesce((select json_agg(row_to_json(tokens)) from tokens), '[]'::json),
  'options', coalesce((select json_agg(row_to_json(options)) from options), '[]'::json),
  'subscription_plans', coalesce((select json_agg(row_to_json(subscription_plans)) from subscription_plans), '[]'::json),
  'models', coalesce((select json_agg(row_to_json(models)) from models), '[]'::json),
  'vendors', coalesce((select json_agg(row_to_json(vendors)) from vendors), '[]'::json),
  'user_subscriptions', coalesce((select json_agg(row_to_json(user_subscriptions)) from user_subscriptions), '[]'::json),
  'topups', coalesce((select json_agg(row_to_json(topups)) from topups), '[]'::json),
  'redemptions', coalesce((select json_agg(row_to_json(redemptions)) from redemptions), '[]'::json)
)::text;
"

if [ "$MODE" = "redacted" ]; then
  target="$SNAPSHOT_DIR/config-redacted-$timestamp.json"
  compose_psql_json "$redacted_sql" > "$target"
  chmod 600 "$target" 2>/dev/null || true
  CONFIG_SNAPSHOT_DIR="$SNAPSHOT_DIR" ENV_FILE="$ENV_FILE" bash "$ROOT_DIR/ops/prune-runtime-storage.sh" snapshots >/dev/null
  echo "$target"
else
  target="$SNAPSHOT_DIR/config-private-$timestamp.json.gpg"
  compose_psql_json "$private_sql" | gpg --batch --yes --encrypt --recipient "$CONFIG_SNAPSHOT_GPG_RECIPIENT" --output "$target"
  chmod 600 "$target" 2>/dev/null || true
  CONFIG_SNAPSHOT_DIR="$SNAPSHOT_DIR" ENV_FILE="$ENV_FILE" bash "$ROOT_DIR/ops/prune-runtime-storage.sh" snapshots >/dev/null
  echo "$target"
fi
