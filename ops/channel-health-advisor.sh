#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${NEW_API_ENV_FILE:-$ROOT_DIR/.env}"
PROFILE_FILE="${1:-}"

pass_count=0
warn_count=0
fail_count=0

print_result() {
  status="$1"
  name="$2"
  detail="$3"
  case "$status" in
    PASS) pass_count=$((pass_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
    FAIL) fail_count=$((fail_count + 1)) ;;
  esac
  printf '%s %-24s %s\n' "$status" "$name" "$detail"
}

usage() {
  echo "usage: $0 <health-profile.json>" >&2
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

optional_number() {
  key="$1"
  default="$2"
  value="$(jq -er ".$key | numbers" "$PROFILE_FILE" 2>/dev/null || true)"
  if [ -z "$value" ]; then
    printf '%s' "$default"
  else
    printf '%s' "$value"
  fi
}

PROFILE_NAME="$(require_string name)"
GROUP="$(require_string group)"
MODEL="$(require_string model)"
MODE="$(jq -r '.mode // "development"' "$PROFILE_FILE")"
WINDOW_HOURS="$(require_number window_hours)"
MIN_ENABLED_CHANNELS="$(require_number min_enabled_channels)"
MIN_SAMPLE_COUNT="$(require_number min_sample_count)"
MAX_ERROR_RATE="$(require_number thresholds.max_error_rate)"
MIN_ERROR_COUNT_FOR_RATE="$(optional_number thresholds.min_error_count_for_rate "$MIN_SAMPLE_COUNT")"
MAX_RECENT_ERRORS="$(require_number thresholds.max_recent_errors)"
MAX_P95_USE_TIME_SECONDS="$(require_number thresholds.max_p95_use_time_seconds)"
MAX_RESPONSE_TIME_MS="$(require_number thresholds.max_response_time_ms)"
MAX_TEST_AGE_HOURS="$(require_number thresholds.max_test_age_hours)"

case "$MODE" in
  development|production) ;;
  *)
    echo "profile.mode must be development or production" >&2
    exit 1
    ;;
esac

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

health_sql="
with params as (
  select (extract(epoch from now())::bigint - ($WINDOW_HOURS * 3600)) as window_start
),
matched_channels as (
  select
    c.id,
    c.name,
    c.status,
    coalesce(c.priority, 0) as priority,
    coalesce(c.weight, 0) as weight,
    coalesce(c.response_time, 0) as response_time,
    coalesce(c.test_time, 0) as test_time,
    coalesce(c.used_quota, 0) as used_quota,
    bool_or(a.enabled) as ability_enabled
  from channels c
  join abilities a on a.channel_id = c.id
  where a.\"group\" = $GROUP_SQL
    and a.model = $MODEL_SQL
  group by c.id
),
channel_logs as (
  select
    m.id as channel_id,
    count(l.*) filter (where l.type in (2, 5)) as request_count,
    count(l.*) filter (where l.type = 5) as error_count,
    coalesce(
      round(
        (count(l.*) filter (where l.type = 5))::numeric /
        nullif((count(l.*) filter (where l.type in (2, 5)))::numeric, 0),
        4
      ),
      0
    ) as error_rate,
    coalesce(
      ceil(
        percentile_cont(0.95) within group (order by l.use_time)
        filter (where l.type in (2, 5))
      )::int,
      0
    ) as p95_use_time
  from matched_channels m
  left join logs l on l.channel_id = m.id
    and l.created_at >= (select window_start from params)
  group by m.id
),
channel_health as (
  select
    m.*,
    greatest(0, floor((extract(epoch from now())::bigint - nullif(m.test_time, 0)) / 3600))::int as test_age_hours,
    coalesce(cl.request_count, 0) as request_count,
    coalesce(cl.error_count, 0) as error_count,
    coalesce(cl.error_rate, 0) as error_rate,
    coalesce(cl.p95_use_time, 0) as p95_use_time
  from matched_channels m
  left join channel_logs cl on cl.channel_id = m.id
)
select json_build_object(
  'matched_channel_count', coalesce((select count(*) from channel_health), 0),
  'enabled_channel_count', coalesce((select count(*) from channel_health where status = 1 and ability_enabled), 0),
  'disabled_channel_count', coalesce((select count(*) from channel_health where status <> 1 or not ability_enabled), 0),
  'window_request_count', coalesce((select sum(request_count) from channel_health), 0),
  'window_error_count', coalesce((select sum(error_count) from channel_health), 0),
  'window_error_rate', coalesce(
    round(
      (select sum(error_count) from channel_health)::numeric /
      nullif((select sum(request_count) from channel_health)::numeric, 0),
      4
    ),
    0
  ),
  'channels', coalesce((
    select json_agg(json_build_object(
      'id', id,
      'name', name,
      'status', status,
      'ability_enabled', ability_enabled,
      'priority', priority,
      'weight', weight,
      'response_time', response_time,
      'test_age_hours', test_age_hours,
      'window_request_count', request_count,
      'window_error_count', error_count,
      'window_error_rate', error_rate,
      'p95_use_time', p95_use_time,
      'used_quota', used_quota
    ) order by status asc, priority desc, weight desc, id asc)
    from channel_health
  ), '[]'::json)
)::text;
"

