# Operations Quick Reference

This is the daily command sheet for the production origin. README keeps the short project overview and the most common examples; this file is the practical runbook to use during routine checks, releases, backup checks, and recovery work.

## Assumptions

- Production origin root: `/opt/lihan_ai_deploy/current`.
- Shared production state: `/opt/lihan_ai_deploy/shared`.
- Production env: `/opt/lihan_ai_deploy/shared/.env.production`, normally visible from `current/.env.production`.
- Current production host example: `lihan@srv998135.hstgr.cloud`.
- The origin server is Arch Linux. Use `cronie`, `pacman`, and `systemctl enable --now cronie`; do not use Debian `apt` or a `cron` service name.
- Current restic storage may be a local repository such as `RESTIC_REPOSITORY=/opt/lihan_ai_deploy/shared/restic-repo`. True off-server backup can replace that later; do not block daily operations on that migration.

## Daily quick check

Run on the production server:

```bash
cd /opt/lihan_ai_deploy/current

cat logs/production-monitor-runtime.status
cat logs/production-monitor-audit.status
cat logs/ops-health/status.json | grep -n 'overall_status\|runtime\|backup\|offsite\|audit\|restore_drill\|inode_status'
```

Expected routine state:

- `runtime`, `backup`, `offsite`, `audit`, and `restore_drill` are `PASS`.
- `overall_status` is `PASS`, or `WARN` only when the warning is an understood non-fault.
- On the current Arch filesystem, `df -Pi /opt/lihan_ai_deploy/current` can report `IUse%` as `-`; the health report may show `inode_status=WARN` and `inode_used_percent=0`. Treat that as inode usage not available, not as disk pressure.

Check the raw inode output when the only warning is inode related:

```bash
df -Pi /opt/lihan_ai_deploy/current
cat logs/ops-health/status.json | grep -n 'WARN\|inode_status\|inode_used_percent'
```

## Automatic operations

Cron is installed by the operator, not by the repo. On Arch Linux:

```bash
command -v crontab
systemctl is-enabled cronie
systemctl is-active cronie
EDITOR=nano crontab -e
crontab -l
```

If `cronie` is missing:

```bash
sudo pacman -S --needed cronie
sudo systemctl enable --now cronie
```

Production crontab:

```cron
*/5 * * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh runtime
*/15 * * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh audit
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh backup
35 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh offsite
20 4 1 * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh restore-drill
```

Do not put interactive inspection commands such as `restic snapshots`, `du -sh`, or `. .env.production` into crontab. Run those manually in a shell.

## Manual monitor commands

Run on the production server:

```bash
cd /opt/lihan_ai_deploy/current

ENV_FILE=.env.production bash ops/production-monitor.sh runtime
ENV_FILE=.env.production bash ops/production-monitor.sh backup
ENV_FILE=.env.production bash ops/production-monitor.sh offsite
ENV_FILE=.env.production bash ops/production-monitor.sh restore-drill
ENV_FILE=.env.production bash ops/production-monitor.sh audit
ENV_FILE=.env.production bash ops/ops-health-report.sh render
```

Useful read-only checks:

```bash
ENV_FILE=.env.production bash ops/check-production-runtime.sh
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker compose -p lihan_ai ps
tail -n 160 logs/production-monitor-runtime.log
tail -n 160 logs/production-monitor-audit.log
```

## Ops dashboard and Kuma

Ops Dashboard is private and served on loopback only:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/ops-dashboard.sh open
ssh -L 3021:127.0.0.1:3021 lihan@srv998135.hstgr.cloud
```

Open `http://127.0.0.1:3021`, then close the server-side listener:

```bash
ENV_FILE=.env.production bash ops/ops-dashboard.sh close
```

Kuma admin UI is also private:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/kuma-ui.sh open
ssh -L 3011:127.0.0.1:3011 lihan@srv998135.hstgr.cloud
```

Open `http://127.0.0.1:3011`, then close it:

```bash
ENV_FILE=.env.production bash ops/kuma-ui.sh close
```

## Deploy latest main

Run from the local repo:

```bash
git fetch origin
git switch main
git pull --ff-only origin main

DEPLOY_HOST=lihan@srv998135.hstgr.cloud DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/deploy-release.sh smoke
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/deploy-release.sh promote
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/verify-remote-prod.sh
```

Release commands read CPA and Cloudflare Tunnel topology from the remote `.env.production`. Pass `DEPLOY_INCLUDE_*` only for a deliberate temporary override.

## Rollback code release

Rollback changes the release symlink and Compose definitions. It does not restore database contents.

```bash
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/deploy-release.sh rollback
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/verify-remote-prod.sh
```

Use database restore only when data itself is bad and there is a deliberate recovery decision.

## Manual backup

Use the monitor wrapper so status files and the dashboard stay current:

```bash
cd /opt/lihan_ai_deploy/current

ENV_FILE=.env.production bash ops/production-monitor.sh backup
ENV_FILE=.env.production bash ops/production-monitor.sh offsite
ENV_FILE=.env.production bash ops/production-monitor.sh audit
```

Manual restic commands need exported env variables. Sourcing without `set -a` does not export `RESTIC_REPOSITORY` or `RESTIC_PASSWORD` to the `restic` process.

```bash
cd /opt/lihan_ai_deploy/current
set -a; . ./.env.production; set +a
restic snapshots
restic check
du -sh /opt/lihan_ai_deploy/shared/restic-repo
```

If `restic snapshots` says repository location is missing, re-run the `set -a; . ./.env.production; set +a` line and confirm `RESTIC_REPOSITORY` is set.

## Restore drill

A restore drill must not touch the production database:

```bash
cd /opt/lihan_ai_deploy/current
latest="$(find backups/postgres -type f -name '*.dump' | sort | tail -n 1)"
ENV_FILE=.env.production bash ops/drill-restore-stack.sh "$latest"
ENV_FILE=.env.production bash ops/production-monitor.sh restore-drill
ENV_FILE=.env.production bash ops/production-monitor.sh audit
```

## Real database restore

This is destructive. Do it only during an intentional recovery window after choosing a known-good dump and accepting data loss after that dump time.

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<backup>.dump
ENV_FILE=.env.production bash ops/check-production-runtime.sh
ENV_FILE=.env.production bash ops/production-monitor.sh audit
```

## Lessons from the 2026-05-11 rollout

- On the release layout, edit `/opt/lihan_ai_deploy/shared/.env.production`. Do not assume a release-local env file is the source of truth unless the symlink is confirmed.
- For manual restic use, run `set -a; . ./.env.production; set +a` before `restic snapshots` or `restic check`.
- `audit=FAIL` can be caused by stale `runtime` when cron is not installed or `cronie` is not running.
- `offsite=FAIL` with `RESTIC_PASSWORD is not set` means the environment is incomplete; check `.env.production` and exports before blaming restic.
- On Arch Linux, use `cronie`; `crontab` may exist even when no user crontab is installed.
- `inode_status=WARN` with `df -Pi` showing `IUse%` as `-` is an unavailable metric on this filesystem, not a full inode table.
- Local restic is acceptable for now, but it only protects against application and database mistakes on the same server. True off-server backup remains the later hardening step.
