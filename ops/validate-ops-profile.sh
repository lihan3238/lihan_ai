#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${NEW_API_ENV_FILE:-$ROOT_DIR/.env}"
PROFILE_FILE="${1:-}"

pass_count=0
fail_count=0
warn_count=0

print_result() {
  status="$1"
  name="$2"
  detail="$3"
  case "$status" in
    PASS) pass_count=$((pass_count + 1)) ;;
    FAIL) fail_count=$((fail_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
  esac
  printf '%s %-24s %s\n' "$status" "$name" "$detail"
}

usage() {
  echo "usage: $0 <ops-profile.json>" >&2
  exit 1
}

if [ -z "$PROFILE_FILE" ]; then
  usage
fi

if [ ! -f "$PROFILE_FILE" ]; then
  echo "missing profile: $PROFILE_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

if ! jq empty "$PROFILE_FILE" >/dev/null 2>&1; then
  echo "invalid JSON: $PROFILE_FILE" >&2
  exit 1
fi

require_string() {
  key="$1"
  value="$(jq -er ".$key | strings | select(length > 0)" "$PROFILE_FILE" 2>/dev/null || true)"
  if [ -z "$value" ]; then
    echo "profile.$key is required" >&2
    exit 1
  fi
  printf '%s' "$value"
}

require_number() {
  key="$1"
  value="$(jq -er ".$key | numbers" "$PROFILE_FILE" 2>/dev/null || true)"
  if [ -z "$value" ]; then
    echo "profile.$key is required" >&2
    exit 1
  fi
  printf '%s' "$value"
}

PROFILE_NAME="$(require_string name)"
GROUP="$(require_string group)"
MODEL="$(require_string model)"
MIN_ENABLED_CHANNELS="$(require_number min_enabled_channels)"
MANUAL_BILLING="$(jq -r '.manual_billing // false' "$PROFILE_FILE")"
AUTOMATIC_PAYMENT="$(jq -r '.automatic_payment // "unspecified"' "$PROFILE_FILE")"

if [ ! -f "$ENV_FILE" ]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

POSTGRES_USER="${POSTGRES_USER:-newapi}"
POSTGRES_DB="${POSTGRES_DB:-newapi}"
BASE_URL="${NEW_API_BASE_URL:-http://localhost:${NEW_API_DEV_PORT:-3100}}"

sql_literal() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

GROUP_SQL="$(sql_literal "$GROUP")"
MODEL_SQL="$(sql_literal "$MODEL")"

compose_psql_json() {
  sql="$1"
  docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.dev.yml" \
    exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "$sql"
}

db_sql="
with matched_channels as (
  select distinct c.id, c.name
  from channels c
  join abilities a on a.channel_id = c.id
  where c.status = 1
    and a.enabled = true
    and a.\"group\" = $GROUP_SQL
    and a.model = $MODEL_SQL
),
payment_options as (
  select key, value
  from options
  where lower(key) like '%pay%'
    and coalesce(value, '') not in ('', 'false', '0', '{}', '[]', 'null')
)
select json_build_object(
  'enabled_channel_count', coalesce((select count(*) from matched_channels), 0),
  'enabled_channel_names', coalesce((select json_agg(name order by name) from matched_channels), '[]'::json),
  'user_count', coalesce((select count(*) from users where deleted_at is null), 0),
  'active_token_count', coalesce((select count(*) from tokens where deleted_at is null and status = 1), 0),
  'subscription_plan_count', coalesce((select count(*) from subscription_plans), 0),
  'payment_option_count', coalesce((select count(*) from payment_options), 0)
)::text;
"

printf 'Ops profile validation\n'
printf 'Profile: %s\n' "$PROFILE_NAME"
printf 'Group:   %s\n' "$GROUP"
printf 'Model:   %s\n\n' "$MODEL"

db_json="$(compose_psql_json "$db_sql" | tr -d '\r' | sed '/^[[:space:]]*$/d' | tail -n 1)"
if ! printf '%s' "$db_json" | jq empty >/dev/null 2>&1; then
  print_result FAIL "database" "profile query did not return JSON"
  printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"
  exit 1
fi

enabled_channel_count="$(printf '%s' "$db_json" | jq -r '.enabled_channel_count // 0')"
enabled_channel_names="$(printf '%s' "$db_json" | jq -r '.enabled_channel_names // [] | join(",")')"
user_count="$(printf '%s' "$db_json" | jq -r '.user_count // 0')"
active_token_count="$(printf '%s' "$db_json" | jq -r '.active_token_count // 0')"
subscription_plan_count="$(printf '%s' "$db_json" | jq -r '.subscription_plan_count // 0')"
payment_option_count="$(printf '%s' "$db_json" | jq -r '.payment_option_count // 0')"

print_result PASS "profile" "schema ok"

if [ "$enabled_channel_count" -ge "$MIN_ENABLED_CHANNELS" ]; then
  print_result PASS "enabled channels" "$enabled_channel_count >= $MIN_ENABLED_CHANNELS [$enabled_channel_names]"
else
  print_result FAIL "enabled channels" "$enabled_channel_count < $MIN_ENABLED_CHANNELS; configure an enabled channel ability for group=$GROUP model=$MODEL"
fi

if [ "$user_count" -gt 0 ]; then
  print_result PASS "users" "$user_count users found"
else
  print_result WARN "users" "no users found; initialize New API and create an admin/test user"
fi

if [ "$active_token_count" -gt 0 ]; then
  print_result PASS "tokens" "$active_token_count active tokens found"
else
  print_result WARN "tokens" "no active tokens found; create a low-quota test token before E2E"
fi

if [ "$subscription_plan_count" -gt 0 ]; then
  print_result PASS "subscriptions" "$subscription_plan_count plans found"
else
  print_result WARN "subscriptions" "no subscription plans found; manual billing is acceptable for this profile"
fi

if [ "$MANUAL_BILLING" = "true" ] && [ "$AUTOMATIC_PAYMENT" = "disabled" ]; then
  if [ "$payment_option_count" -eq 0 ]; then
    print_result PASS "payment" "profile expects manual billing and no active payment-looking options were detected"
  else
    print_result WARN "payment" "$payment_option_count payment-looking options found; verify automatic payment is disabled in admin console"
  fi
else
  print_result WARN "payment" "profile does not explicitly require manual billing with disabled automatic payment"
fi

if [ -n "${NEW_API_TEST_TOKEN:-}" ]; then
  models_body="$(mktemp)"
  curl_err="$(mktemp)"
  trap 'rm -f "$models_body" "$curl_err"' EXIT
  set +e
  http_code="$(curl -sS --max-time "${NEW_API_TEST_TIMEOUT_SECONDS:-20}" -o "$models_body" -w '%{http_code}' \
    -H "Authorization: Bearer $NEW_API_TEST_TOKEN" \
    "$BASE_URL/v1/models" 2>"$curl_err")"
  curl_status="$?"
  set -e
  if [ "$curl_status" -ne 0 ]; then
    print_result FAIL "models api" "curl_exit=$curl_status"
  elif [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
    print_result FAIL "models api" "http=$http_code"
  elif grep -q "\"$MODEL\"" "$models_body"; then
    print_result PASS "models api" "$MODEL visible through /v1/models"
  else
    print_result FAIL "models api" "$MODEL not visible through /v1/models"
  fi
else
  print_result WARN "models api" "NEW_API_TEST_TOKEN is not set; skipped /v1/models visibility check"
fi

printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
