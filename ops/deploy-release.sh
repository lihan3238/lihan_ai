#!/usr/bin/env sh
set -eu

usage() {
  cat >&2 <<'USAGE'
usage: ops/deploy-release.sh <bootstrap|prepare|smoke|promote|rollback|list|current|cleanup> [release-id]
USAGE
}

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

command="$1"
release_arg="${2:-}"

case "$command" in
  bootstrap|prepare|smoke|promote|rollback|list|current|cleanup) ;;
  *)
    usage
    exit 2
    ;;
esac

if [ -z "${DEPLOY_HOST:-}" ]; then
  echo "DEPLOY_HOST is not set" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/lihan_ai_deploy}"
DEPLOY_ENV="${DEPLOY_ENV:-production}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-.env.production}"
DEPLOY_REF="${DEPLOY_REF:-main}"
DEPLOY_REPO="${DEPLOY_REPO:-$(git -C "$ROOT_DIR" config --get remote.origin.url 2>/dev/null || true)}"
DEPLOY_COMPOSE_PROJECT="${DEPLOY_COMPOSE_PROJECT:-lihan_ai}"
DEPLOY_INCLUDE_CPA="${DEPLOY_INCLUDE_CPA:-0}"
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL="${DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL:-0}"
RELEASE_KEEP="${RELEASE_KEEP:-5}"
RUN_REMOTE_BACKUP="${RUN_REMOTE_BACKUP:-1}"
ALLOW_NON_MAIN_PROD_DEPLOY="${ALLOW_NON_MAIN_PROD_DEPLOY:-0}"
LEGACY_DEPLOY_PATH="${LEGACY_DEPLOY_PATH:-/opt/lihan_ai}"
RELEASE_ID="${RELEASE_ID:-$release_arg}"
DEPLOY_DRY_RUN="${DEPLOY_DRY_RUN:-${DRY_RUN:-0}}"

if [ -z "$DEPLOY_REPO" ]; then
  echo "DEPLOY_REPO is not set and git remote origin is unavailable" >&2
  exit 2
fi

if [ "$DEPLOY_ENV" = "production" ] && [ "$DEPLOY_REF" != "main" ]; then
  if [ "$ALLOW_NON_MAIN_PROD_DEPLOY" != "1" ]; then
    echo "production release deploy requires DEPLOY_REF=main; set ALLOW_NON_MAIN_PROD_DEPLOY=1 only for a documented emergency override" >&2
    exit 2
  fi
  echo "WARN non-main production release deploy override: DEPLOY_REF=$DEPLOY_REF" >&2
fi

