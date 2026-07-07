#!/usr/bin/env sh
set -eu

usage() {
  cat >&2 <<'USAGE'
usage: ops/cpa-quota-snapshot.sh [--input FILE] [--output FILE] [--label TEXT]
                                 [--source-url URL] [--header HEADER]

Reads a CPA/Codex quota JSON response, writes a sanitized public snapshot.

Environment:
  CPA_PUBLIC_PATH          Default output directory.
  CPA_AUTH_PATH            Fallback base path; public/ is appended.
  CPA_QUOTA_OUTPUT         Default output file override.
  CPA_QUOTA_INPUT          Default input file.
  CPA_QUOTA_LABEL          Public account label, default "Codex".
  CPA_QUOTA_SOURCE_URL     Optional URL to fetch raw quota JSON from.
  CPA_QUOTA_SOURCE_HEADER  Optional single curl header for the source URL.
  CPA_QUOTA_NOW            Override generated_at, used by tests.
USAGE
}

input="${CPA_QUOTA_INPUT:-}"
output="${CPA_QUOTA_OUTPUT:-}"
label="${CPA_QUOTA_LABEL:-Codex}"
source_url="${CPA_QUOTA_SOURCE_URL:-}"
source_header="${CPA_QUOTA_SOURCE_HEADER:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --input)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      input="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      output="$2"
      shift 2
      ;;
    --label)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      label="$2"
      shift 2
      ;;
    --source-url)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      source_url="$2"
      shift 2
      ;;
    --header)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      source_header="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to sanitize quota JSON" >&2
  exit 1
fi

if [ -n "$input" ] && [ -n "$source_url" ]; then
  echo "--input and --source-url are mutually exclusive" >&2
  exit 2
fi

tmp_input=""
cleanup() {
  [ -z "$tmp_input" ] || rm -f "$tmp_input"
}
trap cleanup EXIT

if [ -n "$source_url" ]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required when --source-url is used" >&2
    exit 1
  fi
  tmp_input="$(mktemp)"
  if [ -n "$source_header" ]; then
    curl -fsSL -H "$source_header" "$source_url" > "$tmp_input"
  else
    curl -fsSL "$source_url" > "$tmp_input"
  fi
  input="$tmp_input"
elif [ -z "$input" ]; then
  if [ -t 0 ]; then
    usage
    exit 2
  fi
  tmp_input="$(mktemp)"
  cat > "$tmp_input"
  input="$tmp_input"
fi

[ -f "$input" ] || { echo "input JSON file not found: $input" >&2; exit 1; }

if [ -z "$output" ]; then
  public_path="${CPA_PUBLIC_PATH:-}"
  if [ -z "$public_path" ]; then
    public_path="${CPA_AUTH_PATH:-/opt/lihan_ai/data/cpa}/public"
  fi
  output="$public_path/codex-quota.json"
fi

output_dir="$(dirname "$output")"
mkdir -p "$output_dir"
tmp_output="$(mktemp "$output_dir/.codex-quota.json.XXXXXX")"

generated_at="${CPA_QUOTA_NOW:-}"

python3 - "$input" "$tmp_output" "$label" "$generated_at" <<'PY'
import json
import math
import pathlib
import sys
from datetime import datetime, timezone

input_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
base_label = sys.argv[3] or "Codex"
generated_at = sys.argv[4] or datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def get_path(value, path):
    current = value
    for part in path.split("."):
        if not isinstance(current, dict) or part not in current:
            return None
        current = current[part]
    return current


def first_path(value, paths):
    for path in paths:
        result = get_path(value, path)
        if result not in (None, ""):
            return result
    return None


def as_number(value):
    if value in (None, ""):
        return None
    if isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(number):
        return None
    if number.is_integer():
        return int(number)
    return number


def as_int(value):
    number = as_number(value)
    if number is None:
        return None
    return int(number)


