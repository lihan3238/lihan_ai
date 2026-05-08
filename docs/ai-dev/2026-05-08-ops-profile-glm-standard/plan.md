# Plan

## Approach
Use a committed JSON profile for intent and a read-only shell validator for reality checks. Query PostgreSQL through the existing Docker Compose stack, parse with `jq`, and keep the output redacted by only returning counts and channel names.

## Files
Create the profile under `config/ops-profiles/`, add `ops/validate-ops-profile.sh`, add `tests/ops-profile.test.sh`, then wire the new check into production gate and repository verification.

## Compatibility
No API, database, Docker runtime, or upstream New API source behavior changes. The validator relies on existing New API tables and exits if the profile or environment is missing.

## Rollback
Revert the implementation commit. Since the validator is read-only, rollback does not require database cleanup.

## Verification
Run the ops-profile test, wrapper tests, AI workflow tests, preflight, repository verification, shell syntax checks, compose config checks, `git diff --check`, and the feature directory gate. Live E2E is optional and remains outside the default validator.
