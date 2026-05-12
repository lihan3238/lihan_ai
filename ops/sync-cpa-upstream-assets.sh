#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$ROOT_DIR/vendor/cli-proxy-api"

if [ ! -f "$ROOT_DIR/.gitmodules" ] || ! grep -q 'path = vendor/cli-proxy-api' "$ROOT_DIR/.gitmodules"; then
  echo "vendor/cli-proxy-api is not registered as a submodule" >&2
  exit 1
fi

git -C "$ROOT_DIR" submodule update --init --remote vendor/cli-proxy-api

sha="$(git -C "$TARGET_DIR" rev-parse --short HEAD)"
echo "CPA upstream submodule synced: vendor/cli-proxy-api@$sha"
echo "Review with: git diff --submodule vendor/cli-proxy-api"
echo "Stage with:  git add vendor/cli-proxy-api"
