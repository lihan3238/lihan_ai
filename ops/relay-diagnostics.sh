#!/usr/bin/env sh
set -eu

BASE_URL="${NEW_API_BASE_URL:-http://localhost:${NEW_API_DEV_PORT:-3100}}"
MODEL="${NEW_API_TEST_MODEL:-gpt-4o-mini}"
MAX_TOKENS="${NEW_API_TEST_MAX_TOKENS:-32}"
TIMEOUT_SECONDS="${NEW_API_TEST_TIMEOUT_SECONDS:-45}"

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

request_json() {
  name="$1"
  method="$2"
  url="$3"
  auth_mode="$4"
  body="$5"
  expect_pattern="$6"
  response_file="$tmp_dir/${name}.body"
  code_file="$tmp_dir/${name}.code"

  set +e
  if [ -n "$body" ]; then
    case "$auth_mode" in
      none)
        http_code="$(curl -sS --max-time "$TIMEOUT_SECONDS" -o "$response_file" -w '%{http_code}' \
          -X "$method" \
          -H "Content-Type: application/json" \
          -d "$body" \
          "$url" 2>"$tmp_dir/${name}.curlerr")"
        ;;
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
  else
    case "$auth_mode" in
      none)
        http_code="$(curl -sS --max-time "$TIMEOUT_SECONDS" -o "$response_file" -w '%{http_code}' \
          -X "$method" \
          "$url" 2>"$tmp_dir/${name}.curlerr")"
        ;;
      openai)
        http_code="$(curl -sS --max-time "$TIMEOUT_SECONDS" -o "$response_file" -w '%{http_code}' \
          -X "$method" \
          -H "Authorization: Bearer $NEW_API_TEST_TOKEN" \
          "$url" 2>"$tmp_dir/${name}.curlerr")"
        ;;
      anthropic)
        http_code="$(curl -sS --max-time "$TIMEOUT_SECONDS" -o "$response_file" -w '%{http_code}' \
          -X "$method" \
          -H "x-api-key: $NEW_API_TEST_TOKEN" \
          -H "anthropic-version: 2023-06-01" \
          "$url" 2>"$tmp_dir/${name}.curlerr")"
        ;;
    esac
  fi
  curl_status="$?"
  set -e
  printf '%s' "$http_code" > "$code_file"

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

request_stream() {
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
  print_result FAIL "$name" "no stream first payload: $detail"
}

printf 'Relay diagnostics\n'
printf 'Base URL: %s\n' "$BASE_URL"
printf 'Model:    %s\n\n' "$MODEL"

request_json "status" "GET" "$BASE_URL/api/status" "none" "" '"success"'

if [ -z "${NEW_API_TEST_TOKEN:-}" ]; then
  print_result FAIL "auth token" "NEW_API_TEST_TOKEN is not set"
  printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"
  exit 2
fi

chat_body='{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Reply with exactly: relay-diagnostics-ok"}],"max_tokens":'"$MAX_TOKENS"',"stream":false}'
chat_stream_body='{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Reply with one short sentence."}],"max_tokens":'"$MAX_TOKENS"',"stream":true}'
messages_body='{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Reply with exactly: relay-diagnostics-ok"}],"max_tokens":'"$MAX_TOKENS"',"stream":false}'
messages_stream_body='{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Reply with one short sentence."}],"max_tokens":'"$MAX_TOKENS"',"stream":true}'
count_tokens_body='{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Count this short diagnostic prompt."}]}'

request_json "openai models" "GET" "$BASE_URL/v1/models" "openai" "" '"data"'
request_json "chat non-stream" "POST" "$BASE_URL/v1/chat/completions" "openai" "$chat_body" '"choices"'
request_stream "chat stream" "$BASE_URL/v1/chat/completions" "openai" "$chat_stream_body"
request_json "messages non-stream" "POST" "$BASE_URL/v1/messages" "anthropic" "$messages_body" '"content"'
request_stream "messages stream" "$BASE_URL/v1/messages" "anthropic" "$messages_stream_body"
request_stream "messages beta stream" "$BASE_URL/v1/messages?beta=true" "anthropic" "$messages_stream_body"

count_response="$tmp_dir/count_tokens.body"
set +e
count_code="$(curl -sS --max-time "$TIMEOUT_SECONDS" -o "$count_response" -w '%{http_code}' \
  -X POST \
  -H "Content-Type: application/json" \
  -H "x-api-key: $NEW_API_TEST_TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -d "$count_tokens_body" \
  "$BASE_URL/v1/messages/count_tokens?beta=true" 2>"$tmp_dir/count_tokens.curlerr")"
count_status="$?"
set -e

if [ "$count_status" -ne 0 ]; then
  detail="$(preview_file "$tmp_dir/count_tokens.curlerr")"
  print_result WARN "messages count_tokens" "curl_exit=$count_status $detail"
elif [ "$count_code" -lt 200 ] || [ "$count_code" -ge 300 ]; then
  detail="$(preview_file "$count_response")"
  print_result WARN "messages count_tokens" "http=$count_code $detail"
elif grep -q '"input_tokens"' "$count_response"; then
  print_result PASS "messages count_tokens" "http=$count_code"
else
  detail="$(preview_file "$count_response")"
  print_result WARN "messages count_tokens" "http=$count_code unexpected response: $detail"
fi

printf '\nSummary: pass=%s warn=%s fail=%s\n' "$pass_count" "$warn_count" "$fail_count"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
