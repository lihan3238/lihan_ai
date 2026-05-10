#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${NEW_API_ENV_FILE:-$ROOT_DIR/.env}"

pass_count=0
fail_count=0

print_result() {
  status="$1"
  name="$2"
  detail="$3"
  case "$status" in
    PASS) pass_count=$((pass_count + 1)) ;;
    FAIL) fail_count=$((fail_count + 1)) ;;
  esac
  printf '%s %-20s %s\n' "$status" "$name" "$detail"
}

OVERRIDE_NEW_API_DEV_PORT="${NEW_API_DEV_PORT:-}"
OVERRIDE_KUMA_PORT="${KUMA_PORT:-}"

if [ ! -f "$ENV_FILE" ]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

NEW_API_DEV_PORT="${OVERRIDE_NEW_API_DEV_PORT:-${NEW_API_DEV_PORT:-3100}}"
KUMA_PORT="${OVERRIDE_KUMA_PORT:-${KUMA_PORT:-3011}}"

docker_ports="$(docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null || true)"

check_port() {
  name="$1"
  port="$2"
  allowed_container="$3"

  owner="$(printf '%s\n' "$docker_ports" | grep -E "(^|[^0-9])${port}->|:${port}->|:${port}[ /]" | head -n 1 || true)"
  if [ -n "$owner" ]; then
    case "$owner" in
      "$allowed_container "*)
        print_result PASS "$name" "port $port is owned by expected container $allowed_container"
        return
        ;;
      *)
        print_result FAIL "$name" "port $port is occupied by: $owner"
        return
        ;;
    esac
  fi

  if command -v lsof >/dev/null 2>&1; then
    owner="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | tail -n +2 | head -n 1 || true)"
    if [ -n "$owner" ]; then
      print_result FAIL "$name" "port $port is occupied by: $owner"
      return
    fi
  elif command -v ss >/dev/null 2>&1; then
    owner="$(ss -ltnp 2>/dev/null | grep -E "[:.]${port}[[:space:]]" | head -n 1 || true)"
    if [ -n "$owner" ]; then
      print_result FAIL "$name" "port $port is occupied by: $owner"
      return
    fi
  fi

  windows_netstat="${PORT_CHECK_WINDOWS_NETSTAT:-}"
  if [ -z "$windows_netstat" ] && [ -x /mnt/c/Windows/System32/netstat.exe ]; then
    windows_netstat="/mnt/c/Windows/System32/netstat.exe"
  fi
  if [ -n "$windows_netstat" ] && [ -x "$windows_netstat" ]; then
    owner="$("$windows_netstat" -ano 2>/dev/null | tr -d '\r' | grep -E "[:.]${port}[[:space:]]" | grep -E "[[:space:]]LISTENING[[:space:]]" | head -n 1 || true)"
    if [ -n "$owner" ]; then
      print_result FAIL "$name" "port $port is occupied on Windows host: $owner"
      return
    fi
  fi

  print_result PASS "$name" "port $port is free"
}

check_port "NEW_API_DEV_PORT" "$NEW_API_DEV_PORT" "relay-new-api"
check_port "KUMA_PORT" "$KUMA_PORT" "relay-uptime-kuma"

printf '\nSummary: pass=%s fail=%s\n' "$pass_count" "$fail_count"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
