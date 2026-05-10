# Plan

## Approach

Add a release deployment wrapper that runs remote commands over SSH. The remote side owns `/opt/lihan_ai_deploy`, fetches code into `repo.git`, materializes release candidates with Git worktree, links shared runtime paths, and promotes by switching the `current` symlink.

The script reuses existing preflight, backup, restore drill, and runtime check scripts instead of creating a separate deployment framework.

## Files

- Create `ops/deploy-release.sh`.
- Create `tests/release-deploy.test.sh`.
- Update `.env.production.example`.
- Update `ops/production-gate.sh`, `tests/docs-i18n.test.sh`, `tests/wrapper-infra.test.sh`, and `scripts/verify-repo.ps1`.
- Add release deployment docs in English and Chinese.
- Update production, backup, disaster recovery, CPA, and README docs where the new layout changes operator behavior.

## Compatibility

The existing `ops/deploy-prod.sh` path remains available as a legacy simple deploy. The new release path uses the same Compose files and named volumes. CPA stays optional through `DEPLOY_INCLUDE_CPA=1`.

Existing `/opt/lihan_ai` is treated as the legacy source for bootstrap migration and should be kept until the release flow has been verified.

## Rollback

`ops/deploy-release.sh rollback` switches `current` back to `previous` and runs Compose again. This rolls code and Compose definitions back, but it does not restore database contents.

## Verification

- `bash -n ops/deploy-release.sh`
- `bash tests/release-deploy.test.sh`
- `bash tests/prod-deploy-hardening.test.sh`
- `bash tests/cpa-compose.test.sh`
- `bash tests/docs-i18n.test.sh`
- `bash tests/wrapper-infra.test.sh`
- `./scripts/verify-repo.ps1`
- `git diff --check`
