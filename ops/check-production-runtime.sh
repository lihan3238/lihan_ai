#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

case "$ENV_FILE" in
  /*) ;;
  *) ENV_FILE="$ROOT_DIR/$ENV_FILE" ;;
esac

if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-${DEPLOY_COMPOSE_PROJECT:-}}"
DEPLOY_INCLUDE_CPA="${DEPLOY_INCLUDE_CPA:-0}"
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL="${DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL:-0}"
RUNTIME_EXTERNAL_RETRIES="${RUNTIME_EXTERNAL_RETRIES:-12}"
RUNTIME_EXTERNAL_RETRY_SECONDS="${RUNTIME_EXTERNAL_RETRY_SECONDS:-5}"

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
  printf '%s %-28s %s\n' "$status" "$name" "$detail"
}

compose() {
  project_args=""
  if [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
    project_args="-p $COMPOSE_PROJECT_NAME"
  fi

  if [ "$DEPLOY_INCLUDE_CPA" = "1" ] && [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
    # shellcheck disable=SC2086
    docker compose $project_args --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.prod.yml" -f "$ROOT_DIR/docker-compose.cpa.yml" -f "$ROOT_DIR/docker-compose.cloudflare-tunnel.yml" "$@"
  elif [ "$DEPLOY_INCLUDE_CPA" = "1" ]; then
    # shellcheck disable=SC2086
    docker compose $project_args --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.prod.yml" -f "$ROOT_DIR/docker-compose.cpa.yml" "$@"
  elif [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
    # shellcheck disable=SC2086
    docker compose $project_args --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.prod.yml" -f "$ROOT_DIR/docker-compose.cloudflare-tunnel.yml" "$@"
  else
    # shellcheck disable=SC2086
    docker compose $project_args --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.prod.yml" "$@"
  fi
}

cd "$ROOT_DIR"

if compose config >/dev/null 2>&1; then
  print_result PASS "compose config" "production compose is valid"
else
  print_result FAIL "compose config" "production compose failed to render"
fi

for service in postgres redis new-api; do
  if compose ps "$service" >/dev/null 2>&1 && compose ps "$service" | grep -q "relay-"; then
    print_result PASS "container $service" "service exists in compose"
  else
    print_result FAIL "container $service" "service is missing from compose state"
  fi
done

if [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
  if compose ps cloudflared >/dev/null 2>&1 && compose ps cloudflared | grep -q "relay-cloudflared"; then
    print_result PASS "container cloudflared" "service exists in compose"
  else
    print_result FAIL "container cloudflared" "service is missing from compose state"
  fi
else
  if compose ps caddy >/dev/null 2>&1 && compose ps caddy | grep -q "relay-caddy"; then
    print_result PASS "container caddy" "service exists in compose"
  else
    print_result FAIL "container caddy" "service is missing from compose state"
  fi
fi

new_api_health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' relay-new-api 2>/dev/null || true)"
if [ "$new_api_health" = "healthy" ] || [ "$new_api_health" = "running" ]; then
  print_result PASS "new-api health" "$new_api_health"
else
  print_result FAIL "new-api health" "${new_api_health:-not found}"
fi

if [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
  cloudflared_state="$(docker inspect -f '{{.State.Status}}' relay-cloudflared 2>/dev/null || true)"
  if [ "$cloudflared_state" = "running" ]; then
    print_result PASS "cloudflared state" "running"
  else
    print_result FAIL "cloudflared state" "${cloudflared_state:-not found}"
  fi

  if docker port relay-caddy 80/tcp 2>/dev/null | grep -q ':80$'; then
    print_result FAIL "caddy port 80" "published during Cloudflare Tunnel mode"
  else
    print_result PASS "caddy port 80" "not published in Cloudflare Tunnel mode"
  fi

  if docker port relay-caddy 443/tcp 2>/dev/null | grep -q ':443$'; then
    print_result FAIL "caddy port 443" "published during Cloudflare Tunnel mode"
  else
    print_result PASS "caddy port 443" "not published in Cloudflare Tunnel mode"
  fi

  if command -v ss >/dev/null 2>&1; then
    if ss -lnt 2>/dev/null | grep -Eq ':(80|443)[[:space:]]'; then
      print_result WARN "host listeners" "80/443 listener detected; Cloudflare Tunnel does not require it"
    else
      print_result PASS "host listeners" "no public origin 80/443 listener required"
    fi
  else
    print_result WARN "host listeners" "ss is not installed"
  fi

  cloudflared_logs="$(docker logs --tail=120 relay-cloudflared 2>/dev/null || true)"
  if printf '%s' "$cloudflared_logs" | grep -Eiq 'ERR|error|failed|unable'; then
    print_result FAIL "cloudflared logs" "recent tunnel error signature found"
  else
    print_result PASS "cloudflared logs" "no recent tunnel error signature"
  fi
else
  caddy_state="$(docker inspect -f '{{.State.Status}}' relay-caddy 2>/dev/null || true)"
  if [ "$caddy_state" = "running" ]; then
    print_result PASS "caddy state" "running"
  else
    print_result FAIL "caddy state" "${caddy_state:-not found}"
  fi

  if docker port relay-caddy 80/tcp 2>/dev/null | grep -q ':80$'; then
    print_result PASS "caddy port 80" "$(docker port relay-caddy 80/tcp 2>/dev/null | tr '\n' ' ')"
  else
    print_result FAIL "caddy port 80" "not published"
  fi

  if docker port relay-caddy 443/tcp 2>/dev/null | grep -q ':443$'; then
    print_result PASS "caddy port 443" "$(docker port relay-caddy 443/tcp 2>/dev/null | tr '\n' ' ')"
  else
    print_result FAIL "caddy port 443" "not published"
  fi

  if command -v ss >/dev/null 2>&1; then
    if ss -lnt 2>/dev/null | grep -Eq ':(80|443)[[:space:]]'; then
      print_result PASS "host listeners" "80/443 listener detected"
    else
      print_result FAIL "host listeners" "no 80/443 listener detected"
    fi
  else
    print_result WARN "host listeners" "ss is not installed"
  fi

  caddy_logs="$(compose logs --tail=120 caddy 2>/dev/null || true)"
  if printf '%s' "$caddy_logs" | grep -Eiq 'lookup .*127\.0\.0\.53|could not get certificate|address already in use'; then
    print_result FAIL "caddy logs" "recent ACME, DNS, or bind error found"
  else
    print_result PASS "caddy logs" "no recent ACME/DNS/bind error signature"
  fi
fi

if compose exec -T new-api wget -q -O - http://localhost:3000/api/status 2>/dev/null | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
  print_result PASS "internal status" "new-api /api/status works inside container"
else
  print_result FAIL "internal status" "new-api /api/status failed inside container"
fi

if [ -n "${DOMAIN:-}" ] && command -v curl >/dev/null 2>&1; then
  case "$RUNTIME_EXTERNAL_RETRIES" in
    ''|*[!0-9]*) RUNTIME_EXTERNAL_RETRIES=12 ;;
  esac
  case "$RUNTIME_EXTERNAL_RETRY_SECONDS" in
    ''|*[!0-9]*) RUNTIME_EXTERNAL_RETRY_SECONDS=5 ;;
  esac

  external_status_ok=0
  external_attempt=1
  while [ "$external_attempt" -le "$RUNTIME_EXTERNAL_RETRIES" ]; do
    if curl -fsS --max-time 20 "https://$DOMAIN/api/status" 2>/dev/null | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
      external_status_ok=1
      break
    fi
    if [ "$external_attempt" -lt "$RUNTIME_EXTERNAL_RETRIES" ]; then
      sleep "$RUNTIME_EXTERNAL_RETRY_SECONDS"
    fi
    external_attempt=$((external_attempt + 1))
  done

  if [ "$external_status_ok" -eq 1 ]; then
    print_result PASS "external status" "https://$DOMAIN/api/status works after $external_attempt attempt(s)"
  else
    print_result FAIL "external status" "https://$DOMAIN/api/status failed after $RUNTIME_EXTERNAL_RETRIES attempt(s)"
  fi
else
  print_result WARN "external status" "DOMAIN or curl is missing"
fi

if [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
  print_result PASS "saas origin status" "Cloudflare Tunnel mode skips direct origin SNI check"
elif [ -n "${DOMAIN:-}" ] && [ -n "${CLOUDFLARE_SAAS_ORIGIN_IP:-}" ] && command -v curl >/dev/null 2>&1; then
  if curl -fsS --max-time 20 --resolve "$DOMAIN:443:$CLOUDFLARE_SAAS_ORIGIN_IP" "https://$DOMAIN/api/status" 2>/dev/null | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
    print_result PASS "saas origin status" "https://$DOMAIN/api/status works via $CLOUDFLARE_SAAS_ORIGIN_IP"
  else
    print_result FAIL "saas origin status" "direct origin SNI/Host check failed via $CLOUDFLARE_SAAS_ORIGIN_IP"
  fi
elif [ -n "${CLOUDFLARE_SAAS_FALLBACK_ORIGIN:-}" ]; then
  print_result WARN "saas origin status" "CLOUDFLARE_SAAS_ORIGIN_IP is missing; skipped direct origin check"
fi

printf 'Summary: %s PASS, %s WARN, %s FAIL\n' "$pass_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
