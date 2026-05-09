# Plan

## Approach
Add a wrapper-level production deployment kit around the existing New API Compose stack. Keep production origin state on one server, keep edge stateless, and rely on PostgreSQL dump/restore plus restic for data movement and disaster recovery.

## Files
- Create production and edge compose files plus an example production env file.
- Create deployment, remote verification, off-server backup, migration preflight, and final migration scripts under `ops/`.
- Add a focused shell test for required files, safety gates, dry-run behavior, and secret-safe output.
- Add runbooks and update existing README, operations, backup, and server-buying documentation.

## Compatibility
The default local development flow stays unchanged. Existing `.env` remains supported. Production scripts default to `.env.production`, but most existing ops scripts can still run with `ENV_FILE=.env.production`.

## Rollback
Deploy rollback is a Git ref redeploy using `DEPLOY_REF=<previous-ref>`. Migration rollback before DNS cutover is to restart source `new-api` and `caddy`. After DNS cutover, restore the last source backup to the chosen server and repoint DNS or edge upstream.

## Verification
Run `bash tests/prod-deploy-migration.test.sh`, existing wrapper tests, shell syntax checks, compose config checks, `ops/preflight.sh`, `scripts/verify-repo.ps1`, and `git diff --check`. Real remote deployment and restic upload are documented but not run from local development unless credentials and target servers are provided.
