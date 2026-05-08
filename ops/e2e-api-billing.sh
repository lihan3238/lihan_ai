#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${NEW_API_ENV_FILE:-$ROOT_DIR/.env}"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
COMPOSE_DEV_FILE="$ROOT_DIR/docker-compose.dev.yml"

BASE_URL="${NEW_API_BASE_URL:-http://localhost:${NEW_API_DEV_PORT:-3100}}"
MODEL="${NEW_API_TEST_MODEL:-glm-5.1}"
MAX_TOKENS="${NEW_API_TEST_MAX_TOKENS:-24}"
TIMEOUT_SECONDS="${NEW_API_TEST_TIMEOUT_SECONDS:-45}"
POLL_SECONDS="${NEW_API_TEST_POLL_SECONDS:-24}"
MISSING_MODEL="${NEW_API_TEST_MISSING_MODEL:-${MODEL}-e2e-missing}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

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

  printf '%s %-34s %s\n' "$status" "$name" "$detail"
}

preview_file() {
  file="$1"
  if [ ! -s "$file" ]; then
    printf 'empty response'
    return
  fi

  tr '\n' ' ' < "$file" | cut -c 1-240
}

die_usage() {
  printf 'API billing e2e\n'
  printf 'Base URL: %s\n' "$BASE_URL"
  printf 'Model:    %s\n\n' "$MODEL"
  printf 'NEW_API_TEST_TOKEN is not set\n' >&2
  printf 'Create a low-quota New API test token, then run:\n' >&2
  printf '  NEW_API_TEST_TOKEN=... NEW_API_TEST_MODEL=%s bash ops/e2e-api-billing.sh\n' "$MODEL" >&2
  exit 2
}

if [ -z "${NEW_API_TEST_TOKEN:-}" ]; then
  die_usage
fi

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-newapi}"
POSTGRES_DB="${POSTGRES_DB:-newapi}"

sql_literal() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

TOKEN_SQL="$(sql_literal "$NEW_API_TEST_TOKEN")"
MODEL_SQL="$(sql_literal "$MODEL")"
MISSING_MODEL_SQL="$(sql_literal "$MISSING_MODEL")"

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" -f "$COMPOSE_DEV_FILE" "$@"
}

psql_query() {
  sql="$1"
  compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "$sql"
}

psql_scalar() {
  psql_query "$1" | tr -d '\r' | sed '/^[[:space:]]*$/d' | tail -n 1
}

get_token_row() {
  psql_scalar "select id || '|' || user_id || '|' || coalesce(used_quota,0) from tokens where key = $TOKEN_SQL and deleted_at is null limit 1;"
}

get_user_used_quota() {
  user_id="$1"
  psql_scalar "select coalesce(used_quota,0) from users where id = $user_id and deleted_at is null;"
}

get_channel_used_quota_total() {
  psql_scalar "select coalesce(sum(used_quota),0) from channels;"
}

get_success_log_summary() {
  token_id="$1"
  started_at="$2"
  psql_scalar "select count(*) || '|' || coalesce(sum(quota),0) || '|' || coalesce(sum(prompt_tokens),0) || '|' || coalesce(sum(completion_tokens),0) from logs where type = 2 and token_id = $token_id and model_name = $MODEL_SQL and created_at >= $started_at;"
}

get_failure_log_row() {
  token_id="$1"
  started_at="$2"
  psql_scalar "select id || '|' || coalesce(quota,0) || '|' || coalesce(content,'') from logs where token_id = $token_id and model_name = $MISSING_MODEL_SQL and created_at >= $started_at order by id desc limit 1;"
}