compose_preview() {
  printf 'docker compose -p %s --env-file %s -f docker-compose.yml -f docker-compose.prod.yml' "$DEPLOY_COMPOSE_PROJECT" "$DEPLOY_ENV_FILE"
  if [ "$DEPLOY_INCLUDE_CPA" = "1" ]; then
    printf ' -f docker-compose.cpa.yml'
  fi
  if [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
    printf ' -f docker-compose.cloudflare-tunnel.yml'
  fi
}

compose_up_preview() {
  compose_preview
  printf ' up -d --remove-orphans'
  if [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
    printf ' --scale caddy=0'
  fi
}

if [ "$DEPLOY_DRY_RUN" = "1" ]; then
  echo "DRY RUN release $command to $DEPLOY_HOST"
  echo "DEPLOY_ROOT=$DEPLOY_ROOT"
  echo "DEPLOY_REPO=$DEPLOY_REPO"
  echo "DEPLOY_REF=$DEPLOY_REF"
  echo "DEPLOY_COMPOSE_PROJECT=$DEPLOY_COMPOSE_PROJECT"
  echo "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL"
  echo "repo: $DEPLOY_ROOT/repo.git"
  echo "releases: $DEPLOY_ROOT/releases"
  echo "shared: $DEPLOY_ROOT/shared"
  echo "current: $DEPLOY_ROOT/current"
  echo "candidate: $DEPLOY_ROOT/candidate"
  case "$command" in
    bootstrap)
      echo "mkdir -p $DEPLOY_ROOT/{repo.git,releases,shared}"
      echo "git clone --mirror $DEPLOY_REPO $DEPLOY_ROOT/repo.git"
      echo "copy legacy runtime from $LEGACY_DEPLOY_PATH into $DEPLOY_ROOT/shared when missing"
      ;;
    prepare)
      echo "git --git-dir $DEPLOY_ROOT/repo.git fetch origin $DEPLOY_REF"
      echo "git worktree add --detach $DEPLOY_ROOT/releases/<timestamp>-<sha> <sha>"
      echo "git submodule update --init --recursive"
      echo "link $DEPLOY_ROOT/shared/$DEPLOY_ENV_FILE into release"
      echo "link shared data/logs/backups/snapshots into release"
      echo "COMPOSE_PROJECT_NAME=$DEPLOY_COMPOSE_PROJECT ENV_FILE=$DEPLOY_ENV_FILE bash ops/preflight.sh"
      echo "$(compose_preview) config"
      echo "candidate -> releases/<timestamp>-<sha>"
      ;;
    smoke)
      if [ -n "$RELEASE_ID" ]; then
        echo "cd $DEPLOY_ROOT/releases/$RELEASE_ID"
      else
        echo "cd $DEPLOY_ROOT/candidate"
        echo "use prepared candidate release; smoke falls back to latest release only when candidate is missing"
      fi
      echo "find latest $DEPLOY_ROOT/shared/backups/postgres/*.dump unless SMOKE_BACKUP_PATH is set"
      echo "COMPOSE_PROJECT_NAME=$DEPLOY_COMPOSE_PROJECT ENV_FILE=$DEPLOY_ENV_FILE bash ops/drill-restore-stack.sh <backup.dump>"
      ;;
    promote)
      echo "cd $DEPLOY_ROOT/current and run backup-postgres.sh when production postgres is running"
      if [ -n "$RELEASE_ID" ]; then
        echo "current -> releases/$RELEASE_ID"
      else
        echo "current -> candidate"
        echo "clear candidate after successful promote"
      fi
      echo "COMPOSE_PROJECT_NAME=$DEPLOY_COMPOSE_PROJECT $(compose_preview) pull"
      echo "COMPOSE_PROJECT_NAME=$DEPLOY_COMPOSE_PROJECT $(compose_up_preview)"
      echo "COMPOSE_PROJECT_NAME=$DEPLOY_COMPOSE_PROJECT ENV_FILE=$DEPLOY_ENV_FILE bash ops/check-production-runtime.sh"
      ;;
    rollback)
      echo "current -> previous"
      echo "COMPOSE_PROJECT_NAME=$DEPLOY_COMPOSE_PROJECT $(compose_up_preview)"
      echo "verify /api/status after rollback"
      ;;
    list)
      echo "list $DEPLOY_ROOT/releases and mark current/previous/candidate"
      ;;
    current)
      echo "readlink -f $DEPLOY_ROOT/current"
      ;;
    cleanup)
      echo "remove old git worktrees, keep RELEASE_KEEP=$RELEASE_KEEP plus current/previous/candidate"
      ;;
  esac
  exit 0
fi

ssh "$DEPLOY_HOST" \
  "DEPLOY_ROOT='$DEPLOY_ROOT' DEPLOY_ENV='$DEPLOY_ENV' DEPLOY_ENV_FILE='$DEPLOY_ENV_FILE' DEPLOY_REF='$DEPLOY_REF' DEPLOY_REPO='$DEPLOY_REPO' DEPLOY_COMPOSE_PROJECT='$DEPLOY_COMPOSE_PROJECT' DEPLOY_INCLUDE_CPA='$DEPLOY_INCLUDE_CPA' DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL='$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL' RELEASE_KEEP='$RELEASE_KEEP' RUN_REMOTE_BACKUP='$RUN_REMOTE_BACKUP' LEGACY_DEPLOY_PATH='$LEGACY_DEPLOY_PATH' RELEASE_ID='$RELEASE_ID' SMOKE_BACKUP_PATH='${SMOKE_BACKUP_PATH:-}' sh -s -- '$command' '$release_arg'" <<'REMOTE'
set -eu

command="$1"
release_arg="${2:-}"

repo_dir="$DEPLOY_ROOT/repo.git"
releases_dir="$DEPLOY_ROOT/releases"
shared_dir="$DEPLOY_ROOT/shared"
current_link="$DEPLOY_ROOT/current"
previous_link="$DEPLOY_ROOT/previous"
candidate_link="$DEPLOY_ROOT/candidate"
revisions_log="$DEPLOY_ROOT/revisions.log"

log() {
  printf '%s\n' "$*"
}

fail() {
  echo "$*" >&2
  exit 1
}

latest_release_id() {
  [ -d "$releases_dir" ] || return 0
  latest="$(find "$releases_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -n 1)"
  [ -n "$latest" ] || return 0
  basename "$latest"
}

