# Spec

## Goal

Provide a production cron wrapper that runs existing health and backup scripts, records durable logs/status, and optionally sends coarse webhook alerts.

## Success Criteria

- `ENV_FILE=.env.production bash ops/production-monitor.sh runtime` runs production runtime checks.
- `ENV_FILE=.env.production bash ops/production-monitor.sh backup` creates and verifies a PostgreSQL dump.
- `ENV_FILE=.env.production bash ops/production-monitor.sh offsite` runs the restic offsite backup flow and fails when restic credentials are missing.
- Each mode writes `logs/production-monitor-<mode>.log` and `logs/production-monitor-<mode>.status`.
- `MONITOR_ALERT_WEBHOOK_URL` enables failure and recovery alerts without including secrets or log bodies.

## Scope

In scope: wrapper script, docs, cron examples, shell tests, repository verification, and production gate wiring.

Out of scope: automatic crontab installation, Uptime Kuma monitor creation, edge checks, new database tables, and New API source changes.

## Interfaces

- `ops/production-monitor.sh runtime`
- `ops/production-monitor.sh backup`
- `ops/production-monitor.sh offsite`
- Optional env: `MONITOR_ALERT_WEBHOOK_URL`, `MONITOR_ALERT_REPEAT_SECONDS`, `MONITOR_ALERT_TIMEOUT_SECONDS`, `MONITOR_LOG_DIR`.

## Failure Modes

Underlying script failures propagate as nonzero exits. Webhook delivery failures are logged but do not mask the original result. Repeated failure alerts for the same mode are rate-limited by `MONITOR_ALERT_REPEAT_SECONDS`; recovery sends one notification after a failed status.