request_json_success() {
  name="$1"
  method="$2"
  url="$3"
  auth_mode="$4"
  body="$5"
  expect_pattern="$6"
  response_file="$tmp_dir/${name}.body"

  set +e
  case "$auth_mode" in
    openai)
      http_code="$(curl -sS --max-time "$TIMEOUT_SECONDS" -o "$response_file" -w '%{http_code}' \
        -X "$method" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $NEW_API_TEST_TOKEN" \
        -d "$body" \
        "$url" 2>"$tmp_dir/${name}.curlerr")"
      ;;
    anthropic)
      http_code="$(curl -sS --max-time "$TIMEOUT_SECONDS" -o "$response_file" -w '%{http_code}' \
        -X "$method" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $NEW_API_TEST_TOKEN" \
        -H "anthropic-version: 2023-06-01" \
        -d "$body" \
        "$url" 2>"$tmp_dir/${name}.curlerr")"
      ;;
  esac
  curl_status="$?"
  set -e

  if [ "$curl_status" -ne 0 ]; then
    detail="$(preview_file "$tmp_dir/${name}.curlerr")"
    print_result FAIL "$name" "curl_exit=$curl_status $detail"
    return
  fi

  if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
    detail="$(preview_file "$response_file")"
    print_result FAIL "$name" "http=$http_code $detail"
    return
  fi

  if [ -n "$expect_pattern" ] && ! grep -q "$expect_pattern" "$response_file"; then
    detail="$(preview_file "$response_file")"
    print_result FAIL "$name" "http=$http_code missing=$expect_pattern $detail"
    return
  fi

  print_result PASS "$name" "http=$http_code"
}

request_stream_success() {
  name="$1"
  url="$2"
  auth_mode="$3"
  body="$4"
  response_file="$tmp_dir/${name}.body"

  set +e
  case "$auth_mode" in
    openai)
      curl -sS -N --max-time "$TIMEOUT_SECONDS" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $NEW_API_TEST_TOKEN" \
        -d "$body" \
        "$url" > "$response_file" 2>"$tmp_dir/${name}.curlerr"
      ;;
    anthropic)
      curl -sS -N --max-time "$TIMEOUT_SECONDS" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $NEW_API_TEST_TOKEN" \
        -H "anthropic-version: 2023-06-01" \
        -d "$body" \
        "$url" > "$response_file" 2>"$tmp_dir/${name}.curlerr"
      ;;
  esac
  curl_status="$?"
  set -e

  if [ "$curl_status" -ne 0 ] && [ "$curl_status" -ne 28 ]; then
    detail="$(preview_file "$tmp_dir/${name}.curlerr")"
    print_result FAIL "$name" "curl_exit=$curl_status $detail"
    return
  fi

  if grep -q '"error"' "$response_file"; then
    detail="$(preview_file "$response_file")"
    print_result FAIL "$name" "$detail"
    return
  fi

  if grep -q '^data: ' "$response_file"; then
    print_result PASS "$name" "received SSE data"
    return
  fi

  if grep -q '^event: ' "$response_file"; then
    print_result PASS "$name" "received Anthropic event stream"
    return
  fi

  detail="$(preview_file "$response_file")"
  print_result FAIL "$name" "no stream payload: $detail"
}

request_expected_failure() {
  name="$1"
  body='{"model":"'"$MISSING_MODEL"'","messages":[{"role":"user","content":"This request should fail because the model does not exist."}],"max_tokens":1,"stream":false}'
  response_file="$tmp_dir/${name}.body"

  set +e
  http_code="$(curl -sS --max-time "$TIMEOUT_SECONDS" -o "$response_file" -w '%{http_code}' \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $NEW_API_TEST_TOKEN" \
    -d "$body" \
    "$BASE_URL/v1/chat/completions" 2>"$tmp_dir/${name}.curlerr")"
  curl_status="$?"
  set -e

  if [ "$curl_status" -ne 0 ]; then
    detail="$(preview_file "$tmp_dir/${name}.curlerr")"
    print_result FAIL "$name" "curl_exit=$curl_status $detail"
    return
  fi

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    detail="$(preview_file "$response_file")"
    print_result FAIL "$name" "unexpected http=$http_code $detail"
    return
  fi

  if grep -qi 'model_not_found\|No available channel\|无可用渠道\|模型不存在' "$response_file"; then
    print_result PASS "$name" "http=$http_code expected model/channel error"
    return
  fi

  detail="$(preview_file "$response_file")"
  print_result FAIL "$name" "http=$http_code unexpected error: $detail"
}

