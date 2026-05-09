# Plan

## Approach
Add documentation and script guardrails for the chosen GitHub Flow style policy. Keep the enforcement small: documentation, default env values, and a deploy-time guard.

## Files
- Create English and Chinese branching runbooks.
- Add a shell test for branch policy behavior.
- Update deployment docs, i18n map, production env example, deploy script, wrapper tests, production gate, and repo verification.

## Compatibility
Existing local development and production compose flows continue to work. The only behavior change is that `DEPLOY_ENV=production` now refuses non-`main` `DEPLOY_REF` unless explicitly overridden.

## Verification
Run the new branch policy test, i18n test, wrapper infra test, repository verification, deploy dry-run cases, and `git diff --check`.