printf 'Channel health advisor\n'
printf 'Profile: %s\n' "$PROFILE_NAME"
printf 'Group:   %s\n' "$GROUP"
printf 'Model:   %s\n' "$MODEL"
printf 'Mode:    %s\n' "$MODE"
printf 'Window:  %sh\n\n' "$WINDOW_HOURS"

db_json="$(compose_psql_json "$health_sql" | tr -d '\r' | sed '/^[[:space:]]*$/d' | tail -n 1)"
if ! printf '%s' "$db_json" | jq empty >/dev/null 2>&1; then
  print_result FAIL "database" "health query did not return JSON"
  printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"
  exit 1
fi

enabled_channel_count="$(printf '%s' "$db_json" | jq -r '.enabled_channel_count // 0')"
disabled_channel_count="$(printf '%s' "$db_json" | jq -r '.disabled_channel_count // 0')"
window_request_count="$(printf '%s' "$db_json" | jq -r '.window_request_count // 0')"
window_error_count="$(printf '%s' "$db_json" | jq -r '.window_error_count // 0')"
window_error_rate="$(printf '%s' "$db_json" | jq -r '.window_error_rate // 0')"
max_p95_use_time="$(printf '%s' "$db_json" | jq -r '[.channels[].p95_use_time] | max // 0')"
max_response_time="$(printf '%s' "$db_json" | jq -r '[.channels[].response_time] | max // 0')"

print_result PASS "profile" "schema ok"

if [ "$enabled_channel_count" -ge "$MIN_ENABLED_CHANNELS" ]; then
  print_result PASS "enabled channels" "$enabled_channel_count >= $MIN_ENABLED_CHANNELS"
else
  print_result FAIL "enabled channels" "$enabled_channel_count < $MIN_ENABLED_CHANNELS; add or re-enable a channel ability for group=$GROUP model=$MODEL"
fi

if [ "$disabled_channel_count" -gt 0 ]; then
  print_result WARN "disabled channels" "$disabled_channel_count matched channels are disabled or ability-disabled"
else
  print_result PASS "disabled channels" "no disabled matched channels"
fi

if [ "$window_request_count" -lt "$MIN_SAMPLE_COUNT" ]; then
  print_result WARN "sample size" "$window_request_count < $MIN_SAMPLE_COUNT requests in ${WINDOW_HOURS}h; health confidence is low"
else
  print_result PASS "sample size" "$window_request_count requests in ${WINDOW_HOURS}h"
fi

if [ "$window_request_count" -lt "$MIN_SAMPLE_COUNT" ]; then
  if awk "BEGIN { exit !($window_error_rate > $MAX_ERROR_RATE) }"; then
    print_result WARN "error rate" "$window_error_rate > $MAX_ERROR_RATE but sample size is below $MIN_SAMPLE_COUNT"
  else
    print_result PASS "error rate" "$window_error_rate <= $MAX_ERROR_RATE"
  fi
elif [ "$window_error_count" -lt "$MIN_ERROR_COUNT_FOR_RATE" ]; then
  if awk "BEGIN { exit !($window_error_rate > $MAX_ERROR_RATE) }"; then
    print_result WARN "error rate" "$window_error_rate > $MAX_ERROR_RATE but errors $window_error_count < $MIN_ERROR_COUNT_FOR_RATE"
  else
    print_result PASS "error rate" "$window_error_rate <= $MAX_ERROR_RATE"
  fi
