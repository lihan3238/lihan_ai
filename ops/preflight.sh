#!/usr/bin/env sh
set -eu

ENV_FILE="${ENV_FILE:-.env}"
missing=0

require_file() {
  path="$1"
  label="${2:-required file}"
  if [ -d "$path" ]; then
    echo "$label must be a file, not a directory: $path" >&2
    missing=1
  elif [ ! -f "$path" ]; then
    echo "missing $label: $path" >&2
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

config_value() {
  key="$1"
  value="$(eval "printf '%s' \"\${$key:-}\"")"
  if [ -z "$value" ]; then
    value="$(env_value "$key")"
  fi
  printf '%s' "$value"
}

require_env_value() {
  key="$1"
  value="$(config_value "$key")"
  if [ -z "$value" ]; then
    echo "$ENV_FILE is missing required value: $key" >&2
    exit 1
  fi
}

require_url_safe_secret() {
  key="$1"
  value="$(config_value "$key")"
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

cpa_yaml_value() {
  file="$1"
  key="$2"
  awk -F: -v key="$key" '
    $0 !~ /^[[:space:]]*#/ {
      field = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field == key) {
        value = substr($0, index($0, ":") + 1)
        sub(/[[:space:]]+#.*$/, "", value)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/^"|"$/, "", value)
        gsub(/^'\''|'\''$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

check_cpa_logging_cap() {
  cpa_config_path="$(config_value CPA_CONFIG_PATH)"
  require_env_value CPA_CONFIG_PATH
  require_file "$cpa_config_path" "CPA_CONFIG_PATH"

  logging_to_file="$(cpa_yaml_value "$cpa_config_path" "logging-to-file")"
  if [ "$logging_to_file" = "true" ]; then
    logs_max_total_size_mb="$(cpa_yaml_value "$cpa_config_path" "logs-max-total-size-mb")"
    case "$logs_max_total_size_mb" in
      ''|*[!0-9]*|0)
        echo "CPA logging-to-file requires logs-max-total-size-mb to be a positive integer" >&2
        exit 1
        ;;
    esac
  fi
}

session_secret="$(config_value SESSION_SECRET)"
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

deploy_env="$(config_value DEPLOY_ENV)"
compose_files="-f docker-compose.yml"
if [ "$deploy_env" = "production" ]; then
  require_env_value DOMAIN
  require_env_value ACME_EMAIL
  domain="$(config_value DOMAIN)"
  fallback_origin="$(config_value CLOUDFLARE_SAAS_FALLBACK_ORIGIN)"
  if [ -n "$fallback_origin" ] && [ "$domain" = "$fallback_origin" ]; then
    echo "DOMAIN must be the public custom hostname, not CLOUDFLARE_SAAS_FALLBACK_ORIGIN" >&2
    echo "For Cloudflare for SaaS, use DOMAIN=api.lihan3238.com and CLOUDFLARE_SAAS_FALLBACK_ORIGIN=origin.lihan3238.top" >&2
    exit 1
  fi
  require_file "docker-compose.prod.yml"
  compose_files="$compose_files -f docker-compose.prod.yml"

  deploy_include_local_new_api_build="$(config_value DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD)"
  if [ "$deploy_include_local_new_api_build" = "1" ]; then
    require_file "docker-compose.local-build.yml"
    require_file "vendor/new-api/Dockerfile" "vendor/new-api/Dockerfile"
    compose_files="$compose_files -f docker-compose.local-build.yml"
  fi

  deploy_include_cpa="$(config_value DEPLOY_INCLUDE_CPA)"
  if [ "$deploy_include_cpa" = "1" ]; then
    require_file "docker-compose.cpa.yml"
    check_cpa_logging_cap
    compose_files="$compose_files -f docker-compose.cpa.yml"
  fi

  deploy_include_tunnel="$(config_value DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL)"
  if [ "$deploy_include_tunnel" = "1" ]; then
    require_file "docker-compose.cloudflare-tunnel.yml"
    require_env_value CLOUDFLARED_CONFIG_PATH
    require_env_value CLOUDFLARED_CREDENTIALS_PATH
    cloudflared_config_path="$(config_value CLOUDFLARED_CONFIG_PATH)"
    cloudflared_credentials_path="$(config_value CLOUDFLARED_CREDENTIALS_PATH)"
    require_file "$cloudflared_config_path" "CLOUDFLARED_CONFIG_PATH"
    require_file "$cloudflared_credentials_path" "CLOUDFLARED_CREDENTIALS_PATH"
    compose_files="$compose_files -f docker-compose.cloudflare-tunnel.yml"
  fi
fi

if [ "$missing" -ne 0 ]; then
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not in PATH" >&2
  exit 1
fi

# shellcheck disable=SC2086
docker compose --env-file "$ENV_FILE" $compose_files config >/dev/null
echo "preflight passed"
