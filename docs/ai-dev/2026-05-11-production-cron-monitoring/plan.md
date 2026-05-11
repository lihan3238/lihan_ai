# Plan

## Approach

Add `ops/production-monitor.sh` as a thin POSIX shell wrapper. It resolves `.env.production`, runs one requested mode, appends logs, writes a status file, and sends optional webhook alerts for failure or recovery.

## Files

- Create `ops/production-monitor.sh` and `tests/production-monitor.test.sh`.
- Update README, backup strategy, operations runbooks, env example, repository verification, wrapper tests, production gate, and docs i18n tests.

## Compatibility

No Docker Compose service, database schema, New API source, or public API changes. Cron installation remains manual.

## Rollback

Remove the wrapper script, tests, docs references, and monitor env example variables. Existing runtime, backup, and offsite scripts remain usable directly.

## Verification

Run syntax checks, the new production monitor test, related Cloudflare/backup/docs/wrapper tests, and the PowerShell repository verifier with `-SkipDocker`.
