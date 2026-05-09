# Plan: Production Deploy Lessons Hardening

## Technical Plan

Harden wrapper scripts and compose files around the existing production stack. Keep CPA as an optional service that shares `relay-internal` with New API, while official CPA assets live under `vendor/cli-proxy-api` for comparison and refresh.

## File Boundaries

- `ops/`: preflight, runtime diagnostics, backup/restore env handling, CPA upstream sync.
- root compose files: optional CPA service and UI-only localhost port override.
- `docs/` and `docs/zh-CN/`: production lessons, CPA runbook, backup/runtime guidance.
- `tests/`: static and fake-command tests for the hardening behavior.

## Rollback

Do not include `docker-compose.cpa.yml` when starting production if CPA causes issues. Existing New API, Caddy, PostgreSQL, and Redis compose behavior remains unchanged.

## Verification

Run shell tests, docs i18n tests, repo verification, compose config rendering, and `git diff --check`. Production live validation remains a manual read-only command against the VPS.