candidate_target() {
  readlink -f "$candidate_link" 2>/dev/null || true
}

candidate_release_id() {
  target="$(candidate_target)"
  [ -n "$target" ] && [ -d "$target" ] || return 0
  basename "$target"
}

release_id_from_input() {
  id="${RELEASE_ID:-$release_arg}"
  if [ -z "$id" ]; then
    id="$(candidate_release_id)"
  fi
  if [ -z "$id" ] && [ "$command" = "smoke" ]; then
    id="$(latest_release_id)"
  fi
  [ -n "$id" ] || fail "RELEASE_ID or release-id argument is required; run prepare first to set candidate"
  printf '%s' "$id"
}

ensure_dirs() {
  mkdir -p "$DEPLOY_ROOT" "$releases_dir" "$shared_dir/data/cpa" "$shared_dir/cloudflared" "$shared_dir/logs" "$shared_dir/backups/postgres" "$shared_dir/snapshots"
}

ensure_repo() {
  ensure_dirs
  if [ ! -d "$repo_dir" ]; then
    git clone --mirror "$DEPLOY_REPO" "$repo_dir"
  else
    git --git-dir "$repo_dir" remote set-url origin "$DEPLOY_REPO"
  fi
}

copy_legacy_if_missing() {
  if [ -f "$LEGACY_DEPLOY_PATH/$DEPLOY_ENV_FILE" ] && [ ! -f "$shared_dir/$DEPLOY_ENV_FILE" ]; then
    cp "$LEGACY_DEPLOY_PATH/$DEPLOY_ENV_FILE" "$shared_dir/$DEPLOY_ENV_FILE"
    chmod 600 "$shared_dir/$DEPLOY_ENV_FILE" || true
  fi

  for name in data logs backups snapshots; do
    if [ -d "$LEGACY_DEPLOY_PATH/$name" ]; then
      mkdir -p "$shared_dir/$name"
      cp -an "$LEGACY_DEPLOY_PATH/$name/." "$shared_dir/$name/" 2>/dev/null || true
    fi
  done
}

compose() {
  include_tunnel=0
  if [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ] && [ -f docker-compose.cloudflare-tunnel.yml ]; then
    include_tunnel=1
  fi

  if [ "$DEPLOY_INCLUDE_CPA" = "1" ] && [ "$include_tunnel" = "1" ]; then
    docker compose -p "$DEPLOY_COMPOSE_PROJECT" --env-file "$DEPLOY_ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml -f docker-compose.cloudflare-tunnel.yml "$@"
  elif [ "$DEPLOY_INCLUDE_CPA" = "1" ]; then
    docker compose -p "$DEPLOY_COMPOSE_PROJECT" --env-file "$DEPLOY_ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml "$@"
  elif [ "$include_tunnel" = "1" ]; then
    docker compose -p "$DEPLOY_COMPOSE_PROJECT" --env-file "$DEPLOY_ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cloudflare-tunnel.yml "$@"
  else
    docker compose -p "$DEPLOY_COMPOSE_PROJECT" --env-file "$DEPLOY_ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml "$@"
  fi
}

compose_up() {
  if [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ] && [ -f docker-compose.cloudflare-tunnel.yml ]; then
    compose up -d --remove-orphans --scale caddy=0
  else
    compose up -d --remove-orphans
  fi
}

link_shared() {
  release_path="$1"
  [ -d "$release_path" ] || fail "release path does not exist: $release_path"

  ln -sfn "$shared_dir/$DEPLOY_ENV_FILE" "$release_path/$DEPLOY_ENV_FILE"
  for name in data logs backups snapshots; do
    rm -rf "$release_path/$name"
    ln -sfn "$shared_dir/$name" "$release_path/$name"
  done
}

release_path_for() {
  printf '%s/%s' "$releases_dir" "$1"
}

current_target() {
  readlink -f "$current_link" 2>/dev/null || true
}

previous_target() {
  readlink -f "$previous_link" 2>/dev/null || true
}

release_id_for_path() {
  path="${1:-}"
  if [ -z "$path" ]; then
    printf 'none'
    return
  fi
  basename "$path"
}

verify_new_api() {
  ready=0
  for _ in $(seq 1 40); do
    if compose exec -T new-api wget -q -O - http://localhost:3000/api/status 2>/dev/null | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
      ready=1
      break
    fi
    sleep 3
  done
  [ "$ready" -eq 1 ]
}

