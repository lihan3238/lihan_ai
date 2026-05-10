# Tasks

Approved for implementation: yes

## Implementation Tasks

- [x] Add a failing release deployment test that checks docs, env defaults, dry-run output, project name pinning, and non-main production guards.
- [x] Implement `ops/deploy-release.sh` with bootstrap, prepare, smoke, promote, rollback, list, current, and cleanup commands.
- [x] Add release deployment environment defaults to `.env.production.example`.
- [x] Add English and Chinese release deployment runbooks.
- [x] Update production, backup, disaster recovery, CPA, README, and i18n docs for the new layout.
- [x] Wire release deployment checks into repository verification and production gate scripts.
- [x] Run the full verification suite.

## High-Risk Stops

- [x] No destructive database operation is automated without an explicit restore command.
- [x] Production deploys still default to `DEPLOY_REF=main`.
- [x] CPA UI remains outside normal promote and uses the existing SSH tunnel security model.
- [x] `vendor/new-api` is not modified.
