# Spec

## Goal

Production must no longer run directly from a mutable Git working directory. Operators should be able to prepare and smoke-test a candidate release, then promote it by switching `current` to a tested release directory.

## Success Criteria

- `prepare` creates a detached release worktree without changing `current`.
- `smoke` starts an isolated restored stack and does not touch the production database.
- `promote` switches `current`, runs Compose with a fixed project name, verifies `/api/status`, and falls back to the previous release on failure.
- `rollback` returns to the previous release without deleting Docker volumes.
- Documentation explains migration from `/opt/lihan_ai` to `/opt/lihan_ai_deploy/shared`.

## Scope

In scope: release deployment script, dry-run behavior, environment defaults, bilingual runbooks, repository gates, CPA optional compose inclusion, and cleanup of old releases.

Out of scope: zero-downtime blue/green routing, independent staging domain, database migration framework, PM2 deployment integration, and changes to `vendor/new-api`.

## Interfaces

- `ops/deploy-release.sh <bootstrap|prepare|smoke|promote|rollback|list|current|cleanup> [release-id]`
- Environment variables: `DEPLOY_ROOT`, `DEPLOY_REF`, `DEPLOY_COMPOSE_PROJECT`, `DEPLOY_INCLUDE_CPA`, `RELEASE_KEEP`, `ALLOW_NON_MAIN_PROD_DEPLOY`, `SMOKE_BACKUP_PATH`, `RUN_REMOTE_BACKUP`
- Docs: `docs/release-deployment-runbook.md` and `docs/zh-CN/release-deployment-runbook.md`

## Data

Release code lives under `/opt/lihan_ai_deploy/releases`. Runtime secrets, CPA files, logs, backups, and snapshots live under `/opt/lihan_ai_deploy/shared`. PostgreSQL and Redis continue using existing Docker named volumes.

## Failure Modes

- Missing `DEPLOY_HOST` exits before SSH.
- Non-`main` production refs are blocked unless explicitly overridden.
- Missing shared `.env.production` blocks `prepare`.
- Missing smoke dump blocks `smoke`.
- Promotion health failure switches `current` back to the previous release and attempts to restart the previous stack.