elif awk "BEGIN { exit !($window_error_rate <= $MAX_ERROR_RATE) }"; then
  print_result PASS "error rate" "$window_error_rate <= $MAX_ERROR_RATE"
else
  print_result FAIL "error rate" "$window_error_rate > $MAX_ERROR_RATE; inspect recent error logs and upstream provider status"
fi

if [ "$window_error_count" -le "$MAX_RECENT_ERRORS" ]; then
  print_result PASS "recent errors" "$window_error_count <= $MAX_RECENT_ERRORS"
elif [ "$MODE" = "development" ]; then
  print_result WARN "recent errors" "$window_error_count > $MAX_RECENT_ERRORS; noisy setup traffic is tolerated in development mode"
else
  print_result FAIL "recent errors" "$window_error_count > $MAX_RECENT_ERRORS; consider running channel test and checking auto-ban settings"
fi

if [ "$max_p95_use_time" -le "$MAX_P95_USE_TIME_SECONDS" ] && [ "$max_response_time" -le "$MAX_RESPONSE_TIME_MS" ]; then
  print_result PASS "latency" "p95=${max_p95_use_time}s response_time=${max_response_time}ms"
elif [ "$MODE" = "development" ]; then
  print_result WARN "latency" "p95=${max_p95_use_time}s or response_time=${max_response_time}ms exceeded development threshold"
else
  print_result FAIL "latency" "p95=${max_p95_use_time}s or response_time=${max_response_time}ms exceeded production threshold"
fi

printf '\nChannels:\n'
printf '%s\n' "$db_json" | jq -c '.channels[]' | while IFS= read -r channel; do
  id="$(printf '%s' "$channel" | jq -r '.id')"
  name="$(printf '%s' "$channel" | jq -r '.name')"
  status="$(printf '%s' "$channel" | jq -r '.status')"
  ability_enabled="$(printf '%s' "$channel" | jq -r '.ability_enabled')"
  priority="$(printf '%s' "$channel" | jq -r '.priority')"
  weight="$(printf '%s' "$channel" | jq -r '.weight')"
  response_time="$(printf '%s' "$channel" | jq -r '.response_time')"
  test_age_hours="$(printf '%s' "$channel" | jq -r '.test_age_hours')"
  request_count="$(printf '%s' "$channel" | jq -r '.window_request_count')"
  error_count="$(printf '%s' "$channel" | jq -r '.window_error_count')"
  error_rate="$(printf '%s' "$channel" | jq -r '.window_error_rate')"
  p95_use_time="$(printf '%s' "$channel" | jq -r '.p95_use_time')"
  used_quota="$(printf '%s' "$channel" | jq -r '.used_quota')"

  printf -- '- #%s %s status=%s ability=%s priority=%s weight=%s response_time_ms=%s test_age_h=%s requests=%s errors=%s error_rate=%s p95_use_time_s=%s used_quota=%s\n' \
    "$id" "$name" "$status" "$ability_enabled" "$priority" "$weight" "$response_time" "$test_age_hours" "$request_count" "$error_count" "$error_rate" "$p95_use_time" "$used_quota"

  if [ "$status" -ne 1 ] || [ "$ability_enabled" != "true" ]; then
    printf '  recommendation: re-enable only after upstream key, balance, and model mapping are verified.\n'
  fi
  if [ "$response_time" -gt "$MAX_RESPONSE_TIME_MS" ]; then
    printf '  recommendation: response time exceeds %sms; lower weight or move out of default group.\n' "$MAX_RESPONSE_TIME_MS"
  fi
  if [ "$test_age_hours" -gt "$MAX_TEST_AGE_HOURS" ]; then
    printf '  recommendation: channel test is older than %sh; run New API channel test from admin console.\n' "$MAX_TEST_AGE_HOURS"
  fi
  if awk "BEGIN { exit !($error_rate > $MAX_ERROR_RATE) }"; then
    printf '  recommendation: error rate exceeds %s; inspect logs before exposing this channel to users.\n' "$MAX_ERROR_RATE"
  fi
  if [ "$p95_use_time" -gt "$MAX_P95_USE_TIME_SECONDS" ]; then
    printf '  recommendation: p95 use_time exceeds %ss; consider lowering priority or adding capacity.\n' "$MAX_P95_USE_TIME_SECONDS"
  fi
done

printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