switch_current_to() {
  target="$1"
  tmp_link="$DEPLOY_ROOT/.current.tmp"
  ln -sfn "$target" "$tmp_link"
  mv -Tf "$tmp_link" "$current_link"
}

set_candidate_to() {
  target="$1"
  tmp_link="$DEPLOY_ROOT/.candidate.tmp"
  ln -sfn "$target" "$tmp_link"
  mv -Tf "$tmp_link" "$candidate_link"
}

clear_candidate_if() {
  target="$1"
  cand="$(candidate_target)"
  if [ -n "$cand" ] && [ "$cand" = "$target" ]; then
    rm -f "$candidate_link"
  fi
}

write_revision() {
  action="$1"
  release_id="$2"
  sha="${3:-unknown}"
  previous="${4:-none}"
  printf '%s action=%s release=%s sha=%s previous=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$action" "$release_id" "$sha" "$previous" >> "$revisions_log"
}

find_latest_backup() {
  if [ -n "${SMOKE_BACKUP_PATH:-}" ]; then
    printf '%s' "$SMOKE_BACKUP_PATH"
    return
  fi
  find "$shared_dir/backups/postgres" -type f -name '*.dump' 2>/dev/null | sort | tail -n 1
}

cmd_bootstrap() {
  ensure_repo
  copy_legacy_if_missing
  log "release deploy root ready: $DEPLOY_ROOT"
  if [ ! -f "$shared_dir/$DEPLOY_ENV_FILE" ]; then
    log "WARN missing $shared_dir/$DEPLOY_ENV_FILE; copy production env before prepare/promote"
  fi
}

cmd_prepare() {
  ensure_repo
  git --git-dir "$repo_dir" fetch --prune origin "$DEPLOY_REF"
  sha="$(git --git-dir "$repo_dir" rev-parse FETCH_HEAD)"
  short="$(printf '%s' "$sha" | cut -c1-7)"
  release_id="$(date -u +%Y%m%dT%H%M%SZ)-$short"
  release_path="$(release_path_for "$release_id")"

  git --git-dir "$repo_dir" worktree add --detach "$release_path" "$sha"
  (cd "$release_path" && git submodule update --init --recursive)
  link_shared "$release_path"

  [ -f "$shared_dir/$DEPLOY_ENV_FILE" ] || fail "missing shared env file: $shared_dir/$DEPLOY_ENV_FILE"

  (
    cd "$release_path"
    if [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ] && [ ! -f docker-compose.cloudflare-tunnel.yml ]; then
      fail "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 but docker-compose.cloudflare-tunnel.yml is missing"
    fi
    COMPOSE_PROJECT_NAME="$DEPLOY_COMPOSE_PROJECT" ENV_FILE="$DEPLOY_ENV_FILE" bash ops/preflight.sh
    compose config >/dev/null
  )

  set_candidate_to "$release_path"
  printf 'release prepared: %s\n' "$release_id"
  printf 'RELEASE_ID=%s\n' "$release_id"
  printf 'candidate -> releases/%s\n' "$release_id"
  write_revision "prepare" "$release_id" "$sha" "$(release_id_for_path "$(current_target)")"
}

cmd_smoke() {
  release_id="$(release_id_from_input)"
  release_path="$(release_path_for "$release_id")"
  [ -d "$release_path" ] || fail "release does not exist: $release_id"
  backup="$(find_latest_backup)"
  [ -n "$backup" ] || fail "no smoke backup found under $shared_dir/backups/postgres; set SMOKE_BACKUP_PATH"
  [ -f "$backup" ] || fail "smoke backup not found: $backup"

  (
    cd "$release_path"
    COMPOSE_PROJECT_NAME="$DEPLOY_COMPOSE_PROJECT" ENV_FILE="$DEPLOY_ENV_FILE" bash ops/drill-restore-stack.sh "$backup"
  )
}

