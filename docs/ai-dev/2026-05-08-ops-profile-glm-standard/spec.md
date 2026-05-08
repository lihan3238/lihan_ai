# Spec

## Goal
Add a GLM standard-pool operations profile that can be committed, reviewed, and validated against the current local New API instance without mutating New API state.

## Success Criteria
- `config/ops-profiles/glm-standard.example.json` describes the expected `standard` + `glm-5.1` pool.
- `bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json` reports clear `PASS/WARN/FAIL` output.
- The validator fails for missing files, invalid JSON, missing required profile fields, and missing enabled channel capacity.
- Validator output does not include API keys, tokens, passwords, or session secrets.
- Existing wrapper, AI workflow, and repo verification checks include the new profile tooling.

## Scope
In scope: wrapper scripts, tests, docs, feature workflow artifacts, and production-gate wiring.

Out of scope: modifying `vendor/new-api`, writing New API configuration, changing schema, adding payment automation, or running live completion calls by default.

## Interfaces
- Command: `bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json`.
- Optional environment variables: `NEW_API_ENV_FILE`, `NEW_API_BASE_URL`, `NEW_API_TEST_TOKEN`, `NEW_API_TEST_TIMEOUT_SECONDS`, `OPS_PROFILE_FILE`.
- Gate integration: `OPS_PROFILE_FILE=<profile> bash ops/production-gate.sh`.

## Data
The validator reads `.env`, profile JSON, PostgreSQL tables, and optionally `/v1/models`. It writes no New API data and no tracked files at runtime.

## Failure Modes
Missing dependencies or invalid profile files fail fast. Runtime configuration mismatch exits nonzero with operator-facing hints. Missing users, tokens, subscriptions, or live test token are warnings unless they block the core channel requirement.
