#!/usr/bin/env sh
set -eu

ENV_FILE="${ENV_FILE:-.env}"
missing=0

require_file() {
  if [ ! -f "$1" ]; then
    echo "missing required file: $1" >&2
    missing=1
  fi
}

require_file "$ENV_FILE"
require_file "docker-compose.yml"
require_file "Caddyfile"

if [ "$missing" -ne 0 ]; then
  exit 1
fi

if grep -v '^[[:space:]]*#' "$ENV_FILE" | grep -q "CHANGE_ME"; then
  echo "$ENV_FILE still contains CHANGE_ME placeholders" >&2
  exit 1
fi

env_value() {
  key="$1"
  awk -F= -v key="$key" '
    $0 !~ /^[[:space:]]*#/ && $1 == key {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      gsub(/^'\''|'\''$/, "", value)
      print value
      exit
    }
  ' "$ENV_FILE"
}

require_env_value() {
  key="$1"
  value="$(env_value "$key")"
  if [ -z "$value" ]; then
    echo "$ENV_FILE is missing required value: $key" >&2
    exit 1
  fi
}

require_url_safe_secret() {
  key="$1"
  value="$(env_value "$key")"
  if [ -z "$value" ]; then
    echo "$ENV_FILE is missing required value: $key" >&2
    exit 1
  fi
  if ! printf '%s' "$value" | grep -Eq '^[A-Za-z0-9._-]+$'; then
    echo "$key contains characters that are unsafe for the current URL-style DSN" >&2
    echo "Use a URL-safe value such as: openssl rand -hex 32" >&2
    exit 1
  fi
}

session_secret="$(env_value SESSION_SECRET)"
if [ -z "$session_secret" ]; then
  echo "$ENV_FILE is missing required value: SESSION_SECRET" >&2
  exit 1
fi
if [ "${#session_secret}" -lt 32 ]; then
  echo "SESSION_SECRET must be at least 32 characters" >&2
  exit 1
fi

require_env_value POSTGRES_USER
require_url_safe_secret POSTGRES_PASSWORD
require_env_value POSTGRES_DB
require_url_safe_secret REDIS_PASSWORD

deploy_env="$(env_value DEPLOY_ENV)"
compose_files="-f docker-compose.yml"
if [ "$deploy_env" = "production" ]; then
  require_env_value DOMAIN
  require_env_value ACME_EMAIL
  domain="$(env_value DOMAIN)"
  fallback_origin="$(env_value CLOUDFLARE_SAAS_FALLBACK_ORIGIN)"
  if [ -n "$fallback_origin" ] && [ "$domain" = "$fallback_origin" ]; then
    echo "DOMAIN must be the public custom hostname, not CLOUDFLARE_SAAS_FALLBACK_ORIGIN" >&2
    echo "For Cloudflare for SaaS, use DOMAIN=api.lihan3238.com and CLOUDFLARE_SAAS_FALLBACK_ORIGIN=origin.lihan3238.top" >&2
    exit 1
  fi
  require_file "docker-compose.prod.yml"
  compose_files="$compose_files -f docker-compose.prod.yml"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not in PATH" >&2
  exit 1
fi

# shellcheck disable=SC2086
docker compose --env-file "$ENV_FILE" $compose_files config >/dev/null
echo "preflight passed"
