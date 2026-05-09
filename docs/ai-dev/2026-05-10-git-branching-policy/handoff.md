# Handoff

## Current State
This feature establishes `main = production` as the branch and deployment policy.

## Important Context
The deploy script must keep allowing dry-run checks, but production dry-runs should still enforce the non-main branch guard. Emergency overrides require `ALLOW_NON_MAIN_PROD_DEPLOY=1`.

## Verification
Local verification run:
- `bash tests/git-branching-policy.test.sh`
- `bash tests/docs-i18n.test.sh`
- `bash tests/wrapper-infra.test.sh`
- `bash ops/ai-dev-check.sh docs/ai-dev/2026-05-10-git-branching-policy`
- `./scripts/verify-repo.ps1`
- `git diff --check`
- Deploy dry-run checks:
  - non-main production deploy is rejected with exit 2.
  - `DEPLOY_REF=main` production dry-run passes.
  - `ALLOW_NON_MAIN_PROD_DEPLOY=1` non-main production dry-run passes with a warning.

## Remaining Work
Configure GitHub branch protection for `main` in the GitHub repository UI or API so direct pushes are blocked and required checks are enforced.

## Risks
GitHub branch protection settings still need to be configured in the GitHub repository UI or API; this repo change documents the rule and enforces deployment behavior locally.
