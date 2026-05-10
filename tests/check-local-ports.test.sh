#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/check-local-ports.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail "missing executable $SCRIPT"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

set +e
missing_output="$(NEW_API_ENV_FILE="$tmp_dir/missing.env" "$SCRIPT" 2>&1)"
missing_status="$?"
set -e
[ "$missing_status" -eq 1 ] || fail "expected missing env exit 1, got $missing_status: $missing_output"
printf '%s' "$missing_output" | grep -q "missing env file" || fail "missing env message: $missing_output"

env_file="$tmp_dir/.env"
cat > "$env_file" <<'ENV'
NEW_API_DEV_PORT=43100
KUMA_PORT=43101
ENV

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
if [ "$1" = "ps" ]; then
  if [ "${PORT_TEST_DOCKER_STATE:-free}" = "occupied" ]; then
    printf 'opentoolhub-api-1 0.0.0.0:3001->3001/tcp\n'
  elif [ "${PORT_TEST_DOCKER_STATE:-free}" = "self" ]; then
    printf 'relay-new-api 127.0.0.1:43100->3000/tcp\n'
    printf 'relay-uptime-kuma 127.0.0.1:43101->3001/tcp\n'
  fi
  exit 0
fi
exit 1
DOCKER
chmod +x "$fake_bin/docker"
cat > "$fake_bin/lsof" <<'LSOF'
#!/usr/bin/env sh
exit 1
LSOF
chmod +x "$fake_bin/lsof"
cat > "$fake_bin/ss" <<'SS'
#!/usr/bin/env sh
exit 0
SS
chmod +x "$fake_bin/ss"
fake_netstat="$tmp_dir/netstat.exe"
cat > "$fake_netstat" <<'NETSTAT'
#!/usr/bin/env sh
if [ "${PORT_TEST_WINDOWS_STATE:-free}" = "occupied" ]; then
  printf '  TCP    127.0.0.1:43100         0.0.0.0:0              LISTENING       25960\n'
fi
NETSTAT
chmod +x "$fake_netstat"

free_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" "$SCRIPT")"
printf '%s' "$free_output" | grep -q "PASS NEW_API_DEV_PORT" || fail "free output missing new api pass: $free_output"
printf '%s' "$free_output" | grep -q "PASS KUMA_PORT" || fail "free output missing kuma pass: $free_output"

set +e
windows_output="$(PORT_TEST_WINDOWS_STATE=occupied PORT_CHECK_WINDOWS_NETSTAT="$fake_netstat" PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" "$SCRIPT" 2>&1)"
windows_status="$?"
set -e
[ "$windows_status" -eq 1 ] || fail "expected Windows occupied exit 1, got $windows_status: $windows_output"
printf '%s' "$windows_output" | grep -q "occupied on Windows host" || fail "windows occupied output missing host detail: $windows_output"
printf '%s' "$windows_output" | grep -q "127.0.0.1:43100" || fail "windows occupied output missing port line: $windows_output"

override_output="$(KUMA_PORT=43102 PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" "$SCRIPT")"
printf '%s' "$override_output" | grep -q "port 43102" || fail "env override did not win over env file: $override_output"

self_output="$(PORT_TEST_DOCKER_STATE=self PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" "$SCRIPT")"
printf '%s' "$self_output" | grep -q "PASS NEW_API_DEV_PORT" || fail "self output missing new api pass: $self_output"
printf '%s' "$self_output" | grep -q "PASS KUMA_PORT" || fail "self output missing kuma pass: $self_output"

cat > "$env_file" <<'ENV'
NEW_API_DEV_PORT=43100
KUMA_PORT=3001
ENV

set +e
occupied_output="$(PORT_TEST_DOCKER_STATE=occupied PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" "$SCRIPT" 2>&1)"
occupied_status="$?"
set -e
[ "$occupied_status" -eq 1 ] || fail "expected occupied exit 1, got $occupied_status: $occupied_output"
printf '%s' "$occupied_output" | grep -q "FAIL KUMA_PORT" || fail "occupied output missing KUMA_PORT fail: $occupied_output"
printf '%s' "$occupied_output" | grep -q "opentoolhub-api-1" || fail "occupied output missing owner: $occupied_output"

echo "check-local-ports tests passed"
