#!/usr/bin/env sh
set -eu

usage() {
  cat >&2 <<'USAGE'
usage: ops/cpa-quota-snapshot.sh [--input FILE] [--output FILE] [--label TEXT]
                                 [--source-url URL] [--header HEADER]

Reads a CPA quota JSON response, writes a sanitized public quota snapshot.

Environment:
  CPA_PUBLIC_PATH          Default output directory.
  CPA_AUTH_PATH            Fallback base path; public/ is appended.
  CPA_QUOTA_OUTPUT         Default output file override.
  CPA_QUOTA_LEGACY_OUTPUT  Optional legacy Codex-only output file.
  CPA_QUOTA_INPUT          Default input file.
  CPA_QUOTA_LABEL          Public account label, default "Codex".
  CPA_QUOTA_SOURCE_URL     Optional URL to fetch raw quota JSON from.
  CPA_QUOTA_SOURCE_HEADER  Optional single curl header for the source URL.
  CPA_QUOTA_NOW            Override generated_at, used by tests.
  CPA_QUOTA_QUERIED_AT     Override queried_at, used when publishing saved raw JSON.
USAGE
}

input="${CPA_QUOTA_INPUT:-}"
output="${CPA_QUOTA_OUTPUT:-}"
legacy_output="${CPA_QUOTA_LEGACY_OUTPUT:-}"
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
  output="$public_path/quota-snapshot.json"
  legacy_output="${legacy_output:-$public_path/codex-quota.json}"
fi

output_dir="$(dirname "$output")"
mkdir -p "$output_dir"
tmp_output="$(mktemp "$output_dir/.quota-snapshot.json.XXXXXX")"
tmp_legacy=""
if [ -n "$legacy_output" ]; then
  legacy_dir="$(dirname "$legacy_output")"
  mkdir -p "$legacy_dir"
  tmp_legacy="$(mktemp "$legacy_dir/.codex-quota.json.XXXXXX")"
fi

generated_at="${CPA_QUOTA_NOW:-}"
queried_at="${CPA_QUOTA_QUERIED_AT:-$generated_at}"

python3 - "$input" "$tmp_output" "$label" "$generated_at" "$queried_at" "$tmp_legacy" <<'PY'
import json
import math
import pathlib
import re
import sys
from datetime import datetime, timezone

input_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
base_label = sys.argv[3] or "Codex"
generated_at = sys.argv[4] or datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
queried_at = sys.argv[5] or generated_at
legacy_path = pathlib.Path(sys.argv[6]) if len(sys.argv) > 6 and sys.argv[6] else None

PROVIDER_TITLES = {
    "codex": "Codex",
    "openai": "GPT / OpenAI",
    "chatgpt": "GPT / ChatGPT",
    "claude": "Claude",
    "anthropic": "Claude",
    "antigravity": "Antigravity",
    "gemini": "Gemini",
    "kimi": "Kimi",
    "grok": "Grok",
}

WINDOW_TITLES = {
    "five_hour": "5-hour limit",
    "primary_window": "5-hour limit",
    "weekly": "Weekly limit",
    "weekly_limit": "Weekly limit",
    "seven_day": "7-day limit",
    "seven_day_opus": "7-day Opus",
    "seven_day_sonnet": "7-day Sonnet",
    "seven_day_oauth_apps": "7-day OAuth Apps",
    "seven_day_cowork": "7-day Cowork",
    "monthly": "Monthly limit",
    "daily": "Daily limit",
}

SENSITIVE_PUBLIC_TEXT_PATTERNS = [
    re.compile(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}"),
    re.compile(r"\b(sk-|ghp_|github_pat_|glpat-|xox[baprs]-|AKIA|ASIA|AIza|GOCSPX-)", re.IGNORECASE),
    re.compile(r"\b(bearer|access[_ -]?token|refresh[_ -]?token|id[_ -]?token|api[_ -]?key|secret|cookie)\b", re.IGNORECASE),
]


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


