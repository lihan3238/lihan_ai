#!/usr/bin/env sh
set -eu

usage() {
  echo "usage: $0 <target-env> <example-env>" >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

target="$1"
example="$2"

if [ ! -f "$target" ]; then
  echo "target env not found: $target" >&2
  exit 1
fi

if [ ! -f "$example" ]; then
  echo "example env not found: $example" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

example_lines="$tmp_dir/example-lines"
example_keys="$tmp_dir/example-keys"
target_keys="$tmp_dir/target-keys"
missing_lines="$tmp_dir/missing-lines"
deprecated_keys="$tmp_dir/deprecated-keys"

awk '
  $0 !~ /^[[:space:]]*#/ && $0 ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
    print
  }
' "$example" > "$example_lines"

awk -F= '
  $0 !~ /^[[:space:]]*#/ && $0 ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
    key = $1
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
    print key
  }
' "$example" | sort -u > "$example_keys"

awk -F= '
  $0 !~ /^[[:space:]]*#/ && $0 ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
    key = $1
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
    print key
  }
' "$target" | sort -u > "$target_keys"

: > "$missing_lines"
while IFS= read -r line; do
  key="$(printf '%s' "$line" | awk -F= '{ key = $1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", key); print key }')"
  if ! grep -Fxq "$key" "$target_keys"; then
    printf '%s\n' "$line" >> "$missing_lines"
  fi
done < "$example_lines"

comm -23 "$target_keys" "$example_keys" > "$deprecated_keys" || true

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="${target}.bak.${timestamp}"
cp -p "$target" "$backup"
echo "backup=$backup"

if [ -s "$missing_lines" ]; then
  {
    printf '\n# Added by ops/sync-env-template.sh from %s at %s\n' "$(basename "$example")" "$timestamp"
    cat "$missing_lines"
  } >> "$target"

  while IFS= read -r line; do
    key="$(printf '%s' "$line" | awk -F= '{ key = $1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", key); print key }')"
    echo "added $key"
  done < "$missing_lines"
else
  echo "no missing keys"
fi

if [ -s "$deprecated_keys" ]; then
  while IFS= read -r key; do
    echo "deprecated $key"
  done < "$deprecated_keys"
fi