cmd_promote() {
  release_id="$(release_id_from_input)"
  release_path="$(release_path_for "$release_id")"
  [ -d "$release_path" ] || fail "release does not exist: $release_id"
  [ -f "$release_path/$DEPLOY_ENV_FILE" ] || fail "release is missing linked env file: $release_path/$DEPLOY_ENV_FILE"

  old_target="$(current_target)"
  old_id="none"
  if [ -n "$old_target" ] && [ -d "$old_target" ]; then
    old_id="$(release_id_for_path "$old_target")"
    ln -sfn "$old_target" "$previous_link"
    if [ "$RUN_REMOTE_BACKUP" = "1" ]; then
      (
        cd "$old_target"
        if compose ps postgres 2>/dev/null | grep -q "relay-postgres"; then
          COMPOSE_PROJECT_NAME="$DEPLOY_COMPOSE_PROJECT" ENV_FILE="$DEPLOY_ENV_FILE" bash ops/backup-postgres.sh >/dev/null
        else
          echo "WARN no running PostgreSQL service found before promote; skipped pre-promote backup"
        fi
      )
    fi
  fi

  switch_current_to "$release_path"

  set +e
  (
    cd "$current_link"
    compose pull
    compose_up
    verify_new_api
    COMPOSE_PROJECT_NAME="$DEPLOY_COMPOSE_PROJECT" ENV_FILE="$DEPLOY_ENV_FILE" bash ops/check-production-runtime.sh
  )
  promote_status="$?"
  set -e

  if [ "$promote_status" -ne 0 ]; then
    echo "release promote failed; attempting rollback to previous release" >&2
    if [ -n "$old_target" ] && [ -d "$old_target" ]; then
      switch_current_to "$old_target"
      (
        cd "$current_link"
        compose_up
      ) || true
    fi
    exit "$promote_status"
  fi

  sha="$(cd "$release_path" && git rev-parse HEAD 2>/dev/null || printf unknown)"
  write_revision "promote" "$release_id" "$sha" "$old_id"
  clear_candidate_if "$release_path"
  log "release promoted: $release_id"
}

cmd_rollback() {
  prev="$(previous_target)"
  [ -n "$prev" ] && [ -d "$prev" ] || fail "previous release is not available"
  old_target="$(current_target)"
  if [ -n "$old_target" ] && [ -d "$old_target" ]; then
    ln -sfn "$old_target" "$previous_link"
  fi
  switch_current_to "$prev"
  (
    cd "$current_link"
    compose_up
    verify_new_api
  )
  release_id="$(release_id_for_path "$prev")"
  sha="$(cd "$prev" && git rev-parse HEAD 2>/dev/null || printf unknown)"
  write_revision "rollback" "$release_id" "$sha" "$(release_id_for_path "$old_target")"
  log "release rolled back: $release_id"
}

cmd_list() {
  cur="$(current_target)"
  prev="$(previous_target)"
  cand="$(candidate_target)"
  if [ ! -d "$releases_dir" ]; then
    log "no releases found"
    return
  fi
  find "$releases_dir" -mindepth 1 -maxdepth 1 -type d | sort -r | while IFS= read -r path; do
    marker=""
    [ "$path" = "$cur" ] && marker="${marker} current"
    [ "$path" = "$prev" ] && marker="${marker} previous"
    [ "$path" = "$cand" ] && marker="${marker} candidate"
    printf '%s%s\n' "$(basename "$path")" "$marker"
  done
}

cmd_current() {
  cur="$(current_target)"
  [ -n "$cur" ] || fail "current release is not set"
  release_id_for_path "$cur"
}

remove_release_path() {
  path="$1"
  git --git-dir "$repo_dir" worktree remove --force "$path" 2>/dev/null || rm -rf "$path"
}

cmd_cleanup() {
  ensure_repo
  case "$RELEASE_KEEP" in
    ''|*[!0-9]*) fail "RELEASE_KEEP must be a non-negative integer" ;;
  esac
  cur="$(current_target)"
  prev="$(previous_target)"
  cand="$(candidate_target)"
  kept=0
  if [ ! -d "$releases_dir" ]; then
    return
  fi
  release_list="$(mktemp)"
  find "$releases_dir" -mindepth 1 -maxdepth 1 -type d | sort -r > "$release_list"
  while IFS= read -r path; do
    if [ "$path" = "$cur" ] || [ "$path" = "$prev" ] || [ "$path" = "$cand" ]; then
      continue
    fi
    kept=$((kept + 1))
    if [ "$kept" -gt "$RELEASE_KEEP" ]; then
      echo "removing old release: $(basename "$path")"
      remove_release_path "$path"
    fi
  done < "$release_list"
  rm -f "$release_list"
  git --git-dir "$repo_dir" worktree prune
}

case "$command" in
  bootstrap) cmd_bootstrap ;;
  prepare) cmd_prepare ;;
  smoke) cmd_smoke ;;
  promote) cmd_promote ;;
  rollback) cmd_rollback ;;
  list) cmd_list ;;
  current) cmd_current ;;
  cleanup) cmd_cleanup ;;
esac
REMOTE