def clean_string(value, max_length=120):
    if not isinstance(value, str):
        return None
    text = " ".join(value.strip().split())
    if not text:
        return None
    return text[:max_length]


def public_string(value, max_length=120):
    text = clean_string(value, max_length)
    if not text:
        return None
    if any(pattern.search(text) for pattern in SENSITIVE_PUBLIC_TEXT_PATTERNS):
        return None
    return text


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


def unwrap_api_call_payload(payload):
    if not isinstance(payload, dict):
        return payload
    if "body" not in payload or ("status_code" not in payload and "statusCode" not in payload):
        return payload

    status_code = as_int(first_path(payload, ["status_code", "statusCode"]))
    if status_code is not None and not 200 <= status_code <= 299:
        raise SystemExit(f"CPA api-call returned upstream HTTP {status_code}")

    body = payload.get("body")
    if isinstance(body, str):
        text = body.strip()
        if not text:
            raise SystemExit("CPA api-call body is empty")
        try:
            return json.loads(text)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"CPA api-call body is not JSON: {exc.msg}") from exc
    if isinstance(body, (dict, list)):
        return body
    raise SystemExit("CPA api-call body must be a JSON string or object")


def normalize_window(raw):
    if not isinstance(raw, dict):
        return None
    key = clean_string(first_path(raw, ["key", "id", "name", "window", "type"]), 64)
    out = {}
    if key:
        out["key"] = key
        out["title"] = clean_string(first_path(raw, ["title", "label", "display_name", "displayName"]), 80) or WINDOW_TITLES.get(key, key.replace("_", " ").title())
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


def with_window_identity(window, key, title):
    data = dict(window or {})
    data["key"] = data.get("key") or key
    data["title"] = data.get("title") or title
    return data


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
    for window in windows:
        if not isinstance(window, dict):
            continue
        if window.get("status") == "limited":
            return "limited"
        used_percent = as_number(window.get("used_percent"))
        if used_percent is not None and used_percent >= 100:
            return "limited"
    if any(isinstance(window, dict) and window for window in windows):
        return "available"
    return "unknown"


def normalize_provider(value):
    provider = clean_string(value, 64)
    if not provider:
        return "codex"
    provider = provider.lower().replace(" ", "_").replace("-", "_")
    if provider in ("open_ai", "gpt"):
        return "openai"
    if provider == "anthropic":
        return "claude"
    return provider


def normalize_windows(raw):
    windows_raw = first_path(raw, ["windows", "quota_windows", "quotaWindows"])
    windows = []
    if isinstance(windows_raw, list):
        for item in windows_raw:
            normalized = normalize_window(item)
            if normalized:
                key = normalized.get("key") or f"window_{len(windows) + 1}"
                windows.append(with_window_identity(normalized, key, WINDOW_TITLES.get(key, key.replace("_", " ").title())))
    elif isinstance(windows_raw, dict):
        for key, item in windows_raw.items():
            normalized = normalize_window(item)
            if normalized:
                windows.append(with_window_identity(normalized, str(key), WINDOW_TITLES.get(str(key), str(key).replace("_", " ").title())))

    if windows:
        return windows

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

    windows = [
        with_window_identity(five or {"status": "unknown"}, "five_hour", "5-hour limit"),
        with_window_identity(weekly or {"status": "unknown"}, "weekly", "Weekly limit"),
    ]

    additional = first_path(raw, ["rate_limit.additional_rate_limits", "additional_rate_limits", "data.rate_limit.additional_rate_limits"])
    if isinstance(additional, list):
        for index, item in enumerate(additional, start=1):
            normalized = normalize_window(item)
            if normalized:
                key = normalized.get("key") or f"additional_{index}"
                windows.append(with_window_identity(normalized, key, normalized.get("title") or f"Additional limit {index}"))
    return windows


def fallback_label(provider, index, total, default_label=None):
    label = public_string(default_label, 80) or PROVIDER_TITLES.get(provider, provider.replace("_", " ").title())
    return label if total == 1 else f"{label} {index}"


