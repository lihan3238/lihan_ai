#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$ROOT_DIR/vendor/cli-proxy-api"

mkdir -p "$TARGET_DIR"

download() {
  url="$1"
  target="$2"
  tmp="${target}.tmp"

  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL --connect-timeout 5 --max-time 20 --retry 1 --retry-delay 2 --retry-connrefused "$url" -o "$tmp"; then
      rm -f "$tmp"
      echo "failed to download $url" >&2
      exit 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -q --timeout=20 --tries=2 -O "$tmp" "$url"; then
      rm -f "$tmp"
      echo "failed to download $url" >&2
      exit 1
    fi
  else
    echo "curl or wget is required" >&2
    exit 1
  fi

  mv "$tmp" "$target"
}

download \
  "https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/main/docker-compose.yml" \
  "$TARGET_DIR/docker-compose.upstream.yml"

download \
  "https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/main/config.example.yaml" \
  "$TARGET_DIR/config.example.yaml"

echo "CPA upstream assets synced into vendor/cli-proxy-api"
