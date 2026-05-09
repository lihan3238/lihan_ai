# Spec

## Goal
Define and enforce a professional, simple branch and environment isolation policy where `main` is the production branch.

## Success Criteria
- Branch policy is documented in English and Chinese.
- Production deploys default to `DEPLOY_REF=main`.
- `ops/deploy-prod.sh` blocks non-`main` production deploys unless `ALLOW_NON_MAIN_PROD_DEPLOY=1`.
- Repository tests verify the policy, documentation, and defaults.

## Scope
In scope: branch naming, PR rules, hotfix flow, deployment branch guard, i18n docs, and verification wiring.

Out of scope: GitHub repository settings changes via API, introducing `develop`, adding a staging server, and changing runtime New API behavior.

## Interfaces
- `docs/git-branching-runbook.md`
- `docs/zh-CN/git-branching-runbook.md`
- `.env.production.example`
- `ops/deploy-prod.sh`
- `tests/git-branching-policy.test.sh`

## Rules
Production origin deploys from `main`. Non-main production deploys require explicit override and should only be used for documented emergencies.