def build_account(raw, index, total, default_provider, default_label=None):
    if not isinstance(raw, dict):
        raw = {}

    provider = normalize_provider(first_path(raw, ["provider", "type", "source"]) or default_provider)
    label = public_string(first_path(raw, ["label", "display_name", "displayName", "name"]), 100)
    if not label:
        label = fallback_label(provider, index, total, default_label)
    windows = normalize_windows(raw)
    account = {
        "label": label,
        "status": status_for(windows, raw),
        "windows": windows,
    }
    account["provider"] = provider

    plan_type = first_path(raw, ["plan_type", "planType", "error.plan_type", "data.plan_type"])
    if isinstance(plan_type, str) and plan_type.strip():
        account["plan_type"] = plan_type.strip()

    return account


def build_provider(raw, index):
    provider_key = normalize_provider(first_path(raw, ["provider", "type", "source"]) or "codex")
    title = public_string(first_path(raw, ["title", "label", "name"]), 80) or PROVIDER_TITLES.get(provider_key, provider_key.replace("_", " ").title())
    account_items = raw.get("accounts") if isinstance(raw, dict) else None
    if not isinstance(account_items, list):
        account_items = raw_account_items(raw)
    accounts = [build_account(item, idx + 1, len(account_items), provider_key, title) for idx, item in enumerate(account_items)]
    for account in accounts:
        account.pop("provider", None)
    return {
        "provider": provider_key,
        "title": title,
        "accounts": accounts,
    }


def build_snapshot(raw_payload):
    providers_raw = first_path(raw_payload, ["providers", "data.providers"]) if isinstance(raw_payload, dict) else None
    if isinstance(providers_raw, list):
        providers = [build_provider(item, idx + 1) for idx, item in enumerate(providers_raw)]
    else:
        items = raw_account_items(raw_payload)
        grouped = {}
        for idx, item in enumerate(items):
            account = build_account(item, idx + 1, len(items), "codex", base_label)
            provider = account.pop("provider", "codex")
            grouped.setdefault(provider, []).append(account)
        providers = []
        for provider, accounts in grouped.items():
            providers.append({
                "provider": provider,
                "title": PROVIDER_TITLES.get(provider, provider.replace("_", " ").title()),
                "accounts": accounts,
            })
    return {
        "schema_version": 2,
        "generated_at": generated_at,
        "queried_at": queried_at,
        "source": "cpa",
        "providers": providers,
    }


raw_payload = unwrap_api_call_payload(parse_json(input_path))
snapshot = build_snapshot(raw_payload)

with output_path.open("w", encoding="utf-8") as handle:
    json.dump(snapshot, handle, ensure_ascii=True, indent=2, sort_keys=True)
    handle.write("\n")

if legacy_path:
    codex_accounts = []
    for provider in snapshot["providers"]:
        if provider.get("provider") != "codex":
            continue
        for account in provider.get("accounts", []):
            windows = {}
            for window in account.get("windows", []):
                key = window.get("key")
                if key:
                    windows[key] = {k: v for k, v in window.items() if k not in ("key", "title")}
            codex_accounts.append({
                "label": account.get("label", "Codex"),
                "status": account.get("status", "unknown"),
                "plan_type": account.get("plan_type"),
                "windows": windows,
            })
    legacy = {
        "schema_version": 1,
        "generated_at": generated_at,
        "queried_at": queried_at,
        "source": "cpa",
        "accounts": codex_accounts,
    }
    with legacy_path.open("w", encoding="utf-8") as handle:
        json.dump(legacy, handle, ensure_ascii=True, indent=2, sort_keys=True)
        handle.write("\n")
PY

chmod 0644 "$tmp_output"
mv -f "$tmp_output" "$output"
if [ -n "$legacy_output" ] && [ -n "$tmp_legacy" ]; then
  chmod 0644 "$tmp_legacy"
  mv -f "$tmp_legacy" "$legacy_output"
fi
printf '%s\n' "$output"
