# Handoff

## Current State

The release deployment V1 change adds a Capistrano-style deployment wrapper using `/opt/lihan_ai_deploy/repo.git`, `releases/`, `current`, `previous`, and `shared/`.

## Important Context

- Production code should run from `/opt/lihan_ai_deploy/current`.
- Runtime files should live under `/opt/lihan_ai_deploy/shared`.
- Compose commands in the release deploy script use `docker compose -p lihan_ai` by default.
- `DEPLOY_INCLUDE_CPA=1` includes `docker-compose.cpa.yml`; the CPA UI override remains manual and temporary.
- `ops/deploy-prod.sh` remains as the legacy direct-checkout deploy path.

## Verification

Planned verification commands are listed in `plan.md`. The key release-specific checks are `bash -n ops/deploy-release.sh` and `bash tests/release-deploy.test.sh`.

## Remaining Work

Run the full verification suite, fix any test failures, then commit the branch.

## Risks

Rollback changes code and Compose definitions only. If a failed release writes bad data, database recovery still requires a deliberate restore from a known-good dump.