poll_success_accounting() {
  token_id="$1"
  user_id="$2"
  started_at="$3"
  token_before="$4"
  user_before="$5"
  channel_before="$6"

  deadline=$(( $(date +%s) + POLL_SECONDS ))
  while :; do
    token_now="$(get_token_row | cut -d '|' -f 3)"
    user_now="$(get_user_used_quota "$user_id")"
    channel_now="$(get_channel_used_quota_total)"
    log_summary="$(get_success_log_summary "$token_id" "$started_at")"
    log_count="$(printf '%s' "$log_summary" | cut -d '|' -f 1)"
    log_quota="$(printf '%s' "$log_summary" | cut -d '|' -f 2)"

    if [ "$log_count" -ge 1 ] && [ "$log_quota" -gt 0 ] && \
      [ "$token_now" -gt "$token_before" ] && \
      [ "$user_now" -gt "$user_before" ] && \
      [ "$channel_now" -gt "$channel_before" ]; then
      print_result PASS "billing accounting" "logs=$log_count quota=$log_quota token=$token_before->$token_now user=$user_before->$user_now channels=$channel_before->$channel_now"
      return
    fi

    if [ "$(date +%s)" -ge "$deadline" ]; then
      print_result FAIL "billing accounting" "logs=$log_count quota=$log_quota token=$token_before->$token_now user=$user_before->$user_now channels=$channel_before->$channel_now"
      return
    fi

    sleep 2
  done
}

verify_failure_accounting() {
  token_id="$1"
  user_id="$2"
  started_at="$3"
  token_before="$4"
  user_before="$5"
  channel_before="$6"

  sleep 2
  token_now="$(get_token_row | cut -d '|' -f 3)"
  user_now="$(get_user_used_quota "$user_id")"
  channel_now="$(get_channel_used_quota_total)"
  failure_log="$(get_failure_log_row "$token_id" "$started_at")"

  if [ "$token_now" -ne "$token_before" ] || [ "$user_now" -ne "$user_before" ] || [ "$channel_now" -ne "$channel_before" ]; then
    print_result FAIL "failure no-charge" "token=$token_before->$token_now user=$user_before->$user_now channels=$channel_before->$channel_now"
    return
  fi

  if [ -z "$failure_log" ]; then
    print_result WARN "failure db error log" "New API did not persist a DB error log for route miss"
    print_result PASS "failure no-charge" "quotas unchanged"
    return
  fi

  failure_quota="$(printf '%s' "$failure_log" | cut -d '|' -f 2)"
  if [ "$failure_quota" -ne 0 ]; then
    print_result FAIL "failure no-charge" "error log quota=$failure_quota"
    return
  fi

  print_result PASS "failure no-charge" "error log quota=0 and quotas unchanged"
}

settle_accounting() {
  token_id="$1"
  user_id="$2"
  deadline=$(( $(date +%s) + POLL_SECONDS ))

  while :; do
    token_a="$(get_token_row | cut -d '|' -f 3)"
    user_a="$(get_user_used_quota "$user_id")"
    channel_a="$(get_channel_used_quota_total)"
    sleep 8
    token_b="$(get_token_row | cut -d '|' -f 3)"
    user_b="$(get_user_used_quota "$user_id")"
    channel_b="$(get_channel_used_quota_total)"

    if [ "$token_a" -eq "$token_b" ] && [ "$user_a" -eq "$user_b" ] && [ "$channel_a" -eq "$channel_b" ]; then
      print_result PASS "accounting settled" "token=$token_b user=$user_b channels=$channel_b"
      return
    fi

    if [ "$(date +%s)" -ge "$deadline" ]; then
      print_result WARN "accounting settled" "still changing token=$token_a->$token_b user=$user_a->$user_b channels=$channel_a->$channel_b"
      return
    fi
  done
}

