#!/usr/bin/env sh
set -eu

BASE_URL="${NEW_API_BASE_URL:-http://localhost:${NEW_API_DEV_PORT:-3100}}"
MODEL="${NEW_API_TEST_MODEL:-gpt-4o-mini}"

echo "checking New API status at $BASE_URL"
curl -fsS "$BASE_URL/api/status" >/dev/null
echo "status endpoint ok"

if [ -z "${NEW_API_TEST_TOKEN:-}" ]; then
  echo "NEW_API_TEST_TOKEN is not set; skipping authenticated /v1 checks"
  echo "set NEW_API_TEST_TOKEN=sk-... after creating a New API token to run model and chat tests"
  exit 0
fi

auth_header="Authorization: Bearer $NEW_API_TEST_TOKEN"

echo "checking /v1/models"
curl -fsS -H "$auth_header" "$BASE_URL/v1/models" >/dev/null
echo "models endpoint ok"

tmp_response="$(mktemp)"
trap 'rm -f "$tmp_response"' EXIT

echo "checking non-stream chat completion with model $MODEL"
curl -fsS \
  -H "$auth_header" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: phase1-ok\"}],\"max_tokens\":20,\"stream\":false}" \
  "$BASE_URL/v1/chat/completions" > "$tmp_response"

if ! grep -q '"choices"' "$tmp_response"; then
  echo "non-stream response did not contain choices" >&2
  cat "$tmp_response" >&2
  exit 1
fi
echo "non-stream chat completion ok"

echo "checking stream chat completion with model $MODEL"
curl -fsS -N \
  -H "$auth_header" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with one short sentence.\"}],\"max_tokens\":20,\"stream\":true}" \
  "$BASE_URL/v1/chat/completions" | grep -m 1 '^data: ' >/dev/null
echo "stream chat completion ok"