def iso_time(value):
    if value in (None, ""):
        return None
    if isinstance(value, (int, float)) or (isinstance(value, str) and value.strip().isdigit()):
        seconds = float(value)
        if seconds > 10_000_000_000:
            seconds = seconds / 1000
        return datetime.fromtimestamp(seconds, timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    if isinstance(value, str):
        text = value.strip()
        if text.endswith("Z"):
            return text
        return text
    return None


def normalize_window(raw):
    if not isinstance(raw, dict):
        return None
    out = {}
    mappings = {
        "used_percent": ["used_percent", "usedPercent", "percent_used", "usage_percent"],
        "used": ["used", "used_count", "usedCount"],
        "limit": ["limit", "total", "quota", "max"],
        "remaining": ["remaining", "remain", "left"],
        "reset_after_seconds": ["reset_after_seconds", "resets_in_seconds", "resetAfterSeconds", "resetsInSeconds"],
        "limit_window_seconds": ["limit_window_seconds", "window_seconds", "limitWindowSeconds", "windowSeconds"],
    }
    for target, keys in mappings.items():
        value = first_path(raw, keys)
        number = as_number(value)
        if number is not None:
            out[target] = number

    reset_at = iso_time(first_path(raw, ["reset_at", "resets_at", "resetAt", "resetsAt"]))
    if reset_at:
        out["reset_at"] = reset_at

    status = first_path(raw, ["status", "state"])
    if isinstance(status, str) and status.strip():
        out["status"] = status.strip().lower()

    return out or None


def quota_paths(kind):
    if kind == "five_hour":
        return [
            "quota.five_hour",
            "quota.fiveHour",
            "five_hour",
            "fiveHour",
            "rate_limit.primary_window",
            "rateLimit.primaryWindow",
            "primary_window",
            "data.quota.five_hour",
            "data.quota.fiveHour",
            "data.rate_limit.primary_window",
        ]
    return [
        "quota.weekly",
        "quota.weekly_limit",
        "quota.weeklyLimit",
        "weekly",
        "weekly_limit",
        "weeklyLimit",
        "rate_limit.secondary_window",
        "rateLimit.secondaryWindow",
        "secondary_window",
        "data.quota.weekly",
        "data.quota.weekly_limit",
        "data.quota.weeklyLimit",
        "data.rate_limit.secondary_window",
    ]


def raw_account_items(raw):
    if isinstance(raw, list):
        return raw
    if not isinstance(raw, dict):
        return [raw]
    for path in ["accounts", "data.accounts", "items", "results", "data"]:
        value = get_path(raw, path)
        if isinstance(value, list):
            return value
    return [raw]


def status_for(windows, raw):
    error_type = first_path(raw, ["error.type"])
    if error_type == "usage_limit_reached":
        return "limited"
    explicit = first_path(raw, ["status", "state"])
    if isinstance(explicit, str) and explicit.strip():
        return explicit.strip().lower()
    for window in windows.values():
        if not isinstance(window, dict):
            continue
        if window.get("status") == "limited":
            return "limited"
        used_percent = as_number(window.get("used_percent"))
        if used_percent is not None and used_percent >= 100:
            return "limited"
    if any(isinstance(window, dict) and window for window in windows.values()):
        return "available"
    return "unknown"


def build_account(raw, index, total):
    if not isinstance(raw, dict):
        raw = {}

    five = normalize_window(first_path(raw, quota_paths("five_hour")))
    weekly = normalize_window(first_path(raw, quota_paths("weekly")))

    error_type = first_path(raw, ["error.type"])
    if error_type == "usage_limit_reached" and five is None:
        five = {
            "status": "limited",
        }
        reset_at = iso_time(first_path(raw, ["error.resets_at"]))
        if reset_at:
            five["reset_at"] = reset_at
        reset_after = as_int(first_path(raw, ["error.resets_in_seconds"]))
        if reset_after is not None:
            five["reset_after_seconds"] = reset_after

    windows = {
        "five_hour": five or {"status": "unknown"},
        "weekly": weekly or {"status": "unknown"},
    }

    label = base_label if total == 1 else f"{base_label} {index}"
    account = {
        "label": label,
        "status": status_for(windows, raw),
        "windows": windows,
    }

    plan_type = first_path(raw, ["plan_type", "planType", "error.plan_type", "data.plan_type"])
    if isinstance(plan_type, str) and plan_type.strip():
        account["plan_type"] = plan_type.strip()

    additional = first_path(raw, ["rate_limit.additional_rate_limits", "additional_rate_limits", "data.rate_limit.additional_rate_limits"])
    if isinstance(additional, list):
        clean = []
        for item in additional:
            normalized = normalize_window(item)
            if normalized:
                clean.append(normalized)
        if clean:
            account["additional_rate_limits"] = clean

    return account


raw_payload = parse_json(input_path)
items = raw_account_items(raw_payload)
accounts = [build_account(item, idx + 1, len(items)) for idx, item in enumerate(items)]

snapshot = {
    "schema_version": 1,
    "generated_at": generated_at,
    "source": "cpa",
    "accounts": accounts,
}

with output_path.open("w", encoding="utf-8") as handle:
    json.dump(snapshot, handle, ensure_ascii=True, indent=2, sort_keys=True)
    handle.write("\n")
PY

chmod 0644 "$tmp_output"
mv -f "$tmp_output" "$output"
printf '%s\n' "$output"
