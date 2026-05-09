#!/usr/bin/env sh
set -eu

failures=0

pass() {
  echo "PASS $*"
}

warn() {
  echo "WARN $*" >&2
}

fail() {
  echo "FAIL $*" >&2
  failures=$((failures + 1))
}

if [ -r /etc/os-release ]; then
  os_name="$(. /etc/os-release && printf '%s' "${ID:-unknown}")"
  os_version="$(. /etc/os-release && printf '%s' "${VERSION_ID:-unknown}")"
  if [ "$os_name" = "ubuntu" ]; then
    pass "os ubuntu $os_version"
  else
    warn "os is $os_name $os_version; Ubuntu 24.04 LTS is the recommended baseline"
  fi
else
  warn "cannot read /etc/os-release"
fi

for cmd in git curl jq df awk sed; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "command $cmd"
  else
    fail "missing command $cmd"
  fi
done

if command -v docker >/dev/null 2>&1; then
  pass "docker $(docker --version 2>/dev/null | sed 's/,//g')"
else
  fail "docker is not installed"
fi

if docker compose version >/dev/null 2>&1; then
  pass "docker compose $(docker compose version 2>/dev/null)"
else
  fail "Docker Compose plugin is missing; install the docker compose plugin before deploying"
fi

available_kb="$(df -Pk . | awk 'NR==2 {print $4}')"
if [ "${available_kb:-0}" -ge 20971520 ]; then
  pass "disk has at least 20 GiB free"
else
  warn "disk has less than 20 GiB free in current filesystem"
fi

if command -v ss >/dev/null 2>&1; then
  for port in 80 443; do
    if ss -ltn | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
      warn "port $port is already listening; this is fine only if it is the intended reverse proxy"
    else
      pass "port $port is available"
    fi
  done
else
  warn "ss is not available; skipped port checks"
fi

if [ "$failures" -ne 0 ]; then
  exit 1
fi

echo "bootstrap check passed"
