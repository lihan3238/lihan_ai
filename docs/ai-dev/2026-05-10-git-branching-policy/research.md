# Research

## Sources
- GitHub Flow documentation for short-lived branches and `main` as the deployable integration branch.
- GitHub protected branch documentation for required checks and blocked direct pushes.
- Trunk-based development practices for keeping integration branches short-lived.
- GitFlow branching model, reviewed as a heavier alternative.

## Common Practice
Small teams and fast-moving services commonly use GitHub Flow or trunk-based development: keep `main` deployable, develop in short-lived branches, review by PR, and deploy from `main`. GitFlow adds `develop`, `release`, and `hotfix` branches; it is useful for scheduled releases but adds avoidable process overhead here.

## Risks
- Deploying a feature branch to production can make the server diverge from `main`.
- Long-lived `develop` can hide unshipped changes and complicate urgent fixes.
- Without script-level guardrails, a mistaken `DEPLOY_REF` can deploy non-production code.

## Decision
Use a GitHub Flow style model: `main = production`, short-lived `codex/`, `feature/`, and `hotfix/` branches, and a deploy script guard that blocks non-`main` production deploys unless explicitly overridden.