printf 'API billing e2e\n'
printf 'Base URL: %s\n' "$BASE_URL"
printf 'Model:    %s\n' "$MODEL"
printf 'Max tok:  %s\n\n' "$MAX_TOKENS"

if ! command -v docker >/dev/null 2>&1; then
  print_result FAIL "docker" "docker is not installed or not in PATH"
  printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  print_result FAIL "env file" "missing $ENV_FILE"
  printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"
  exit 1
fi

if ! compose ps postgres >/dev/null 2>&1; then
  print_result FAIL "postgres container" "docker compose postgres service is not available"
  printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"
  exit 1
fi

token_row="$(get_token_row)"
if [ -z "$token_row" ]; then
  print_result FAIL "test token lookup" "token not found in New API database"
  printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"
  exit 1
fi

TOKEN_ID="$(printf '%s' "$token_row" | cut -d '|' -f 1)"
USER_ID="$(printf '%s' "$token_row" | cut -d '|' -f 2)"
TOKEN_USED_BEFORE="$(printf '%s' "$token_row" | cut -d '|' -f 3)"
USER_USED_BEFORE="$(get_user_used_quota "$USER_ID")"
CHANNEL_USED_BEFORE="$(get_channel_used_quota_total)"
print_result PASS "database baseline" "token_id=$TOKEN_ID user_id=$USER_ID token_used=$TOKEN_USED_BEFORE user_used=$USER_USED_BEFORE channel_used_total=$CHANNEL_USED_BEFORE"

success_started_at="$(date +%s)"
chat_body='{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Reply with exactly: e2e-api-billing-ok"}],"max_tokens":'"$MAX_TOKENS"',"stream":false}'
chat_stream_body='{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Reply with one short sentence."}],"max_tokens":'"$MAX_TOKENS"',"stream":true}'
messages_body='{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Reply with exactly: e2e-api-billing-ok"}],"max_tokens":'"$MAX_TOKENS"',"stream":false}'
messages_stream_body='{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Reply with one short sentence."}],"max_tokens":'"$MAX_TOKENS"',"stream":true}'

request_json_success "chat non-stream" "POST" "$BASE_URL/v1/chat/completions" "openai" "$chat_body" '"choices"'
request_stream_success "chat stream" "$BASE_URL/v1/chat/completions" "openai" "$chat_stream_body"
request_json_success "messages non-stream" "POST" "$BASE_URL/v1/messages" "anthropic" "$messages_body" '"content"'
request_stream_success "messages stream" "$BASE_URL/v1/messages" "anthropic" "$messages_stream_body"
request_stream_success "messages beta stream" "$BASE_URL/v1/messages?beta=true" "anthropic" "$messages_stream_body"

poll_success_accounting "$TOKEN_ID" "$USER_ID" "$success_started_at" "$TOKEN_USED_BEFORE" "$USER_USED_BEFORE" "$CHANNEL_USED_BEFORE"
settle_accounting "$TOKEN_ID" "$USER_ID"

failure_token_before="$(get_token_row | cut -d '|' -f 3)"
failure_user_before="$(get_user_used_quota "$USER_ID")"
failure_channel_before="$(get_channel_used_quota_total)"
failure_started_at="$(date +%s)"
request_expected_failure "missing model failure"
verify_failure_accounting "$TOKEN_ID" "$USER_ID" "$failure_started_at" "$failure_token_before" "$failure_user_before" "$failure_channel_before"

printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"

if [ "$fail_count" -ne 0 ]; then
  printf '\nHints: check channel status, model casing, group abilities, token quota, and upstream streaming support.\n' >&2
  exit 1
fi
