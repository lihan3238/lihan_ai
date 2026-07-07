#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"
CPA_MANAGEMENT_BASE_URL="${CPA_MANAGEMENT_BASE_URL:-http://127.0.0.1:8317}"

usage() {
  cat >&2 <<'USAGE'
usage: ops/cpa-quota-refresh-all.sh

Refreshes all enabled CPA quota credentials with known quota endpoints and
publishes one sanitized public quota snapshot.

Environment:
  ENV_FILE                  Default .env.production.
  CPA_CONFIG_PATH           CPA config.yaml path; read from ENV_FILE when set.
  CPA_PUBLIC_PATH           Public snapshot directory; read from ENV_FILE when set.
  CPA_MGMT_KEY              Optional management key override.
  CPA_MANAGEMENT_KEY        Optional management key override.
  MANAGEMENT_PASSWORD       Optional legacy management key override.
  CPA_MANAGEMENT_BASE_URL   Default http://127.0.0.1:8317.
  CPA_QUOTA_URL_CODEX       Override Codex/OpenAI quota URL.
  CPA_QUOTA_URL_OPENAI      Override OpenAI quota URL.
  CPA_QUOTA_URL_CHATGPT     Override ChatGPT quota URL.
  CPA_QUOTA_URL_CLAUDE      Override Claude quota URL.
USAGE
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage
    exit 2
    ;;
esac

case "$ENV_FILE" in
  /*) ENV_FILE_PATH="$ENV_FILE" ;;
  *) ENV_FILE_PATH="$ROOT_DIR/$ENV_FILE" ;;
esac

if [ -f "$ENV_FILE_PATH" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE_PATH"
  set +a
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "$1 is required" >&2
    exit 1
  }
}

need_cmd curl
need_cmd jq
need_cmd python3

CPA_MANAGEMENT_BASE_URL="${CPA_MANAGEMENT_BASE_URL%/}"
CPA_CONFIG_PATH="${CPA_CONFIG_PATH:-${CPA_AUTH_PATH:-/opt/lihan_ai/data/cpa}/config.yaml}"
CPA_PUBLIC_PATH="${CPA_PUBLIC_PATH:-${CPA_AUTH_PATH:-/opt/lihan_ai/data/cpa}/public}"

read_config_management_key() {
  [ -f "$CPA_CONFIG_PATH" ] || return 0
  python3 - "$CPA_CONFIG_PATH" <<'PY'
import re
import sys

path = sys.argv[1]
try:
    lines = open(path, "r", encoding="utf-8").read().splitlines()
except OSError:
    sys.exit(0)

in_remote = False
remote_indent = -1
for line in lines:
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    indent = len(line) - len(line.lstrip(" "))
    stripped = line.strip()
    if re.match(r"^remote-management\s*:\s*(#.*)?$", stripped):
        in_remote = True
        remote_indent = indent
        continue
    if in_remote and indent <= remote_indent:
        in_remote = False
    if not in_remote:
        continue
    match = re.match(r"^secret-key\s*:\s*(.*?)\s*(?:#.*)?$", stripped)
    if not match:
        continue
    value = match.group(1).strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        value = value[1:-1]
    if value:
        print(value)
    sys.exit(0)
PY
}

management_key="${CPA_MGMT_KEY:-${CPA_MANAGEMENT_KEY:-${MANAGEMENT_PASSWORD:-}}}"
if [ -z "$management_key" ]; then
  management_key="$(read_config_management_key || true)"
fi

if [ -z "$management_key" ]; then
  if [ -t 0 ]; then
    printf "CPA management key: " >&2
    stty -echo
    IFS= read -r management_key
    stty echo
    printf "\n" >&2
  else
    echo "CPA management key not found in environment or $CPA_CONFIG_PATH" >&2
    exit 1
  fi
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

curl_config="$tmp_dir/curl.conf"
auth_json="$tmp_dir/auth-files.json"
entries_json="$tmp_dir/entries.json"
results_dir="$tmp_dir/results"
merged_json="$tmp_dir/merged-quota.json"
mkdir -p "$results_dir"
chmod 700 "$tmp_dir" "$results_dir" 2>/dev/null || true

cat > "$curl_config" <<EOF
header = "Authorization: Bearer $management_key"
EOF
chmod 600 "$curl_config" 2>/dev/null || true

curl -fsS --config "$curl_config" \
  "$CPA_MANAGEMENT_BASE_URL/v0/management/auth-files" > "$auth_json"

CPA_QUOTA_URL_CODEX="${CPA_QUOTA_URL_CODEX:-https://chatgpt.com/backend-api/wham/usage}" \
CPA_QUOTA_URL_OPENAI="${CPA_QUOTA_URL_OPENAI:-https://chatgpt.com/backend-api/wham/usage}" \
CPA_QUOTA_URL_CHATGPT="${CPA_QUOTA_URL_CHATGPT:-https://chatgpt.com/backend-api/wham/usage}" \
CPA_QUOTA_URL_CLAUDE="${CPA_QUOTA_URL_CLAUDE:-https://api.anthropic.com/api/oauth/usage}" \
python3 - "$auth_json" "$entries_json" <<'PY'
import json
import os
import sys

source_path, out_path = sys.argv[1:3]
payload = json.load(open(source_path, "r", encoding="utf-8"))
items = payload.get("files") if isinstance(payload, dict) else None
if not isinstance(items, list):
    items = payload if isinstance(payload, list) else []

defaults = {
    "codex": os.environ.get("CPA_QUOTA_URL_CODEX", ""),
    "openai": os.environ.get("CPA_QUOTA_URL_OPENAI", ""),
    "chatgpt": os.environ.get("CPA_QUOTA_URL_CHATGPT", ""),
    "claude": os.environ.get("CPA_QUOTA_URL_CLAUDE", ""),
    "anthropic": os.environ.get("CPA_QUOTA_URL_CLAUDE", ""),
}
provider_aliases = {
    "anthropic": "claude",
    "chatgpt": "openai",
}


def text(value):
    return value.strip() if isinstance(value, str) else ""


def truthy(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on", "disabled"}
    return bool(value)


entries = []
skipped = {"disabled": 0, "missing_auth_index": 0, "unsupported": 0}
for index, item in enumerate(items, start=1):
    if not isinstance(item, dict):
        continue
    status = text(item.get("status")).lower()
    if truthy(item.get("disabled")) or truthy(item.get("unavailable")) or status == "disabled":
        skipped["disabled"] += 1
        continue

    auth_index = text(item.get("auth_index") or item.get("authIndex") or item.get("auth-index"))
    if not auth_index:
        skipped["missing_auth_index"] += 1
        continue

    provider_raw = text(item.get("provider") or item.get("type") or item.get("source")).lower().replace("-", "_")
    provider = provider_aliases.get(provider_raw, provider_raw)
    url = defaults.get(provider_raw) or defaults.get(provider)
    if not provider or not url:
        skipped["unsupported"] += 1
        continue

    label = text(item.get("label") or item.get("name") or item.get("id")) or f"{provider} {index}"
    entries.append({
        "auth_index": auth_index,
        "provider": provider,
        "provider_raw": provider_raw,
        "label": label,
        "url": url,
    })

json.dump({"entries": entries, "skipped": skipped, "total": len(items)}, open(out_path, "w", encoding="utf-8"), indent=2, sort_keys=True)
PY

entry_count="$(jq '.entries | length' "$entries_json")"
if [ "$entry_count" -eq 0 ]; then
  jq -r '"no supported enabled CPA quota credentials found (total=\(.total), skipped=\(.skipped))"' "$entries_json" >&2
  exit 1
fi

i=0
success_count=0
failure_count=0
while [ "$i" -lt "$entry_count" ]; do
  entry_file="$tmp_dir/entry-$i.json"
  request_file="$tmp_dir/request-$i.json"
  response_file="$results_dir/result-$i.json"
  jq ".entries[$i]" "$entries_json" > "$entry_file"

  jq -nc --argjson entry "$(cat "$entry_file")" '{
    auth_index: $entry.auth_index,
    method: "GET",
    url: $entry.url,
    header: {
      "Authorization": "Bearer $TOKEN$"
    }
  }' > "$request_file"
  chmod 600 "$request_file" 2>/dev/null || true

  if curl -fsS --config "$curl_config" \
    -H "Content-Type: application/json" \
    -X POST "$CPA_MANAGEMENT_BASE_URL/v0/management/api-call" \
    -d "$(cat "$request_file")" > "$response_file"; then
    status_code="$(jq -r '.status_code // .statusCode // 0' "$response_file" 2>/dev/null || printf 0)"
    if [ "$status_code" -ge 200 ] && [ "$status_code" -le 299 ]; then
      success_count=$((success_count + 1))
    else
      failure_count=$((failure_count + 1))
    fi
  else
    printf '{"status_code":0,"body":"{}","error":"api-call failed"}\n' > "$response_file"
    failure_count=$((failure_count + 1))
  fi
  chmod 600 "$response_file" 2>/dev/null || true
  i=$((i + 1))
done

python3 - "$entries_json" "$results_dir" "$merged_json" <<'PY'
import json
import pathlib
import sys

entries_path, results_dir, out_path = sys.argv[1:4]
entries = json.load(open(entries_path, "r", encoding="utf-8"))["entries"]
results_dir = pathlib.Path(results_dir)

providers = {}
failures = []
for index, entry in enumerate(entries):
    result_path = results_dir / f"result-{index}.json"
    try:
        envelope = json.loads(result_path.read_text(encoding="utf-8"))
    except Exception as exc:
        failures.append({"label": entry["label"], "provider": entry["provider"], "error": f"invalid response: {exc}"})
        continue
    status_code = int(envelope.get("status_code") or envelope.get("statusCode") or 0)
    if status_code < 200 or status_code > 299:
        failures.append({"label": entry["label"], "provider": entry["provider"], "status_code": status_code})
        continue
    body = envelope.get("body")
    try:
        account = json.loads(body) if isinstance(body, str) else body
    except json.JSONDecodeError:
        failures.append({"label": entry["label"], "provider": entry["provider"], "error": "body is not JSON"})
        continue
    if not isinstance(account, dict):
        account = {"data": account}
    account = dict(account)
    account["provider"] = entry["provider"]
    account["label"] = entry["label"]

    provider = providers.setdefault(entry["provider"], {
        "provider": entry["provider"],
        "accounts": [],
    })
    provider["accounts"].append(account)

if not any(provider["accounts"] for provider in providers.values()):
    print(json.dumps({"failures": failures}, ensure_ascii=True), file=sys.stderr)
    sys.exit("no quota API calls succeeded; keeping existing public snapshot")

snapshot_source = {"providers": [provider for provider in providers.values() if provider["accounts"]]}
json.dump(snapshot_source, open(out_path, "w", encoding="utf-8"), ensure_ascii=True, indent=2, sort_keys=True)
open(out_path, "a", encoding="utf-8").write("\n")
summary_path = pathlib.Path(out_path).with_suffix(".summary.json")
json.dump({"failures": failures, "successes": sum(len(p["accounts"]) for p in snapshot_source["providers"])}, open(summary_path, "w", encoding="utf-8"), ensure_ascii=True, indent=2, sort_keys=True)
PY
chmod 600 "$merged_json" 2>/dev/null || true

CPA_PUBLIC_PATH="$CPA_PUBLIC_PATH" \
  bash "$ROOT_DIR/ops/cpa-quota-snapshot.sh" --input "$merged_json" >/dev/null

summary_file="${merged_json%.json}.summary.json"
if [ -f "$summary_file" ]; then
  failures="$(jq '.failures | length' "$summary_file")"
else
  failures="$failure_count"
fi
skipped="$(jq -c '.skipped' "$entries_json")"
printf 'published CPA quota snapshot: queried=%s failed=%s skipped=%s output=%s\n' \
  "$success_count" "$failures" "$skipped" "$CPA_PUBLIC_PATH/quota-snapshot.json"
